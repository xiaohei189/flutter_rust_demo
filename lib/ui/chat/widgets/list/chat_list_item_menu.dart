import 'package:flutter/material.dart';

import '../../../../domain/models/conversation.dart';
import '../../../../router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../view_models/chat_list_view_model.dart';

/// 会话列表项长按菜单：置顶、已读、免打扰、标记、清空、隐藏、删除。
Future<void> showChatListItemMenu(
  BuildContext context, {
  required Conversation conversation,
  required bool isMuted,
  VoidCallback? onPinToggle,
  VoidCallback? onMarkRead,
  VoidCallback? onMuteToggle,
  VoidCallback? onClear,
  VoidCallback? onFlagToggle,
  VoidCallback? onDoneToggle,
  VoidCallback? onHide,
  VoidCallback? onDelete,
}) {
  final colors = context.appColors;
  return showModalBottomSheet(
    context: context,
    builder: (ctx) => SafeArea(
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
            leading: const Icon(Icons.done_all_outlined),
            title: const Text('标为已读'),
            onTap: () {
              AppRouter.goBack(ctx);
              onMarkRead?.call();
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
          if (onClear != null)
            ListTile(
              leading: const Icon(Icons.delete_sweep_outlined),
              title: const Text('清空聊天记录'),
              onTap: () {
                AppRouter.goBack(ctx);
                confirmClearChatHistory(context, onClear);
              },
            ),
          if (onHide != null)
            ListTile(
              leading: const Icon(Icons.visibility_off_outlined),
              title: const Text('不显示该聊天'),
              onTap: () {
                AppRouter.goBack(ctx);
                onHide();
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
