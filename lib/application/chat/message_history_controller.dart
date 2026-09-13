import 'package:flutter_rust_demo/data/repositories/message_repository.dart';
import 'package:flutter_rust_demo/data/services/im_client.dart';
import 'package:flutter_rust_demo/domain/message_sorting.dart'
    show sortMessagesByTime;
import 'package:flutter_rust_demo/domain/models/chat_message.dart'
    show ChatMessage;
import 'package:flutter_rust_demo/core/utils/app_logger.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

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
      final merged = mergeHistoryPage(
        existing: currentMessages,
        incoming: incoming,
      );
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

  /// 合并新拉取的历史分页与已有消息列表。
  ///
  /// 分页结果放在前面（同一 clientMsgId 以新拉取到的为准），只对分页结果建 ID
  /// 集合、已有列表用 contains 过滤：避免 `insertAll(0, ...)` 的 O(n) 位移与
  /// 逐条 `Set.add` 的二次全量遍历，也保证不修改传入列表（旧状态仍被 UI 持有）。
  @visibleForTesting
  static List<ChatMessage> mergeHistoryPage({
    required List<ChatMessage> existing,
    required List<ChatMessage> incoming,
  }) {
    final merged = <ChatMessage>[];
    final incomingIds = <String>{};
    for (final msg in incoming) {
      if (incomingIds.add(msg.clientMsgId)) merged.add(msg);
    }
    for (final msg in existing) {
      if (!incomingIds.contains(msg.clientMsgId)) merged.add(msg);
    }
    return merged;
  }
}
