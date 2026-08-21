import 'package:flutter_rust_demo/data/mappers/message_mapper.dart';
import 'package:flutter_rust_demo/data/repositories/message_repository.dart';
import 'package:flutter_rust_demo/data/services/im_client.dart';
import 'package:flutter_rust_demo/domain/message_sorting.dart'
    show sortMessagesByTime;
import 'package:flutter_rust_demo/domain/models/chat_message.dart'
    show ChatMessage;
import 'package:flutter_rust_demo/core/utils/app_logger.dart';

import 'message_service_notifier.dart';
import 'message_service_reducer.dart';

/// 历史消息与消息列表：加载分页、写入发送结果、查询与移除。
class MessageHistoryController {
  MessageHistoryController(this.service, this.imClient, this.repository);

  final MessageServiceNotifier service;
  final ImClient imClient;
  final MessageRepository repository;

  bool get _isClientReady => imClient.isInitialized;

  List<ChatMessage> getMessages(String conversationId) {
    return List.unmodifiable(
      sortMessagesByTime(
        service.currentState.messages[conversationId] ?? const [],
      ),
    );
  }

  /// 将发送结果写入全局消息状态（替代已移除的 messageSent 事件）
  void upsertSentMessage(String conversationId, ChatMessage result) {
    final state = service.currentState;
    final newMessages = Map<String, List<ChatMessage>>.from(state.messages);
    final list = newMessages.putIfAbsent(conversationId, () => []);
    final idx = list.indexWhere((m) => m.clientMsgId == result.clientMsgId);
    final msgInfo = ChatMessage(
      clientMsgId: result.clientMsgId,
      serverMsgId: result.serverMsgId,
      sendId: result.sendId,
      recvId: result.recvId,
      groupId: result.groupId,
      senderPlatformId: result.senderPlatformId,
      senderNickname: result.senderNickname,
      senderFaceUrl: result.senderFaceUrl,
      sessionType: result.sessionType,
      msgFrom: result.msgFrom,
      contentType: result.contentType,
      content: result.content,
      seq: result.seq,
      sendTime: normalizeMessageSendTime(result.sendTime.toInt()),
      createTime: result.createTime > 0
          ? result.createTime
          : normalizeMessageSendTime(result.sendTime.toInt()),
      status: result.status,
      isRead: false,
      attachedInfo: '',
      ex: '',
    );
    if (idx >= 0) {
      list[idx] = msgInfo;
    } else {
      service.seenClientMsgIds.add(result.clientMsgId);
      list.add(msgInfo);
    }
    newMessages[conversationId] = List<ChatMessage>.from(list);
    service.updateState(state.copyWith(messages: newMessages));
  }

  Future<bool> loadHistoryMessages(
    String conversationId, {
    int count = 20,
    String startClientMsgId = '',
  }) async {
    if (!_isClientReady) return false;

    try {
      appLog.i(
        '[MSG] Service 加载历史消息: conv=$conversationId count=$count start=$startClientMsgId',
      );
      final result = await repository.getHistoryMessages(
        conversationId: conversationId,
        startClientMsgId: startClientMsgId,
        count: count,
      );

      if (result.messages.isEmpty) {
        appLog.i(
          '[MSG] Service 空页: conv=$conversationId isEnd=${result.isEnd}',
        );
        return !result.isEnd;
      }

      final state = service.currentState;
      final newMessages = Map<String, List<ChatMessage>>.from(state.messages);
      final currentMessages = newMessages.putIfAbsent(conversationId, () => []);
      final beforeCount = currentMessages.length;

      final incoming = result.messages;
      currentMessages.insertAll(0, incoming);

      final seenIds = <String>{};
      final merged = currentMessages
          .where((msg) => seenIds.add(msg.clientMsgId))
          .toList();
      final dedupRemoved = beforeCount + incoming.length - merged.length;
      newMessages[conversationId] = merged;

      final firstSeq = result.messages.isNotEmpty
          ? result.messages.first.seq
          : 0;
      final lastSeq = incoming.isNotEmpty ? incoming.last.seq : 0;

      appLog.i(
        '[MSG] Service 加载完成: conv=$conversationId start=$startClientMsgId '
        'new=${result.messages.length} firstSeq=$firstSeq lastSeq=$lastSeq '
        'dedupRemoved=$dedupRemoved isEnd=${result.isEnd}',
      );

      service.updateState(state.copyWith(messages: newMessages));

      return !result.isEnd;
    } catch (e) {
      appLog.e('dart MessageService ❌ 加载历史消息失败: $e');
      rethrow;
    }
  }

  /// 移除指定消息（用于重发成功后替换旧的失败消息）。
  void removeMessage(String conversationId, String clientMsgId) {
    service.updateState(
      MessageServiceReducer.removeMessage(
        service.currentState,
        conversationId,
        clientMsgId,
      ),
    );
  }
}
