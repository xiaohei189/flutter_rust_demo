import 'dart:async';

import 'package:flutter/material.dart';

import '../models/chat.dart';
import '../models/message.dart';
import '../models/user.dart';
import '../src/rust/api/bridge_client.dart';
import '../src/rust/im/types.dart';

/// 消息服务 - 管理 WebSocket 连接和消息监听
class MessageService extends ChangeNotifier {
  OpenImBridgeClient? _client;
  StreamSubscription<MessageEvent>? _messageSubscription;
  bool _isConnected = false;

  // 会话列表数据
  final Map<String, Chat> _chats = {};

  // 每个会话的消息列表
  final Map<String, List<Message>> _messages = {};

  // 当前用户ID（需要从登录获取）
  String? _currentUserId;

  /// 是否已连接
  bool get isConnected => _isConnected;

  /// 获取所有会话列表
  List<Chat> get chats => _chats.values.toList()
    ..sort((a, b) {
      final aTime = a.lastMessageTime ?? DateTime(1970);
      final bTime = b.lastMessageTime ?? DateTime(1970);
      return bTime.compareTo(aTime);
    });

  /// 获取指定会话的消息列表
  List<Message> getMessages(String conversationId) {
    return _messages[conversationId] ?? [];
  }

  /// 初始化并连接 WebSocket
  Future<void> initialize({
    required String areaCode,
    required String phoneNumber,
    required String password,
    required int platform,
    String? wsUrl,
  }) async {
    if (_client != null) {
      await disconnect();
    }

    try {
      var response = await OpenImBridgeClient.loginAsync(
        areaCode: '+86',
        phoneNumber: '17764008284',
        password: '284f3d09ea0695538e4ded1c1766d73a',
        platform: 5,
      );
      if (response.errCode != 0) {
        throw Exception('登录失败: ${response.errMsg}');
      }
      _currentUserId = response.data?.userId;
      var token = response.data?.imToken;
      if (token == null) {
        throw Exception('登录失败: 没有 token');
      }
      // 创建客户端实例
      _client = OpenImBridgeClient(
        userId: _currentUserId ?? '',
        token: token,
        platformId: platform,
        wsUrl: wsUrl,
      );

      // 连接到服务器
      await _client!.connect();
      _isConnected = true;
      notifyListeners();

      // 订阅消息事件
      _subscribeToMessages();

      debugPrint('✅ WebSocket 连接成功');
    } catch (e) {
      debugPrint('❌ WebSocket 连接失败: $e');
      _isConnected = false;
      notifyListeners();
      rethrow;
    }
  }

  /// 订阅消息事件
  void _subscribeToMessages() {
    if (_client == null) return;

    _messageSubscription?.cancel();

    _messageSubscription = _client!.subscribeMessages().listen(
      (event) {
        _handleMessageEvent(event);
      },
      onError: (error) {
        debugPrint('❌ 消息流错误: $error');
        _isConnected = false;
        notifyListeners();
      },
      onDone: () {
        debugPrint('⚠️ 消息流已关闭');
        _isConnected = false;
        notifyListeners();
      },
    );
  }

  /// 处理消息事件
  ///
  /// 注意：需要重新生成 Rust 绑定后才能使用 MessageEvent 的辅助方法
  /// 运行命令：flutter_rust_bridge_codegen generate
  void _handleMessageEvent(MessageEvent event) {
    try {
      // TODO: 重新生成 Rust 绑定后，取消注释以下代码
      // 临时方案：先打印事件信息，等重新生成绑定后再实现完整逻辑
      debugPrint('📨 收到消息事件: ${event.toString()}');

      // 重新生成绑定后，使用以下代码：
      /*
      final eventType = RustLib.instance.api.crateImTypesMessageEventEventType(that: event);
      debugPrint('📨 收到消息事件: $eventType');
      
      if (eventType == 'NewMessage') {
        final conversationId = RustLib.instance.api.crateImTypesMessageEventGetConversationId(that: event);
        if (conversationId == null) return;
        
        final sendId = RustLib.instance.api.crateImTypesMessageEventGetSendId(that: event);
        final recvId = RustLib.instance.api.crateImTypesMessageEventGetRecvId(that: event);
        final content = RustLib.instance.api.crateImTypesMessageEventGetContent(that: event);
        if (content == null) return;
        
        final sendTime = RustLib.instance.api.crateImTypesMessageEventGetSendTime(that: event);
        final timestamp = sendTime != null 
            ? DateTime.fromMillisecondsSinceEpoch(sendTime)
            : DateTime.now();
        
        debugPrint('   会话ID: $conversationId');
        debugPrint('   发送者: $sendId -> 接收者: $recvId');
        debugPrint('   内容: $content');
        
        final message = Message(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          senderId: sendId ?? 'unknown',
          content: content,
          timestamp: timestamp,
          isSent: true,
        );
        
        _addMessage(conversationId, message);
      } else if (eventType == 'SendMessageResponse') {
        final response = RustLib.instance.api.crateImTypesMessageEventGetSendResponse(that: event);
        if (response != null) {
          final (success, errMsg, serverMsgId, clientMsgId) = response;
          debugPrint('📤 消息发送响应: success=$success, errMsg=$errMsg');
        }
      } else if (eventType == 'ConnectionStatus') {
        final status = RustLib.instance.api.crateImTypesMessageEventGetConnectionStatus(that: event);
        if (status != null) {
          final (connected, message) = status;
          _isConnected = connected;
          debugPrint('🔌 连接状态: $connected - $message');
          notifyListeners();
        }
      } else if (eventType == 'KickedOffline') {
        debugPrint('⚠️ 被踢下线');
        _isConnected = false;
        notifyListeners();
      }
      */
    } catch (e) {
      debugPrint('❌ 处理消息事件失败: $e');
    }
  }

