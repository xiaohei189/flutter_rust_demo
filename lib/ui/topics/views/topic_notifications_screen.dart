import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../application/topics/topic_notification_controller.dart';
import '../../../domain/models/topic_notification.dart';
import '../../../router/app_router.dart';
import '../../chat/providers/conversation_provider.dart';
import '../../core/theme/app_theme.dart';

class TopicNotificationsScreen extends ConsumerWidget {
  const TopicNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final items = ref.watch(topicNotificationsProvider);
    final unread = ref.watch(unreadTopicNotificationCountProvider);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('话题通知'),
        actions: [
          if (unread > 0)
            TextButton(
              onPressed: () =>
                  ref.read(topicNotificationsProvider.notifier).markAllRead(),
              child: const Text('全部已读'),
            ),
        ],
      ),
      body: items.isEmpty
          ? Center(
              child: Text(
                '暂无话题通知',
                style: TextStyle(color: colors.textSecondary),
              ),
            )
          : RefreshIndicator(
              onRefresh: () =>
                  ref.read(topicNotificationsProvider.notifier).load(),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: items.length,
                separatorBuilder: (_, __) =>
                    Divider(height: 1, indent: 72, color: colors.divider),
                itemBuilder: (context, index) {
                  final item = items[index];
                  final conversation = ref.watch(
                    conversationByIdProvider('sg_${item.groupId}'),
                  );
                  return _NotificationTile(
                    item: item,
                    groupName: conversation?.showName ?? '话题群',
                    onTap: () async {
                      await ref
                          .read(topicNotificationsProvider.notifier)
                          .markRead(item.id);
                      if (context.mounted) {
                        await AppRouter.goToTopicDetail(
                          context,
                          groupId: item.groupId,
                          topicId: item.topicId,
                        );
                      }
                    },
                  );
                },
              ),
            ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.item,
    required this.groupName,
    required this.onTap,
  });

  final TopicNotification item;
  final String groupName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Material(
      color: item.read
          ? colors.surface
          : colors.primary.withValues(alpha: 0.06),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                ),
                child: Icon(_icon, color: colors.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontWeight: item.read
                                  ? FontWeight.w500
                                  : FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          DateFormat('MM-dd HH:mm').format(
                            DateTime.fromMillisecondsSinceEpoch(item.createdAt),
                          ),
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: colors.textSecondary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      groupName,
                      style: TextStyle(color: colors.primary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (!item.read) ...[
                const SizedBox(width: 8),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: colors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  IconData get _icon => switch (item.type) {
    TopicNotificationType.newTopic => Icons.forum_outlined,
    TopicNotificationType.reply => Icons.reply_outlined,
    TopicNotificationType.mention => Icons.alternate_email,
    TopicNotificationType.stateChanged => Icons.info_outline,
    TopicNotificationType.rootEdited => Icons.edit_note,
    TopicNotificationType.taskAssigned => Icons.assignment_ind_outlined,
    TopicNotificationType.taskChanged => Icons.task_alt,
  };
}
