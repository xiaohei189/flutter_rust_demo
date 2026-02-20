import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/chat.dart';
import '../models/message.dart';
import '../src/rust/api/bridge_client.dart';
import '../src/rust/api/listeners/conversation.dart';
import '../src/rust/im/model/conversation.dart' as im_conv;
import '../src/rust/im/model/message.dart' as im_msg;

/// 消息服务 - 管理客户端连接、会话列表、消息
/// 会话通过 get_all_conversations + 监听 conversation stream 回调同步
class MessageService extends ChangeNotifier {
  OpenImBridgeClient? _client;
  bool _isConnected = false;
  bool _isInitializing = false; // 初始化状态标志，防止并发初始化
  String _currentUserId = ''; // 当前登录用户 ID，用于判断消息是否为自己发送

  /// 会话同步中（用于显示同步提示）
  bool _isSyncingConversations = false;
  /// 同步进度 0-100
  int _syncProgress = 0;

  // 会话列表
  final List<im_conv.LocalConversation> _conversations = [];
  // 消息列表（按会话ID分组）
  final Map<String, List<Message>> _messages = {};

  StreamSubscription<ConversationEvent>? _conversationStreamSubscription;

  /// 是否已连接
  bool get isConnected => _isConnected;

  /// 是否正在同步会话
  bool get isSyncingConversations => _isSyncingConversations;

  /// 同步进度 0-100
  int get syncProgress => _syncProgress;

  /// 获取客户端实例
  OpenImBridgeClient? get client => _client;

  /// 获取所有会话列表
  List<im_conv.LocalConversation> get conversations =>
      List.unmodifiable(_conversations);

  /// 获取所有会话列表（兼容旧代码）
  @Deprecated('使用 conversations 替代')
  List<Chat> get chats => [];

  /// 获取指定会话的消息列表
  List<Message> getMessages(String conversationId) {
    return List.unmodifiable(_messages[conversationId] ?? []);
  }

  /// 加载历史消息（首次加载或翻页）
  ///
  /// 完全参考 Go SDK 的 GetAdvancedHistoryMessageList 实现
  /// - `conversationId`: 会话 ID
  /// - `count`: 每次加载的消息数量
  /// - `startClientMsgId`: 起始消息ID（可选，用于翻页，获取比这个消息更早的消息）
  /// - 返回: 是否还有更多消息
  Future<bool> loadHistoryMessages(
    String conversationId, {
    int count = 20,
    String? startClientMsgId,
  }) async {
    if (_client == null) return false;

    try {
      // 构建请求参数（完全匹配 Go SDK）
      final req = im_msg.GetAdvancedHistoryMessageListParams(
        conversationId: conversationId,
        startClientMsgId: startClientMsgId ?? '', // 空字符串表示从最新开始
        count: count,
        viewType: 0, // 视图类型，0 表示普通视图
      );

      // 调用 Rust API 获取历史消息
      final result = await _client!.getAdvancedHistoryMessageList(req: req);

      // 检查错误
      if (result.errCode != 0) {
        debugPrint(
          'dart MessageService ❌ 加载历史消息失败: ${result.errMsg} (code: ${result.errCode})',
        );
        return false;
      }

      if (result.messageList.isEmpty) {
        return false; // 没有更多消息
      }

      // 转换为 Message 模型并添加到消息列表
      final messages = result.messageList
          .map((msg) => _msgStructToMessage(msg))
          .toList();

      // 获取当前消息列表
      final currentMessages = _messages.putIfAbsent(conversationId, () => []);

      // 将新消息插入到列表开头（因为历史消息是按时间倒序的，最新的在前）
      // 但我们需要按时间正序显示（最旧的在前面，最新的在后面）
      // 所以需要反转后添加到列表开头
      currentMessages.insertAll(0, messages.reversed);

      // 去重（基于消息 ID）
      final seenIds = <String>{};
      _messages[conversationId] = currentMessages
          .where((msg) => seenIds.add(msg.id))
          .toList();

      notifyListeners();
      debugPrint(
        'dart MessageService ✅ 加载历史消息成功: ${messages.length} 条，isEnd: ${result.isEnd}',
      );

      // 返回是否还有更多消息（取反，因为 isEnd 表示已到末尾）
      return !result.isEnd;
    } catch (e) {
      debugPrint('dart MessageService ❌ 加载历史消息失败: $e');
      return false;
    }
  }

  /// 将 MsgStruct 转换为 Message
  Message _msgStructToMessage(im_msg.MsgStruct msg) {
    // 从 MsgStruct 中提取信息
    final clientMsgId = msg.clientMsgId ?? '';
    final sendId = msg.sendId ?? '';

    // 提取内容（优先使用 textElem，否则使用 content）
    String content = '';
    if (msg.textElem != null) {
      content = msg.textElem!.content;
    } else if (msg.content != null) {
      final raw = msg.content!;
      if (msg.contentType == 101 && raw.startsWith('{')) {
        try {
          final decoded = jsonDecode(raw) as Map<String, dynamic>;
          content = decoded['content'] as String? ?? raw;
        } catch (_) {
          content = raw;
        }
      } else {
        content = raw;
      }
    }

    final sendTime = msg.sendTime.toInt();
    final isSent = sendId == _currentUserId;

    return Message(
      id: clientMsgId.isNotEmpty
          ? clientMsgId
          : DateTime.now().millisecondsSinceEpoch.toString(),
      senderId: sendId,
      content: content,
      type: MessageType.text, // 暂时都当作文本消息
      timestamp: sendTime > 0
          ? DateTime.fromMillisecondsSinceEpoch(sendTime)
          : DateTime.now(),
      isSent: isSent,
    );
  }

