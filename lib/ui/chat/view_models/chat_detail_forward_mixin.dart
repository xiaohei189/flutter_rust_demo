import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/chat/forward_messages_use_case.dart';
import '../../../application/chat/message_service_notifier.dart';
import '../../../domain/models/chat_message.dart' show ChatMessage;
import '../../../domain/models/chat_session_type.dart' show ChatSessionType;
import '../mappers/message_display.dart';
import '../providers/message_service_provider.dart';
import 'chat_detail_view_model.dart';

/// 聊天详情页转发：单条/合并、批量目标、取消与失败重试。
/// 批量转发编排与重试状态委托给 [ForwardMessagesUseCase]。
mixin ChatDetailForwardMixin on FamilyNotifier<ChatDetailState, String> {
  MessageServiceNotifier get _messageService =>
      ref.read(messageServiceProvider.notifier);

  ForwardMessagesUseCase? _forwardUseCase;

  ForwardMessagesUseCase get _forwardUseCaseInstance => _forwardUseCase ??=
      ForwardMessagesUseCase(messageService: _messageService);

  Future<bool> forwardSelectedMessages({
    required List<ChatMessage> messages,
    required String targetId,
    required bool isGroup,
    required bool merge,
    String title = '聊天记录',
  }) async {
    if (messages.isEmpty) return false;
    final sessionType = isGroup
        ? ChatSessionType.writeGroupChat
        : ChatSessionType.singleChat;
    try {
      if (merge) {
        await _messageService.sendMergerMessage(
          clientMsgIds: messages.map((m) => m.clientMsgId).toList(),
          sourceConversationId: arg,
          title: title,
          summaryList: messages.map((m) => m.displayText).toList(),
          sourceId: targetId,
          sessionType: sessionType,
        );
      } else {
        for (final message in messages) {
          await _messageService.forwardMessage(
            clientMsgId: message.clientMsgId,
            sourceId: targetId,
            sessionType: sessionType,
          );
        }
      }
      state = state.copyWith(selectMode: false, selectedMessages: const []);
      return true;
    } catch (e) {
      state = state.copyWith(errorText: '转发失败: $e');
      return false;
    }
  }

  Future<bool> forwardSelectedMessagesToTargets({
    required List<ChatMessage> messages,
    required List<({String id, bool isGroup})> targets,
    required bool merge,
    String title = '聊天记录',
  }) async {
    if (messages.isEmpty || targets.isEmpty) return false;

    state = state.copyWith(
      isForwarding: true,
      forwardDone: 0,
      forwardTotal: targets.length,
      errorText: null,
    );
    final outcome = await _forwardUseCaseInstance.forwardToTargets(
      messages: messages,
      summaryList: messages.map((m) => m.displayText).toList(),
      targets: targets,
      merge: merge,
      title: title,
      onProgress: (done) => state = state.copyWith(forwardDone: done),
    );
    state = state.copyWith(
      isForwarding: false,
      forwardDone: 0,
      forwardTotal: 0,
    );

    if (outcome.cancelled) {
      state = state.copyWith(
        errorText: outcome.success == 0
            ? '已取消转发'
            : '已取消转发：成功 ${outcome.success} 个，未完成 ${targets.length - outcome.success} 个',
      );
      return false;
    }
    if (outcome.failed == 0) {
      state = state.copyWith(selectMode: false, selectedMessages: const []);
      return true;
    }
    state = state.copyWith(
      errorText: outcome.failed == targets.length
          ? '转发失败'
          : '部分转发失败：成功 ${outcome.success} 个，失败 ${outcome.failed} 个',
    );
    return false;
  }

  bool get hasFailedForwardTargets => _forwardUseCaseInstance.hasFailedTargets;

  Future<bool> retryFailedForwardTargets() async {
    final messages = _forwardUseCaseInstance.lastMessages;
    final targets = _forwardUseCaseInstance.failedTargets;
    if (messages == null || targets == null || targets.isEmpty) return false;
    return forwardSelectedMessagesToTargets(
      messages: messages,
      targets: targets,
      merge: _forwardUseCaseInstance.lastMerge,
      title: _forwardUseCaseInstance.lastTitle,
    );
  }

  void cancelForward() {
    _forwardUseCaseInstance.cancel();
  }
}
