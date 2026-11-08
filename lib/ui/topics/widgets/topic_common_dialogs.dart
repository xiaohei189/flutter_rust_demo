import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../domain/models/group_member.dart';
import '../../../domain/models/topic.dart';
import '../../core/theme/app_theme.dart';

typedef TopicTaskDraft = ({
  String title,
  String description,
  String assigneeId,
  int dueAt,
  TopicTaskPriority priority,
});

Future<String?> showEditTopicDialog({
  required BuildContext context,
  required String initialText,
}) async {
  final controller = TextEditingController(text: initialText);
  final result = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      surfaceTintColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusSheet),
      ),
      title: const Text('编辑话题'),
      content: TextField(
        controller: controller,
        autofocus: true,
        minLines: 4,
        maxLines: 12,
        decoration: const InputDecoration(hintText: '输入话题正文'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            final value = controller.text.trim();
            if (value.isNotEmpty) {
              Navigator.of(dialogContext).pop(value);
            }
          },
          child: const Text('保存'),
        ),
      ],
    ),
  );
  await Future<void>.delayed(const Duration(milliseconds: 350));
  controller.dispose();
  return result;
}

Future<TopicTaskDraft?> showCreateTopicTaskDialog({
  required BuildContext context,
  required List<GroupMember> members,
}) async {
  if (members.isEmpty) return null;
  final title = TextEditingController();
  final description = TextEditingController();
  var assigneeId = members.first.userId;
  var priority = TopicTaskPriority.normal;
  DateTime? dueAt;
  final result = await showDialog<TopicTaskDraft>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        surfaceTintColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusSheet),
        ),
        title: const Text('添加任务'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: title,
                autofocus: true,
                decoration: const InputDecoration(labelText: '任务名称'),
              ),
              TextField(
                controller: description,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(labelText: '任务说明（可选）'),
              ),
              DropdownButtonFormField<String>(
                initialValue: assigneeId,
                decoration: const InputDecoration(labelText: '负责人'),
                items: [
                  for (final member in members)
                    DropdownMenuItem(
                      value: member.userId,
                      child: Text(
                        member.nickname.isEmpty
                            ? member.userId
                            : member.nickname,
                      ),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() => assigneeId = value);
                  }
                },
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<TopicTaskPriority>(
                initialValue: priority,
                decoration: const InputDecoration(labelText: '优先级'),
                items: const [
                  DropdownMenuItem(
                    value: TopicTaskPriority.low,
                    child: Text('低'),
                  ),
                  DropdownMenuItem(
                    value: TopicTaskPriority.normal,
                    child: Text('普通'),
                  ),
                  DropdownMenuItem(
                    value: TopicTaskPriority.high,
                    child: Text('高'),
                  ),
                  DropdownMenuItem(
                    value: TopicTaskPriority.urgent,
                    child: Text('紧急'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() => priority = value);
                  }
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_outlined),
                title: const Text('截止时间'),
                subtitle: Text(
                  dueAt == null
                      ? '未设置'
                      : DateFormat('yyyy-MM-dd HH:mm').format(dueAt!),
                ),
                onTap: () async {
                  final now = DateTime.now();
                  final date = await showDatePicker(
                    context: dialogContext,
                    initialDate: dueAt ?? now,
                    firstDate: now,
                    lastDate: now.add(const Duration(days: 3650)),
                  );
                  if (date == null || !dialogContext.mounted) return;
                  final time = await showTimePicker(
                    context: dialogContext,
                    initialTime: TimeOfDay.fromDateTime(dueAt ?? now),
                  );
                  if (time == null) return;
                  setDialogState(() {
                    dueAt = DateTime(
                      date.year,
                      date.month,
                      date.day,
                      time.hour,
                      time.minute,
                    );
                  });
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final value = title.text.trim();
              if (value.isEmpty) return;
              Navigator.of(dialogContext).pop((
                title: value,
                description: description.text.trim(),
                assigneeId: assigneeId,
                dueAt: dueAt?.millisecondsSinceEpoch ?? 0,
                priority: priority,
              ));
            },
            child: const Text('创建'),
          ),
        ],
      ),
    ),
  );
  await Future<void>.delayed(const Duration(milliseconds: 350));
  title.dispose();
  description.dispose();
  return result;
}
