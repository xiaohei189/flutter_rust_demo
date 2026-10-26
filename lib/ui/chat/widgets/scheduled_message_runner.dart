import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/chat_send_target.dart';
import '../../../domain/models/conversation.dart';
import '../../../domain/models/scheduled_message.dart';
import '../../../providers/current_user_provider.dart';
import '../providers/conversation_provider.dart';
import '../providers/message_provider.dart';
import '../providers/scheduled_message_provider.dart';

/// 应用级定时消息派发器：到点后走普通文本消息链路发送。
///
/// 只在应用进程存活时触发（前台每 10s 轮询一次 + 回到前台立即补一次）；
/// 关闭期间到点的消息会在下次启动登录后补发。
class ScheduledMessageRunner extends ConsumerStatefulWidget {
  const ScheduledMessageRunner({
    super.key,
    required this.child,
    this.tickInterval = const Duration(seconds: 10),
    this.sendOverride,
  });

  final Widget child;
  final Duration tickInterval;

  /// 测试钩子：替换真实发送链路（默认走 [messageListProvider]）。
  final Future<bool> Function(
    ScheduledMessage message,
    Conversation conversation,
  )?
  sendOverride;

  @override
  ConsumerState<ScheduledMessageRunner> createState() =>
      _ScheduledMessageRunnerState();
}

class _ScheduledMessageRunnerState extends ConsumerState<ScheduledMessageRunner>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool _ticking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(widget.tickInterval, (_) => unawaited(_tick()));
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_tick()));
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_tick());
  }

  Future<void> _tick() async {
    if (_ticking || !mounted) return;
    _ticking = true;
    try {
      final due = ref
          .read(scheduledMessagesProvider)
          .where((message) => message.isDue(DateTime.now()))
          .toList();
      if (due.isEmpty) return;
      final currentUserId = ref.read(currentUserIdProvider);
      if (currentUserId.isEmpty) return;

      for (final message in due) {
        if (!mounted) return;
        final conversation = ref.read(
          conversationByIdProvider(message.conversationId),
        );
        if (conversation == null) continue;

        final override = widget.sendOverride;
        if (override != null) {
          await override(message, conversation);
        } else {
          final target = chatSendTargetOf(conversation, currentUserId);
          if (target == null) continue;
          await ref
              .read(messageListProvider(message.conversationId).notifier)
              .sendTextMessage(
                recvId: target.recvId,
                text: message.text,
                sessionType: target.sessionType,
                groupId: target.groupId,
              );
        }
        // 不论成败都清掉定时项：失败会在气泡上标红并可手动重发，
        // 留着会每轮重复发送同一段文本。
        await ref.read(scheduledMessagesProvider.notifier).remove(message.id);
      }
    } finally {
      _ticking = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
