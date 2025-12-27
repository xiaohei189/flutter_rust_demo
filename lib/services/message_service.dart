import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';

import '../models/chat.dart';
import '../models/message.dart';
import '../models/user.dart';
import '../src/rust/api/bridge_client.dart';
import '../src/rust/api/listeners.dart';
import '../src/rust/im/types.dart';

/// 消息服务 - 管理客户端连接、监听事件、更新会话列表
class MessageService extends ChangeNotifier {
  OpenImBridgeClient? _client;
  bool _isConnected = false;
  bool _isInitializing = false; // 初始化状态标志，防止并发初始化

  // 会话列表
  final List<Chat> _chats = [];

  // 消息列表（按会话ID分组）
  final Map<String, List<Message>> _messages = {};

  // Stream 订阅
  StreamSubscription<ConversationChangedEvent>? _conversationSubscription;
  StreamSubscription<NewMessageEvent>? _messageSubscription;
  StreamSubscription<ConnectionStatusEvent>? _connectionSubscription;

  /// 是否已连接
  bool get isConnected => _isConnected;

  /// 获取客户端实例
  OpenImBridgeClient? get client => _client;

  /// 获取所有会话列表
  List<Chat> get chats => List.unmodifiable(_chats);

  /// 获取指定会话的消息列表
  List<Message> getMessages(String conversationId) {
    return List.unmodifiable(_messages[conversationId] ?? []);
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

      debugPrint('✅ 登录成功！用户ID: $userId');

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


    // 设置连接状态监听器
    final connectionSink = RustStreamSink<ConnectionStatusEvent>();
    _connectionSubscription = connectionSink.stream.listen((event) {
      _isConnected = event.connected;
      debugPrint(
        '🔌 连接状态变更: ${event.connected ? "已连接" : "已断开"} - ${event.message}',
      );
      notifyListeners();
    });

    // 设置消息监听器
    final messageSink = RustStreamSink<NewMessageEvent>();
    _messageSubscription = messageSink.stream.listen((event) {
      _handleNewMessage(event.message);
    });

    _client!.setAdvancedMsgListener(
      messageSink: messageSink,
      connectionSink: connectionSink,
    );

    // 设置会话监听器
    _conversationSubscription = _client!.setConversationListener().listen((
      event,
    ) {
      _handleConversationChanged(event.conversationList);
    });
  }

  /// 处理新消息
  void _handleNewMessage(String messageJson) {
    try {
      final messageData = jsonDecode(messageJson) as Map<String, dynamic>;
      final conversationId = messageData['conversationID'] as String?;
      final senderId = messageData['sendID'] as String?;
      final content = messageData['content'] as String?;
      final sendTime = messageData['sendTime'] as int?;

      if (conversationId == null || senderId == null || content == null) {
        debugPrint('⚠️ 消息格式不完整: $messageJson');
        return;
      }

      final message = Message(
        id:
            messageData['clientMsgID'] as String? ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        senderId: senderId,
        content: content,
        timestamp: sendTime != null
            ? DateTime.fromMillisecondsSinceEpoch(sendTime)
            : DateTime.now(),
      );

      // 添加到消息列表
      _messages.putIfAbsent(conversationId, () => []).add(message);

      // 更新会话列表
      _updateConversationFromMessage(conversationId, message);

      notifyListeners();
      debugPrint('📨 收到新消息: $conversationId - $content');
    } catch (e) {
      debugPrint('❌ 处理新消息失败: $e');
    }
  }

  /// 处理会话变更
  void _handleConversationChanged(String conversationListJson) {
    try {
      // 会话变更时重新加载会话列表
      _loadConversations();
      debugPrint('🔄 会话列表已更新: ${_chats.length} 个会话');
    } catch (e) {
      debugPrint('❌ 处理会话变更失败: $e');
    }
  }

  /// 从 LocalConversation 更新 Chat
  void _updateChatFromConversation(LocalConversation conv) {
    final chatIndex = _chats.indexWhere(
      (chat) => chat.id == conv.conversationId,
    );

    // 处理 PlatformInt64（转换为 int）
    final latestMsgTime = conv.latestMsgSendTime.toInt();

    final chat = Chat(
      id: conv.conversationId,
      user: User(
        id: conv.userId.isNotEmpty ? conv.userId : conv.groupId,
        name: conv.showName.isNotEmpty ? conv.showName : conv.conversationId,
        avatar: conv.faceUrl.isNotEmpty ? conv.faceUrl : null,
      ),
      unreadCount: conv.unreadCount,
      lastMessageTime: latestMsgTime > 0
          ? DateTime.fromMillisecondsSinceEpoch(latestMsgTime)
          : null,
    );

    if (chatIndex >= 0) {
      _chats[chatIndex] = chat;
    } else {
      _chats.add(chat);
    }

    // 按最后消息时间排序
    _chats.sort((a, b) {
      final aTime = a.lastMessageTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.lastMessageTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });
  }

  /// 从消息更新会话
  void _updateConversationFromMessage(String conversationId, Message message) {
    final chatIndex = _chats.indexWhere((chat) => chat.id == conversationId);
    if (chatIndex >= 0) {
      final chat = _chats[chatIndex];
      _chats[chatIndex] = Chat(
        id: chat.id,
        user: chat.user,
        lastMessage: message,
        unreadCount: chat.unreadCount + 1,
        lastMessageTime: message.timestamp,
      );

      // 重新排序
      _chats.sort((a, b) {
        final aTime =
            a.lastMessageTime ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime =
            b.lastMessageTime ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });
    }
  }

  /// 加载会话列表
  Future<void> _loadConversations() async {
    if (_client == null) return;

    try {
      final conversations = await _client!.getAllConversations();
      _chats.clear();
      for (final conv in conversations) {
        _updateChatFromConversation(conv);
      }
      notifyListeners();
      debugPrint('✅ 加载会话列表成功: ${_chats.length} 个会话');
    } catch (e) {
      debugPrint('❌ 加载会话列表失败: $e');
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
    _chats.clear();
    _messages.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
