import 'package:flutter/material.dart';

import '../../../../domain/models/conversation.dart';
import '../../../previews/app_theme_preview.dart';
import '../../../previews/fake_data.dart';
import '../../../../domain/models/user_profile.dart' show UserProfile;
import '../../../core/theme/app_theme.dart';
import 'chat_list_item_menu.dart';
import 'chat_list_item_content.dart';
import 'swipe_action_item.dart';
import '../../view_models/chat_list_view_model.dart';

/// 会话列表项：头像、标题、预览、时间、未读红点、静音图标；草稿红色/橙色；左滑操作、长按菜单。
class ChatListItem extends StatelessWidget {
  final Conversation conversation;
  final VoidCallback onTap;
  final bool isSelected;
  final String? currentUserId;
  final VoidCallback? onDelete;
  final VoidCallback? onPinToggle;
  final VoidCallback? onMarkRead;
  final VoidCallback? onMarkUnread;
  final VoidCallback? onMuteToggle;
  final VoidCallback? onClear;
  final VoidCallback? onFlagToggle;
  final VoidCallback? onDoneToggle;
  final VoidCallback? onArchive;
  final VoidCallback? onUnarchive;
  final VoidCallback? onMoveToFolder;
  final UserProfile? cachedUserProfile;

  /// 当前用户的本地头像路径（优先于 cachedUserProfile.faceUrl）
  final String? currentUserLocalAvatarPath;

  /// 已缓存的最近消息预览与展示时间，避免列表项重复解析。
  final String? previewText;
  final String? timeText;

  /// 多选管理模式：显示复选框，点击切换选中。
  final bool isSelectionMode;

  /// 单聊对方是否在线（null 表示未知）。
  final bool? isOnline;

  /// 正在输入预览文案。
  final String? typingText;

  /// 最近一条消息发送失败。
  final bool hasSendFailure;
  final VoidCallback? onRetrySend;

  const ChatListItem({
    super.key,
    required this.conversation,
    required this.onTap,
    this.isSelected = false,
    this.currentUserId,
    this.onDelete,
    this.onPinToggle,
    this.onMarkRead,
    this.onMarkUnread,
    this.onMuteToggle,
    this.onClear,
    this.onFlagToggle,
    this.onDoneToggle,
    this.onArchive,
    this.onUnarchive,
    this.onMoveToFolder,
    this.cachedUserProfile,
    this.currentUserLocalAvatarPath,
    this.previewText,
    this.timeText,
    this.isSelectionMode = false,
    this.isOnline,
    this.typingText,
    this.hasSendFailure = false,
    this.onRetrySend,
  });

  Widget _buildContent(BuildContext context) {
    return ChatListItemContent(
      conversation: conversation,
      isSelected: isSelected,
      currentUserId: currentUserId,
      cachedUserProfile: cachedUserProfile,
      previewText: previewText,
      timeText: timeText,
      isSelectionMode: isSelectionMode,
      isOnline: isOnline,
      typingText: typingText,
      hasSendFailure: hasSendFailure,
      onRetrySend: onRetrySend,
      onTap: onTap,
      onLongPress: (Rect rowRect) {
        if (isSelectionMode) return;
        showChatListItemMenu(
          context,
          rowRect: rowRect,
          conversation: conversation,
          isMuted: conversation.recvMsgOpt == 1,
          onPinToggle: onPinToggle,
          onMarkRead: onMarkRead,
          onMarkUnread: onMarkUnread,
          onMuteToggle: onMuteToggle,
          onClear: onClear,
          onFlagToggle: onFlagToggle,
          onDoneToggle: onDoneToggle,
          onArchive: onArchive,
          onUnarchive: onUnarchive,
          onDelete: onDelete,
        );
      },
    );
  }

  List<SwipeAction> _swipeActions(BuildContext context) {
    final colors = context.appColors;
    final hasUnread = ChatListViewModel.effectiveUnreadCount(conversation) > 0;
    return [
      if (hasUnread && onMarkRead != null)
        SwipeAction(
          label: '标为已读',
          color: colors.primary,
          icon: Icons.done_all,
          onPressed: onMarkRead!,
        ),
      if (!hasUnread && onMarkUnread != null)
        SwipeAction(
          label: '标为未读',
          color: colors.primary,
          icon: Icons.mark_email_unread,
          onPressed: onMarkUnread!,
        ),
      if (onPinToggle != null)
        SwipeAction(
          label: conversation.isPinned ? '取消置顶' : '置顶',
          color: colors.warning,
          icon: Icons.push_pin_outlined,
          onPressed: onPinToggle!,
        ),
      if (onDelete != null)
        SwipeAction(
          label: '删除',
          color: colors.danger,
          icon: Icons.delete_outline,
          onPressed: onDelete!,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final content = _buildContent(context);
    if (isSelectionMode) return content;
    final actions = _swipeActions(context);
    if (actions.isEmpty) return content;
    return SwipeActionItem(actions: actions, child: content);
  }
}

// ==================== 预览 ====================

Widget _previewChatListItem(Conversation conversation, {String? previewText}) {
  return Padding(
    padding: const EdgeInsets.all(16),
    child: ChatListItem(
      conversation: conversation,
      onTap: () {},
      currentUserId: kPreviewMyUserId,
      previewText: previewText,
      timeText: '10:30',
    ),
  );
}

@AppThemePreview(name: '单聊 - 普通', group: 'ChatListItem')
Widget chatListItemNormalPreview() {
  return _previewChatListItem(fakeConversation(), previewText: '在吗？');
}

@AppThemePreview(name: '单聊 - 未读 5 条', group: 'ChatListItem')
Widget chatListItemUnreadPreview() {
  return _previewChatListItem(
    fakeConversation(unreadCount: 5),
    previewText: '[图片]',
  );
}

@AppThemePreview(name: '单聊 - 置顶', group: 'ChatListItem')
Widget chatListItemPinnedPreview() {
  return _previewChatListItem(
    fakeConversation(isPinned: true),
    previewText: '好的，收到！',
  );
}

@AppThemePreview(name: '单聊 - 草稿', group: 'ChatListItem')
Widget chatListItemDraftPreview() {
  return _previewChatListItem(
    fakeConversation(draftText: '晚上一起吃饭吗？'),
    previewText: '晚上一起吃饭吗？',
  );
}

@AppThemePreview(name: '群聊 - 未读 99+（免打扰）', group: 'ChatListItem')
Widget chatListItemGroupPreview() {
  return _previewChatListItem(
    fakeConversation(
      showName: '产品讨论群',
      conversationId: 'sg_group_1001',
      conversationType: 2,
      groupId: 'group_1001',
      unreadCount: 99,
      recvMsgOpt: 1,
    ),
    previewText: '张三: 这个方案可以',
  );
}

@AppThemePreview(name: '单聊 - @我 标记', group: 'ChatListItem')
Widget chatListItemAtMePreview() {
  return _previewChatListItem(
    fakeConversation(
      conversationId: 'sg_group_1002',
      conversationType: 2,
      groupId: 'group_1002',
      showName: '需求评审群',
      groupAtType: 1,
    ),
    previewText: '李四: @你 看下需求',
  );
}

@AppThemePreview(name: '群聊 - 不在群内', group: 'ChatListItem')
Widget chatListItemNotInGroupPreview() {
  return _previewChatListItem(
    fakeConversation(
      conversationId: 'sg_group_1003',
      conversationType: 2,
      groupId: 'group_1003',
      showName: '已退出群聊',
      isNotInGroup: true,
    ),
    previewText: '你已不在该群',
  );
}
