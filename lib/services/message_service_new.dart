import 'dart:async';
import 'dart:convert';

import '../models/message.dart' show Message, MessageSendStatus, MessageType;
import '../src/rust/im/client/listeners.dart' show AdvancedMsgEvent;
import '../src/rust/im/model/message.dart' as im_msg;
import '../utils/app_logger.dart';
import 'im_client.dart';

/// 消息服务 - 管理消息的发送和接收
///
/// 职责：
/// 1. 发送消息（文本、图片等）
/// 2. 加载历史消息
/// 3. 监听新消息
/// 4. 管理消息状态（发送中、已发送、失败）
class MessageService {
  static final MessageService _instance = MessageService._internal();

  /// 全局单例实例
  static MessageService get instance => _instance;

  // 消息列表（按会话ID分组）
  final Map<String, List<Message>> _messages = {};

  // 流控制器
  final _messagesController =
      StreamController<Map<String, List<Message>>>.broadcast();

  StreamSubscription<dynamic>? _subscription;
  String _currentUserId = '';
  bool _isDisposed = false;

  MessageService._internal();

  /// 设置当前用户ID
  void setCurrentUserId(String userId) {
    _currentUserId = userId;
  }

  /// 所有消息流
  Stream<Map<String, List<Message>>> get messagesStream =>
      _messagesController.stream;

  /// 获取指定会话的消息列表
  List<Message> getMessages(String conversationId) {
    return List.unmodifiable(_messages[conversationId] ?? []);
  }

  /// 获取指定会话的消息流
  Stream<List<Message>> getMessagesStream(String conversationId) {
    return _messagesController.stream.map(
      (messages) => List.unmodifiable(messages[conversationId] ?? []),
    );
  }

  /// 开始监听消息事件
  void startListening() {
    if (_subscription != null) return;

    try {
      _subscription = ImClient.instance.messageStream.listen(
        _handleMessageEvent,
        onError: (error) {
          appLog.e('[MessageService] 消息流错误: $error');
        },
      );
      appLog.i('[MessageService] 开始监听消息事件');
    } catch (e) {
      appLog.e('[MessageService] 监听消息事件失败: $e');
    }
  }

