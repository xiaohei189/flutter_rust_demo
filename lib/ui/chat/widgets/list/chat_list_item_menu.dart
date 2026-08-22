import 'package:flutter/material.dart';

import '../../../../domain/models/conversation.dart';
import '../../../../router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../view_models/chat_list_view_model.dart';

/// 会话列表项长按菜单：置顶、标为已读/未读、免打扰、标记、归档、清空、删除。
Future<void> showChatListItemMenu(
  BuildContext context, {
  required Conversation conversation,
  required bool isMuted,
  VoidCallback? onPinToggle,
  VoidCallback? onMarkRead,
  VoidCallback? onMarkUnread,
  VoidCallback? onMuteToggle,
  VoidCallback? onClear,
  VoidCallback? onFlagToggle,
  VoidCallback? onDoneToggle,
  VoidCallback? onArchive,
  VoidCallback? onUnarchive,
  VoidCallback? onMoveToFolder,
  VoidCallback? onDelete,
}) {
  final colors = context.appColors;
  final hasUnread = ChatListViewModel.effectiveUnreadCount(conversation) > 0;
  final isArchived = ChatListViewModel.isArchived(conversation);
  return showModalBottomSheet(
    context: context,
    builder: (ctx) => SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.push_pin_outlined),
              title: Text(conversation.isPinned ? '取消置顶' : '置顶'),
              onTap: () {
                AppRouter.goBack(ctx);
                onPinToggle?.call();
              },
            ),
            ListTile(
              leading: Icon(
                hasUnread ? Icons.done_all_outlined : Icons.mark_email_unread,
              ),
              title: Text(hasUnread ? '标为已读' : '标为未读'),
              onTap: () {
                AppRouter.goBack(ctx);
                if (hasUnread) {
                  onMarkRead?.call();
                } else {
                  onMarkUnread?.call();
                }
              },
            ),
            if (onMuteToggle != null)
              ListTile(
                leading: Icon(
                  isMuted
                      ? Icons.notifications_off_outlined
                      : Icons.notifications_none,
                ),
                title: Text(isMuted ? '取消免打扰' : '免打扰'),
                onTap: () {
                  AppRouter.goBack(ctx);
                  onMuteToggle();
                },
              ),
            if (onFlagToggle != null)
              ListTile(
                leading: Icon(
                  ChatListViewModel.isFlagged(conversation)
                      ? Icons.flag
                      : Icons.flag_outlined,
                ),
                title: Text(
                  ChatListViewModel.isFlagged(conversation) ? '取消标记' : '标记',
                ),
                onTap: () {
                  AppRouter.goBack(ctx);
                  onFlagToggle();
                },
              ),
            if (onDoneToggle != null)
              ListTile(
                leading: Icon(
                  ChatListViewModel.isDone(conversation)
                      ? Icons.check_circle
                      : Icons.check_circle_outline,
                ),
                title: Text(
                  ChatListViewModel.isDone(conversation) ? '取消已完成' : '标记已完成',
                ),
                onTap: () {
                  AppRouter.goBack(ctx);
                  onDoneToggle();
                },
              ),
            if (isArchived && onUnarchive != null)
              ListTile(
                leading: const Icon(Icons.unarchive_outlined),
                title: const Text('取消归档'),
                onTap: () {
                  AppRouter.goBack(ctx);
                  onUnarchive();
                },
              ),
            if (!isArchived && onArchive != null)
              ListTile(
                leading: const Icon(Icons.inventory_2_outlined),
                title: const Text('归档'),
                onTap: () {
                  AppRouter.goBack(ctx);
                  onArchive();
                },
              ),
            if (onMoveToFolder != null)
              ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: const Text('移动到分组'),
                onTap: () {
                  AppRouter.goBack(ctx);
                  onMoveToFolder();
                },
              ),
            if (onClear != null)
              ListTile(
                leading: const Icon(Icons.delete_sweep_outlined),
                title: const Text('清空聊天记录'),
                onTap: () {
                  AppRouter.goBack(ctx);
                  confirmClearChatHistory(context, onClear);
                },
              ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: colors.danger),
              title: Text('删除', style: TextStyle(color: colors.danger)),
              onTap: () {
                AppRouter.goBack(ctx);
                onDelete?.call();
              },
            ),
          ],
        ),
      ),
    ),
  );
}

/// 确认清空会话聊天记录。
Future<void> confirmClearChatHistory(
  BuildContext context,
  VoidCallback onClear,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('清空聊天记录'),
      content: const Text('确定清空该会话的所有聊天记录吗？'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text('清空', style: TextStyle(color: context.appColors.danger)),
        ),
      ],
    ),
  );
  if (confirmed == true && context.mounted) {
    onClear();
  }
}
