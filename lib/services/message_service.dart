import 'dart:async';

import 'package:flutter/material.dart';

import '../models/chat.dart';
import '../models/message.dart';
import '../models/user.dart';
import '../src/rust/api/bridge_client.dart';
import '../src/rust/api/listeners/connection_status.dart';
import '../src/rust/api/listeners/conversation.dart';
import '../src/rust/api/listeners/message.dart';
import '../src/rust/im/types.dart';
import '../utils/json_serializer.dart';

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
  StreamSubscription<ConversationEvent>? _conversationSubscription;
  StreamSubscription<MessageEvent>? _messageSubscription;
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

  /// 处理会话变更
  void _handleConversationEvent(ConversationEvent event) {
    event.when(
      syncServerStart: (reinstalled) {
        debugPrint(
          'dart ConversationEvent sync start, reinstalled=$reinstalled',
        );
      },
      syncServerFinish: (reinstalled) {
        debugPrint(
          'dart ConversationEvent sync finish, reinstalled=$reinstalled',
        );
      },
      syncServerProgress: (progress) {
        debugPrint('dart ConversationEvent progress=$progress');
      },
      syncServerFailed: (reinstalled) {
        debugPrint(
          'dart ConversationEvent sync failed, reinstalled=$reinstalled',
        );
      },
      newConversation: (conversationList) {
        debugPrint(
          'dart ConversationEvent new conversation, conversationList=$conversationList',
        );
      },
      conversationChanged: (conversationList) {
        debugPrint(
          'dart ConversationEvent conversation changed, conversationList=$conversationList',
        );
      },
      totalUnreadMessageCountChanged: (totalUnreadCount) {
        debugPrint(
          'dart ConversationEvent total unread message count changed, totalUnreadCount=$totalUnreadCount',
        );
      },
      conversationUserInputStatusChanged: (change) {
        debugPrint(
          'dart ConversationEvent conversation user input status changed, change=$change',
        );
      },
    );
    try {
      // 会话变更时重新加载会话列表
      _loadConversations();
      debugPrint('dart MessageService 🔄 会话列表已更新: ${_chats.length} 个会话');
    } catch (e) {
      debugPrint('dart MessageService ❌ 处理会话变更失败: $e');
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
      debugPrint('dart MessageService ✅ 加载会话列表成功: ${_chats.length} 个会话');
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