  /// 发送文本消息
  /// [conversationId] 可选，发送成功后若提供则刷新该会话的消息列表
  Future<void> sendTextMessage({
    required String recvId,
    required String text,
    required int sessionType,
    String? conversationId,
  }) async {
    if (_client == null) {
      throw StateError('客户端未初始化');
    }
    await _client!.sendTextMessage(
      recvId: recvId,
      text: text,
      sessionType: sessionType,
    );
    if (conversationId != null) {
      _messages[conversationId] = [];
      await loadHistoryMessages(conversationId);
    }
    notifyListeners();
  }

  /// 初始化并连接服务
  Future<void> initialize({String? wsUrl}) async {
    // 如果已经连接，热更新时跳过重复初始化
    if (_client != null && _isConnected) {
      debugPrint('ℹ️ 客户端已连接，跳过重复初始化（热更新场景）');
      return;
    }

    // 防止并发初始化
    if (_isInitializing) {
      debugPrint('⚠️ 初始化正在进行中，跳过重复调用');
      return;
    }

    _isInitializing = true;
    try {
      // 先登录获取 token 信息（参考 openim-cli.rs 的实现）
      final resp = await loginAsync(
        areaCode: '+86',
        phoneNumber: '17764338283',
        password: '284f3d09ea0695538e4ded1c1766d73a',
        platform: 5,
      );

      final userId = resp.userId;
      final imToken = resp.imToken;

      debugPrint('✅ 登录成功！用户ID: $userId');
      _currentUserId = userId;

      // 创建客户端实例（异步，由 bridge executor 执行）
      _client = await OpenImBridgeClient.newInstance(
        userId: userId,
        token: imToken,
        platformId: 5,
        wsUrl: wsUrl,
      );

      // 设置会话监听 Stream（需在 connect 之前，codegen 生成 setConversationStream 后取消注释）
      // final stream = _client!.setConversationStream();
      // _conversationStreamSubscription = stream.listen(_handleConversationEvent);

      // 连接到服务器
      await _client!.connect();
      _isConnected = true;
      notifyListeners();

      debugPrint('✅ 客户端连接成功');

      // 加载初始会话列表
      await _loadConversations();
    } catch (e) {
      debugPrint('❌ 初始化失败: $e');
      _isConnected = false;
      notifyListeners();
      rethrow;
    } finally {
      _isInitializing = false;
    }
  }

  /// 更新或添加会话
  void _updateConversation(im_conv.LocalConversation conv) {
    final index = _conversations.indexWhere(
      (c) => c.conversationId == conv.conversationId,
    );

    if (index >= 0) {
      _conversations[index] = conv;
    } else {
      _conversations.add(conv);
    }

    // 按最后消息时间排序（置顶的排在前面）
    _conversations.sort((a, b) {
      // 置顶的排在前面
      if (a.isPinned != b.isPinned) {
        return a.isPinned ? -1 : 1;
      }
      // 按最后消息时间倒序
      final aTime = a.latestMsgSendTime.toInt();
      final bTime = b.latestMsgSendTime.toInt();
      return bTime.compareTo(aTime);
    });
  }

  /// 处理会话事件（同步进度、新会话、会话变更等）
  /// 在 setConversationStream 取消注释后由 stream.listen 调用
  // ignore: unused_element
  void _handleConversationEvent(ConversationEvent event) {
    event.when(
      syncServerStart: (_) {
        _isSyncingConversations = true;
        _syncProgress = 0;
        notifyListeners();
      },
      syncServerFinish: (_) {
        _isSyncingConversations = false;
        _syncProgress = 100;
        notifyListeners();
        _loadConversations();
      },
      syncServerProgress: (progress) {
        _syncProgress = progress;
        notifyListeners();
      },
      syncServerFailed: (_) {
        _isSyncingConversations = false;
        notifyListeners();
      },
      newConversation: (list) {
        for (final c in list) {
          _updateConversation(c);
        }
        notifyListeners();
      },
      conversationChanged: (list) {
        for (final c in list) {
          _updateConversation(c);
        }
        notifyListeners();
      },
      totalUnreadMessageCountChanged: (_) => notifyListeners(),
      conversationUserInputStatusChanged: (_) {},
    );
  }

  /// 加载会话列表
  Future<void> _loadConversations() async {
    if (_client == null) return;

    try {
      final conversations = await _client!.getAllConversations();
      _conversations.clear();
      for (final conv in conversations) {
        _updateConversation(conv);
      }
      notifyListeners();
      debugPrint(
        'dart MessageService ✅ 加载会话列表成功: ${_conversations.length} 个会话',
      );
    } catch (e) {
      debugPrint('dart MessageService ❌ 加载会话列表失败: $e');
    }
  }

  /// 刷新会话列表（供下拉刷新等场景调用）
  Future<void> refreshConversations() async {
    await _loadConversations();
  }

  /// 断开连接
  Future<void> disconnect() async {
    await _conversationStreamSubscription?.cancel();
    _conversationStreamSubscription = null;
    _client = null;
    _currentUserId = '';
    _isConnected = false;
    _isInitializing = false; // 重置初始化状态
    _conversations.clear();
    _messages.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
