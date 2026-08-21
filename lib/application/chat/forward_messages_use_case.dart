import 'package:flutter_rust_demo/domain/models/chat_message.dart'
    show ChatMessage;
import 'package:flutter_rust_demo/domain/models/chat_session_type.dart'
    show ChatSessionType;

import 'message_service_notifier.dart';

typedef ForwardTarget = ({String id, bool isGroup});

/// 一次批量转发的执行结果。
class ForwardOutcome {
  const ForwardOutcome({
    required this.success,
    required this.failed,
    required this.cancelled,
  });

  final int success;
  final int failed;
  final bool cancelled;

  bool get isOk => failed == 0 && !cancelled;
}

/// 多选转发：逐目标发送、合并转发、取消与失败重试。
/// 只负责发送编排，状态展示由调用方（ChatDetailViewModel）映射。
class ForwardMessagesUseCase {
  ForwardMessagesUseCase({required this.messageService});

  final MessageServiceNotifier messageService;

  bool _cancelled = false;
  List<ChatMessage>? _lastMessages;
  List<String>? _lastSummaryList;
  List<ForwardTarget>? _failedTargets;
  String _lastTitle = '聊天记录';
  bool _lastMerge = false;

  List<ChatMessage>? get lastMessages => _lastMessages;
  List<String>? get lastSummaryList => _lastSummaryList;
  List<ForwardTarget>? get failedTargets => _failedTargets;
  String get lastTitle => _lastTitle;
  bool get lastMerge => _lastMerge;
  bool get hasFailedTargets =>
      _failedTargets != null && _failedTargets!.isNotEmpty;

  Future<ForwardOutcome> forwardToTargets({
    required List<ChatMessage> messages,
    required List<String> summaryList,
    required List<ForwardTarget> targets,
    required bool merge,
    String title = '聊天记录',
    void Function(int done)? onProgress,
  }) async {
    if (messages.isEmpty || targets.isEmpty) {
      return const ForwardOutcome(success: 0, failed: 0, cancelled: false);
    }

    _cancelled = false;
    var success = 0;
    var failed = 0;
    final failedTargets = <ForwardTarget>[];
    _lastMessages = messages;
    _lastSummaryList = summaryList;
    _lastTitle = title;
    _lastMerge = merge;

    for (final target in targets) {
      if (_cancelled) {
        _failedTargets = null;
        return ForwardOutcome(
          success: success,
          failed: failed,
          cancelled: true,
        );
      }
      try {
        await _forwardToTarget(
          messages: messages,
          summaryList: summaryList,
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
      onProgress?.call(success + failed);
    }

    _failedTargets = failedTargets.isEmpty ? null : failedTargets;
    return ForwardOutcome(success: success, failed: failed, cancelled: false);
  }

  void cancel() {
    _cancelled = true;
  }

  Future<ForwardOutcome> retryFailed({
    void Function(int done)? onProgress,
  }) async {
    final messages = _lastMessages;
    final targets = _failedTargets;
    if (messages == null || targets == null || targets.isEmpty) {
      return const ForwardOutcome(success: 0, failed: 0, cancelled: false);
    }
    return forwardToTargets(
      messages: messages,
      summaryList: _lastSummaryList ?? const [],
      targets: targets,
      merge: _lastMerge,
      title: _lastTitle,
      onProgress: onProgress,
    );
  }

  Future<void> _forwardToTarget({
    required List<ChatMessage> messages,
    required List<String> summaryList,
    required String targetId,
    required bool isGroup,
    required bool merge,
    required String title,
  }) async {
    final sessionType = isGroup
        ? ChatSessionType.writeGroupChat
        : ChatSessionType.singleChat;
    if (merge) {
      await messageService.sendMergerMessage(
        clientMsgIds: messages.map((m) => m.clientMsgId).toList(),
        sourceConversationId: targetId,
        title: title,
        summaryList: summaryList,
        sourceId: targetId,
        sessionType: sessionType,
      );
    } else {
      for (final message in messages) {
        await messageService.forwardMessage(
          clientMsgId: message.clientMsgId,
          sourceId: targetId,
          sessionType: sessionType,
        );
      }
    }
  }
}
