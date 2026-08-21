import 'package:flutter/material.dart';

import '../../../../domain/models/conversation.dart';
import '../../../previews/app_theme_preview.dart';
import '../../../previews/fake_data.dart';
import '../../../../domain/models/user_profile.dart' show UserProfile;
import '../../../core/theme/app_theme.dart';
import 'chat_list_item_menu.dart';
import 'chat_list_item_content.dart';

/// 会话列表项：头像、标题、预览、时间、未读红点、静音图标；草稿红色/橙色；长按菜单、左滑删除
class ChatListItem extends StatelessWidget {
  final Conversation conversation;
  final VoidCallback onTap;
  final bool isSelected;
  final String? currentUserId;
  final VoidCallback? onDelete;
  final VoidCallback? onPinToggle;
  final VoidCallback? onMarkRead;
  final VoidCallback? onMuteToggle;
  final VoidCallback? onClear;
  final VoidCallback? onFlagToggle;
  final VoidCallback? onDoneToggle;
  final VoidCallback? onHide;
  final UserProfile? cachedUserProfile;

  /// 当前用户的本地头像路径（优先于 cachedUserProfile.faceUrl）
  final String? currentUserLocalAvatarPath;

  /// 已缓存的最近消息预览与展示时间，避免列表项重复解析。
  final String? previewText;
  final String? timeText;

  /// 列表索引，用于 Dismissible 的 key，避免删除时重建冲突
  final int? itemIndex;

  const ChatListItem({
    super.key,
    required this.conversation,
    required this.onTap,
    this.isSelected = false,
    this.currentUserId,
    this.onDelete,
    this.onPinToggle,
    this.onMarkRead,
    this.onMuteToggle,
    this.onClear,
    this.onFlagToggle,
    this.onDoneToggle,
    this.onHide,
    this.cachedUserProfile,
    this.currentUserLocalAvatarPath,
    this.previewText,
    this.timeText,
    this.itemIndex,
  });

  Widget _buildContent(BuildContext context) {
    return ChatListItemContent(
      conversation: conversation,
      isSelected: isSelected,
      currentUserId: currentUserId,
      cachedUserProfile: cachedUserProfile,
      previewText: previewText,
      timeText: timeText,
      onTap: onTap,
      onLongPress: () => showChatListItemMenu(
        context,
        conversation: conversation,
        isMuted: conversation.recvMsgOpt == 1,
        onPinToggle: onPinToggle,
        onMarkRead: onMarkRead,
        onMuteToggle: onMuteToggle,
        onClear: onClear,
        onFlagToggle: onFlagToggle,
        onDoneToggle: onDoneToggle,
        onHide: onHide,
        onDelete: onDelete,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    if (onDelete != null) {
      return Dismissible(
        key: ValueKey<String>(
          '${conversation.conversationId}_${itemIndex ?? 0}',
        ),
        direction: DismissDirection.endToStart,
        background: Container(
          color: colors.danger,
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          child: Icon(Icons.delete_outline, color: colors.surface, size: 28),
        ),
        onDismissed: (_) => onDelete!(),
        child: _buildContent(context),
      );
    }
    return _buildContent(context);
  }
}

/// 名称后的小标签（群聊/外部/机器人等）
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
      itemIndex: 0,
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
    previewText: '李四: 新版原型已经上传',
  );
}