  /// 停止监听
  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
    appLog.i('[MessageService] 停止监听消息事件');
  }

  /// 处理消息事件
  void _handleMessageEvent(dynamic event) {
    if (event is! AdvancedMsgEvent) return;
    appLog.d('[MessageService] 收到消息事件: ${event.runtimeType}');

    try {
      event.when(
        recvNewMessage: (msg) {
          _appendMessage(msg);
          _notifyMessagesChanged();
        },
        recvC2CReadReceipt: (_) {
          // 已读回执处理
          _notifyMessagesChanged();
        },
        recvGroupReadReceipt: (_) {
          // 群已读回执处理
          _notifyMessagesChanged();
        },
        newRecvMessageRevoked: (_) {
          // 消息撤回处理
          _notifyMessagesChanged();
        },
        recvOfflineNewMessage: (msg) {
          _appendMessage(msg);
          _notifyMessagesChanged();
        },
        msgDeleted: (_) {
          // 消息删除处理
          _notifyMessagesChanged();
        },
        recvOnlineOnlyMessage: (msg) {
          _appendMessage(msg);
          _notifyMessagesChanged();
        },
      );
    } catch (e) {
      appLog.e('[MessageService] 处理消息事件失败: $e');
    }
  }

  /// 添加消息到列表
  void _appendMessage(im_msg.MsgStruct msg) {
    final conversationId = _msgStructToConversationId(msg);
    if (conversationId.isEmpty) return;

    final list = _messages.putIfAbsent(conversationId, () => []);
    list.add(_msgStructToMessage(msg));
  }

  /// 将 MsgStruct 转换为 Message
  Message _msgStructToMessage(im_msg.MsgStruct msg) {
    final clientMsgId = msg.clientMsgId ?? '';
    final sendId = msg.sendId ?? '';

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
      type: MessageType.text,
      timestamp: sendTime > 0
          ? DateTime.fromMillisecondsSinceEpoch(sendTime)
          : DateTime.now(),
      isSent: isSent,
      senderNickname: msg.senderNickname,
      senderFaceUrl: msg.senderFaceUrl,
    );
  }

  /// 计算会话ID
  String _msgStructToConversationId(im_msg.MsgStruct msg) {
    final sessionType = msg.sessionType;
    final sendId = msg.sendId ?? '';
    final recvId = msg.recvId ?? '';
    final groupId = msg.groupId ?? '';

    if (sessionType == 1) {
      // 单聊
      final my = _currentUserId;
      if (my.isEmpty) return '';
      final other = sendId == my ? recvId : sendId;
      if (other.isEmpty) return '';
      final parts = [my, other]..sort();
      return 'si_${parts[0]}_${parts[1]}';
    }
    if (sessionType == 2) return 'sg_$groupId';
    if (sessionType == 3) return 'sg_$groupId';
    if (groupId.isNotEmpty) return 'g_$groupId';
    return '';
  }

  /// 发送文本消息
  Future<void> sendTextMessage({
    required String recvId,
    required String text,
    required int sessionType,
    required String conversationId,
    String groupId = '',
  }) async {
    final client = ImClient.instance.client;
    if (client == null) {
      throw StateError('客户端未初始化');
    }
    if (recvId.trim().isEmpty && groupId.trim().isEmpty) {
      throw ArgumentError('recvId 与 groupId 至少填一个');
    }

    // 1. 创建消息
    final msgData = await client.createTextMessage(
      text: text,
      recvId: recvId,
      groupId: groupId,
      sessionType: sessionType,
    );

    // 2. 加入展示列表（乐观更新）
    final tempId = 'sending_${DateTime.now().millisecondsSinceEpoch}';
    final optimisticMessage = Message(
      id: tempId,
      senderId: _currentUserId,
      content: text,
      type: MessageType.text,
      timestamp: DateTime.now(),
      isSent: true,
      sendStatus: MessageSendStatus.sending,
    );
    final list = _messages.putIfAbsent(conversationId, () => []);
    list.add(optimisticMessage);
    _notifyMessagesChanged();

    try {
      // 3. 发送
      await client.sendMessage(msg: msgData, isOnlineOnly: false);
      // 4. 更新状态
      _updateMessageStatus(conversationId, tempId, MessageSendStatus.sent);
    } catch (e) {
      appLog.e('[MessageService] 发送失败: $e');
      _updateMessageStatus(conversationId, tempId, MessageSendStatus.failed);
      rethrow;
    }
  }

  /// 更新消息发送状态
  void _updateMessageStatus(
    String conversationId,
    String messageId,
    MessageSendStatus status,
  ) {
    final list = _messages[conversationId];
    if (list == null) return;

    final index = list.indexWhere((m) => m.id == messageId);
    if (index >= 0) {
      list[index] = list[index].copyWith(sendStatus: status);
      _notifyMessagesChanged();
    }
  }

  /// 加载历史消息
  Future<bool> loadHistoryMessages(
    String conversationId, {
    int count = 20,
    String? startClientMsgId,
  }) async {
    final client = ImClient.instance.client;
    if (client == null) return false;

    try {
      final req = im_msg.GetAdvancedHistoryMessageListParams(
        conversationId: conversationId,
        startClientMsgId: startClientMsgId ?? '',
        count: count,
        viewType: 0,
      );

      final result = await client.getAdvancedHistoryMessageList(req: req);

      if (result.errCode != 0) {
        appLog.w(
          '[MessageService] 加载历史消息失败: ${result.errMsg} (code: ${result.errCode})',
        );
        return false;
      }

      if (result.messageList.isEmpty) {
        return false;
      }

      final messages = result.messageList
          .map((msg) => _msgStructToMessage(msg))
          .toList();

      final currentMessages = _messages.putIfAbsent(conversationId, () => []);
      currentMessages.insertAll(0, messages.reversed);

      // 去重
      final seenIds = <String>{};
      _messages[conversationId] = currentMessages
          .where((msg) => seenIds.add(msg.id))
          .toList();

      _notifyMessagesChanged();
      return !result.isEnd;
    } catch (e) {
      appLog.e('[MessageService] 加载历史消息失败: $e');
      return false;
    }
  }

  /// 清除指定会话的消息
  void clearMessages(String conversationId) {
    _messages.remove(conversationId);
    _notifyMessagesChanged();
  }

  /// 通知消息变化
  void _notifyMessagesChanged() {
    if (!_isDisposed && !_messagesController.isClosed) {
      // 创建不可变的副本
      final messagesCopy = <String, List<Message>>{};
      _messages.forEach((key, value) {
        messagesCopy[key] = List.unmodifiable(value);
      });
      _messagesController.add(Map.unmodifiable(messagesCopy));
    }
  }

  /// 重置状态
  void reset() {
    _messages.clear();
    _currentUserId = '';
    stopListening();
  }

  /// 释放资源
  void dispose() {
    _isDisposed = true;
    reset();
    _messagesController.close();
  }
}
