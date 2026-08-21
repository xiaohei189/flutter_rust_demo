import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/chat/message_service_notifier.dart';
import '../../../domain/models/chat_message.dart' show ChatMessage;
import '../../../domain/models/chat_session_type.dart' show ChatSessionType;
import '../mappers/message_display.dart';
import '../providers/message_service_provider.dart';
import 'chat_detail_view_model.dart';

/// 聊天详情页转发：单条/合并、批量目标、取消与失败重试。
mixin ChatDetailForwardMixin on FamilyNotifier<ChatDetailState, String> {
  MessageServiceNotifier get _messageService =>
      ref.read(messageServiceProvider.notifier);

  bool _forwardCancelled = false;
  List<ChatMessage>? _lastForwardMessages;
  List<({String id, bool isGroup})>? _failedForwardTargets;
  String _lastForwardTitle = '聊天记录';
  bool _lastForwardMerge = false;

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
    _forwardCancelled = false;
    var success = 0;
    var failed = 0;
    final failedTargets = <({String id, bool isGroup})>[];
    _lastForwardMessages = messages;
    _lastForwardTitle = title;
    _lastForwardMerge = merge;

    try {
      for (final target in targets) {
        if (_forwardCancelled) {
          state = state.copyWith(
            errorText: success == 0
                ? '已取消转发'
                : '已取消转发：成功 $success 个，未完成 ${targets.length - success} 个',
          );
          _failedForwardTargets = null;
          return false;
        }
        try {
          await _forwardToTarget(
            messages: messages,
            targetId: target.id,
            isGroup: target.isGroup,
            merge: merge,
            title: title,
          );
          success++;
        } catch (_) {
          failed++;
          failedTargets.add(target);
        }
        state = state.copyWith(forwardDone: success + failed);
      }
      if (failed == 0) {
        _failedForwardTargets = null;
        state = state.copyWith(selectMode: false, selectedMessages: const []);
        return true;
      }
      _failedForwardTargets = failedTargets;
      state = state.copyWith(
        errorText: failed == targets.length
            ? '转发失败'
            : '部分转发失败：成功 $success 个，失败 $failed 个',
      );
      return false;
    } finally {
      state = state.copyWith(
        isForwarding: false,
        forwardDone: 0,
        forwardTotal: 0,
      );
    }
  }

  bool get hasFailedForwardTargets =>
      _failedForwardTargets != null && _failedForwardTargets!.isNotEmpty;

  Future<bool> retryFailedForwardTargets() async {
    final messages = _lastForwardMessages;
    final targets = _failedForwardTargets;
    if (messages == null || targets == null || targets.isEmpty) return false;
    return forwardSelectedMessagesToTargets(
      messages: messages,
      targets: targets,
      merge: _lastForwardMerge,
      title: _lastForwardTitle,
    );
  }

  void cancelForward() {
    _forwardCancelled = true;
  }

  Future<void> _forwardToTarget({
    required List<ChatMessage> messages,
    required String targetId,
    required bool isGroup,
    required bool merge,
    required String title,
  }) async {
    final sessionType = isGroup
        ? ChatSessionType.writeGroupChat
        : ChatSessionType.singleChat;
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
  }
}
