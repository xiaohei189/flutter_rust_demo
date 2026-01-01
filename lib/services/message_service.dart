import 'dart:async';

import 'package:flutter/material.dart';

import '../models/chat.dart';
import '../models/message.dart';
import '../src/rust/api/bridge_client.dart';
import '../src/rust/api/listeners/connection_status.dart';
import '../src/rust/api/listeners/conversation.dart';
import '../src/rust/api/listeners/message.dart';
import '../src/rust/im/message/types.dart';
import '../src/rust/im/types.dart';

/// 消息服务 - 管理客户端连接、监听事件、更新会话列表
class MessageService extends ChangeNotifier {
  OpenImBridgeClient? _client;
  bool _isConnected = false;
  bool _isInitializing = false; // 初始化状态标志，防止并发初始化

  // 会话列表
  final List<LocalConversation> _conversations = [];
  // 消息列表（按会话ID分组）
  final Map<String, List<Message>> _messages = {};

  // Stream 订阅
  StreamSubscription<ConversationEvent>? _conversationSubscription;
  StreamSubscription<MessageEvent>? _messageSubscription;
  StreamSubscription<ConnectionStatusEvent>? _connectionSubscription;

  /// 是否已连接
  bool get isConnected => _isConnected;

  /// 获取客户端实例
  OpenImBridgeClient? get client => _client;

