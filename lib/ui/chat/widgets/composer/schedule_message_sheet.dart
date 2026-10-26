import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/models/scheduled_message.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/scheduled_message_provider.dart';

/// 定时消息的时间展示：今天只显示 `HH:mm`，跨天带上日期。
String formatScheduledTime(DateTime time, {DateTime? now}) {
  final current = now ?? DateTime.now();
  String two(int value) => value.toString().padLeft(2, '0');
  final hm = '${two(time.hour)}:${two(time.minute)}';
  final sameDay =
      time.year == current.year &&
      time.month == current.month &&
      time.day == current.day;
  return sameDay ? hm : '${two(time.month)}-${two(time.day)} $hm';
}

/// 「定时消息」弹层：选发送时间 + 查看/取消本会话已定时消息。
///
/// 定时仅在应用运行时触发；应用关闭期间到点的消息会在下次启动登录后补发。
class ScheduleMessageSheet extends ConsumerStatefulWidget {
  const ScheduleMessageSheet({
    super.key,
    required this.conversationId,
    required this.text,
    required this.onSchedule,
  });

  final String conversationId;
  final String text;
  final Future<bool> Function(DateTime scheduledAt) onSchedule;

  @override
  ConsumerState<ScheduleMessageSheet> createState() =>
      _ScheduleMessageSheetState();
}

class _ScheduleMessageSheetState extends ConsumerState<ScheduleMessageSheet> {
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final pending = ref.watch(
      scheduledMessagesProvider.select(
        (messages) => [
          for (final message in messages)
            if (message.conversationId == widget.conversationId) message,
        ],
      ),
    );

    return Material(
      color: colors.surface,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.7,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                child: Row(
                  children: [
                    Text(
                      '定时消息',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      tooltip: '关闭',
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: colors.divider.withValues(alpha: 0.6)),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                  children: [
                    _buildPreview(colors),
                    const SizedBox(height: 18),
                    Text(
                      '选择发送时间',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildChip(Icons.schedule, '10 分钟后', 10),
                        _buildChip(Icons.schedule, '30 分钟后', 30),
                        _buildChip(Icons.schedule, '1 小时后', 60),
                        _buildChip(Icons.edit_calendar_outlined, '自定义…', null),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '仅在应用运行时触发；应用关闭期间到点的消息会在下次启动后补发。',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Divider(
                      height: 1,
                      color: colors.divider.withValues(alpha: 0.6),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      pending.isEmpty ? '已定时' : '已定时 · ${pending.length} 条',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (pending.isEmpty)
                      Text(
                        '本会话还没有定时消息',
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.textSecondary,
                        ),
                      )
                    else
                      for (final message in pending) _buildPendingRow(message),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreview(AppColors colors) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      ),
      child: Text(
        widget.text,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 14, height: 1.4, color: colors.textPrimary),
      ),
    );
  }

  Widget _buildChip(IconData icon, String label, int? minutes) {
    final colors = context.appColors;
    return ActionChip(
      avatar: Icon(icon, size: 16, color: colors.primary),
      label: Text(label),
      onPressed: _submitting
          ? null
          : () {
              if (minutes == null) {
                _pickCustomTime();
              } else {
                _scheduleAt(DateTime.now().add(Duration(minutes: minutes)));
              }
            },
    );
  }

  Widget _buildPendingRow(ScheduledMessage message) {
    final colors = context.appColors;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: Icon(
        Icons.schedule_send_outlined,
        size: 20,
        color: colors.primary,
      ),
      title: Text(
        '${formatScheduledTime(message.scheduledDateTime)} 发送',
        style: TextStyle(fontSize: 13, color: colors.textPrimary),
      ),
      subtitle: Text(
        message.text.replaceAll('\n', ' '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 12, color: colors.textSecondary),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.close, size: 18),
        tooltip: '取消定时',
        onPressed: () =>
            ref.read(scheduledMessagesProvider.notifier).cancel(message.id),
      ),
    );
  }

  Future<void> _pickCustomTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(minutes: 10))),
    );
    if (time == null || !mounted) return;
    final at = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    await _scheduleAt(at);
  }

  Future<void> _scheduleAt(DateTime at) async {
    if (!mounted) return;
    if (!at.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请选择晚于当前时间的时间')));
      return;
    }
    setState(() => _submitting = true);
    var ok = false;
    try {
      ok = await widget.onSchedule(at);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
    if (!mounted) return;
    if (ok) Navigator.of(context).pop();
  }
}