  /// 添加或更新会话
  void _updateChat(String conversationId, Message message) {
    // 确定会话的另一方用户ID
    // 对于单聊，会话ID格式通常是 "single_{sendId}_{recvId}" 或类似格式
    // 这里简化处理，从会话ID或消息中提取对方用户ID
    String? otherUserId;

    // 如果消息是自己发送的，对方是接收者；否则对方是发送者
    if (message.isFromMe) {
      // 从会话ID中提取对方ID，或者需要从消息的 recvId 获取
      // 这里简化处理，假设会话ID包含用户ID信息
      final parts = conversationId.split('_');
      if (parts.length >= 2) {
        // 尝试找到不是当前用户的ID
        for (final part in parts) {
          if (part != _currentUserId && part.isNotEmpty) {
            otherUserId = part;
            break;
          }
        }
      }
      // 如果无法从会话ID提取，可能需要存储 recvId
      // 这里暂时使用会话ID作为用户ID
      otherUserId ??= conversationId;
    } else {
      otherUserId = message.senderId;
    }

    if (otherUserId == null || otherUserId == _currentUserId) return;

    // 查找或创建用户
    User user;
    try {
      user = User.mockUsers.firstWhere((u) => u.id == otherUserId);
    } catch (e) {
      // 创建新用户
      user = User(
        id: otherUserId,
        name: '用户 $otherUserId',
        avatarColor: Colors.blue,
        avatarIcon: Icons.person,
      );
    }

    // 更新或创建会话
    final existingChat = _chats[conversationId];
    if (existingChat != null) {
      // 更新现有会话
      _chats[conversationId] = Chat(
        id: existingChat.id,
        user: existingChat.user,
        lastMessage: message,
        unreadCount: existingChat.unreadCount + (message.isFromMe ? 0 : 1),
        lastMessageTime: message.timestamp,
      );
    } else {
      // 创建新会话
      _chats[conversationId] = Chat(
        id: conversationId,
        user: user,
        lastMessage: message,
        unreadCount: message.isFromMe ? 0 : 1,
        lastMessageTime: message.timestamp,
      );
    }

    notifyListeners();
  }

  /// 添加消息到指定会话
  void _addMessage(String conversationId, Message message) {
    if (!_messages.containsKey(conversationId)) {
      _messages[conversationId] = [];
    }

    _messages[conversationId]!.add(message);

    // 更新会话列表
    _updateChat(conversationId, message);

    notifyListeners();
  }

  /// 发送文本消息
  Future<void> sendTextMessage({
    required String recvId,
    required String text,
    required int sessionType,
  }) async {
    if (_client == null || !_isConnected) {
      throw Exception('客户端未连接');
    }

    try {
      await _client!.sendTextMessage(
        recvId: recvId,
        text: text,
        sessionType: sessionType,
      );

      // 创建本地消息（发送响应会通过事件流返回）
      // 会话ID格式：单聊为 "single_{sendId}_{recvId}"，群聊为 "group_{groupId}"
      // 注意：实际会话ID应该从服务器返回，这里简化处理
      // 对于单聊，会话ID应该是两个用户ID排序后的组合
      // 对于单聊，会话ID应该是两个用户ID排序后的组合，确保唯一性
      final conversationId = sessionType == 2
          ? 'group_$recvId'
          : _currentUserId != null && _currentUserId!.compareTo(recvId) < 0
          ? 'single_${_currentUserId}_$recvId'
          : 'single_$recvId\_${_currentUserId}';

      final message = Message(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        senderId: _currentUserId ?? 'unknown',
        content: text,
        timestamp: DateTime.now(),
        isSent: false, // 等待服务器确认
      );

      _addMessage(conversationId, message);
    } catch (e) {
      debugPrint('❌ 发送消息失败: $e');
      rethrow;
    }
  }

  /// 断开连接
  Future<void> disconnect() async {
    await _messageSubscription?.cancel();
    _messageSubscription = null;
    _client = null;
    _isConnected = false;
    notifyListeners();
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