  /// 获取所有会话列表
  List<LocalConversation> get conversations =>
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
      final req = GetAdvancedHistoryMessageListParams(
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
  Message _msgStructToMessage(MsgStruct msg) {
    // 从 MsgStruct 中提取信息
    final clientMsgId = msg.clientMsgId ?? '';
    final sendId = msg.sendId ?? '';

    // 提取内容（优先使用 textElem，否则使用 content）
    String content = '';
    if (msg.textElem != null) {
      content = msg.textElem!.content;
    } else if (msg.content != null) {
      // 如果是文本消息，content 可能是 JSON，需要解析
      if (msg.contentType == 101) {
        // TEXT 类型
        try {
          final json = msg.content!;
          // 尝试解析 JSON，如果失败则直接使用
          if (json.startsWith('{')) {
            // 可能是 JSON 格式的 {"content": "..."}
            // 这里简化处理，直接使用 content
            content = json;
          } else {
            content = json;
          }
        } catch (e) {
          content = msg.content!;
        }
      } else {
        content = msg.content ?? '';
      }
    }

    final sendTime = msg.sendTime.toInt();

    // 判断是否是自己发送的消息
    // TODO: 从客户端配置中获取当前用户ID
    final isSent = true; // 暂时假设都是已发送的

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

  /// 发送文本消息（空实现）
  Future<void> sendTextMessage({
    required String recvId,
    required String text,
    required int sessionType,
  }) async {
    // TODO: 实现消息发送功能
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
      final loginResponse = await loginAsync(
        areaCode: '+86',
        phoneNumber: '17764338283',
        password: '284f3d09ea0695538e4ded1c1766d73a',
        platform: 5,
      );

      if (loginResponse.errCode != 0) {
        throw Exception('登录失败: ${loginResponse.errMsg}');
      }

      final userId = loginResponse.data?.userId;
      final imToken = loginResponse.data?.imToken;

      if (userId == null || imToken == null) {
        throw Exception('登录失败：服务器返回数据为空');
      }

      debugPrint('✅ 登录成功！用户ID----: $userId');

      // 创建客户端实例
      _client = OpenImBridgeClient(
        userId: userId,
        token: imToken,
        platformId: 5,
        wsUrl: wsUrl,
      );

      // 设置监听器
      _setupListeners();

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

  /// 设置监听器
  void _setupListeners() {
    if (_client == null) return;

    // 设置会话监听器
    _conversationSubscription = _client?.conversationEvent().listen((event) {
      _handleConversationEvent(event);
    });

    // 设置消息监听器（独立的事件源）
    _messageSubscription = _client?.messageEvent().listen((event) {
      _handleMessageEvent(event);
    });

    // 设置连接状态监听器（独立的事件源）
    _connectionSubscription = _client?.connectionEvent().listen((event) {
      _isConnected = event.connected;
      debugPrint(
        '🔌 连接状态变更: ${event.connected ? "已连接" : "已断开"} - ${event.message}',
      );
      notifyListeners();
    });
  }

  /// 处理新消息
  void _handleMessageEvent(MessageEvent event) {
    try {
      event.when(
        recvNewMessage: (message) {
          debugPrint(
            'dart MessageEvent recv new message: ${message.senderNickname}',
          );
        },
        recvC2CReadReceipt: (msgReceiptList) {
          debugPrint(
            'dart MessageEvent recv C2C read receipt, msgReceiptList=$msgReceiptList',
          );
        },
        newRecvMessageRevoked: (messageRevoked) {
          debugPrint(
            'dart MessageEvent new recv message revoked: ${messageRevoked}',
          );
        },
        recvOfflineNewMessage: (message) {
          debugPrint('dart MessageEvent recv offline new message: ${message}');
        },
        msgDeleted: (message) {
          debugPrint('dart MessageEvent msg deleted: ${message}');
        },
        recvOnlineOnlyMessage: (message) {
          debugPrint('dart MessageEvent recv online only message: ${message}');
        },
        kickedOffline: () {
          debugPrint('dart MessageEvent kicked offline');
        },
        recvTypingStatus: (typingStatus) {
          debugPrint('dart MessageEvent recv typing status: ${typingStatus}');
        },
      );
      // final message = Message(
      //   id:
      //       messageData['clientMsgID'] as String? ??
      //       DateTime.now().millisecondsSinceEpoch.toString(),
      //   senderId: senderId,
      //   content: content,
      //   timestamp: sendTime != null
      //       ? DateTime.fromMillisecondsSinceEpoch(sendTime)
      //       : DateTime.now(),
      // );

      // // 添加到消息列表
      // _messages.putIfAbsent(conversationId, () => []).add(message);

      // // 更新会话列表
      // _updateConversationFromMessage(conversationId, message);

      notifyListeners();
      // debugPrint('📨 收到新消息: $conversationId - $content');
    } catch (e) {
      debugPrint('❌ 处理新消息失败: $e');
    }
  }

  /// 更新会话列表（从结构体列表）
  void _updateConversationsFromList(List<LocalConversation> conversationList) {
    try {
      for (final conv in conversationList) {
        _updateConversation(conv);
      }
      notifyListeners();
      debugPrint(
        'dart MessageService 🔄 会话列表已更新: ${_conversations.length} 个会话',
      );
    } catch (e) {
      debugPrint('dart MessageService ❌ 更新会话列表失败: $e');
    }
  }

  /// 更新或添加会话
  void _updateConversation(LocalConversation conv) {
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

  /// 处理会话变更
  void _handleConversationEvent(ConversationEvent event) {
    try {
      event.when(
        syncServerStart: (reinstalled) {
          debugPrint(
            'dart ConversationEvent sync start, reinstalled=$reinstalled',
          );
          // 同步开始时，可以显示加载状态
        },
        syncServerFinish: (reinstalled) {
          debugPrint(
            'dart ConversationEvent sync finish, reinstalled=$reinstalled',
          );
          // 同步完成时，重新加载会话列表
          _loadConversations();
        },
        syncServerProgress: (progress) {
          debugPrint('dart ConversationEvent progress=$progress');
          // 可以更新同步进度UI
        },
        syncServerFailed: (reinstalled) {
          debugPrint(
            'dart ConversationEvent sync failed, reinstalled=$reinstalled',
          );
          // 同步失败时，可以显示错误提示
        },
        newConversation: (conversationList) {
          debugPrint(
            'dart ConversationEvent new conversation, count=${conversationList.length}',
          );
          // 新会话：直接使用结构体列表更新
          _updateConversationsFromList(conversationList);
        },
        conversationChanged: (conversationList) {
          debugPrint(
            'dart ConversationEvent conversation changed, count=${conversationList.length}',
          );
          // 会话变更：直接使用结构体列表更新
          _updateConversationsFromList(conversationList);
        },
        totalUnreadMessageCountChanged: (totalUnreadCount) {
          debugPrint(
            'dart ConversationEvent total unread message count changed, totalUnreadCount=$totalUnreadCount',
          );
          // 总未读数变更：可以更新应用角标等
          // 注意：这里只是总未读数，具体会话的未读数在 conversationChanged 中更新
        },
        conversationUserInputStatusChanged: (change) {
          debugPrint(
            'dart ConversationEvent conversation user input status changed, change=$change',
          );
          // 用户输入状态变更：可以显示"正在输入"提示
          // change 是 JSON 字符串，包含 conversationID 和状态信息
        },
      );
    } catch (e) {
      debugPrint('dart MessageService ❌ 处理会话变更失败: $e');
    }
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

  /// 断开连接
  Future<void> disconnect() async {
    await _conversationSubscription?.cancel();
    await _messageSubscription?.cancel();
    await _connectionSubscription?.cancel();
    _conversationSubscription = null;
    _messageSubscription = null;
    _connectionSubscription = null;

    _client = null;
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
