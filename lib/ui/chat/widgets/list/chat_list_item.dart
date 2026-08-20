import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../domain/models/conversation.dart';
import '../../../../domain/models/user.dart';
import '../../../previews/app_theme_preview.dart';
import '../../../previews/fake_data.dart';
import '../../../../router/app_router.dart';
import '../../../../domain/models/user_profile.dart' show UserProfile;
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../utils/conversation_display.dart';
import '../../view_models/chat_list_view_model.dart';

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

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static bool _isSameWeek(DateTime a, DateTime b) {
    final start = b.subtract(Duration(days: b.weekday - 1));
    final end = start.add(const Duration(days: 6));
    return !a.isBefore(start.subtract(const Duration(days: 1))) &&
        !a.isAfter(end.add(const Duration(days: 1)));
  }

  static const _weekdayZh = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

  String _formatTime(int? timeMs) {
    if (timeMs == null || timeMs <= 0) return '';
    final time = DateTime.fromMillisecondsSinceEpoch(timeMs);
    final now = DateTime.now();
    const formatToday = 'HH:mm';
    if (_isSameDay(time, now)) {
      return DateFormat(formatToday).format(time);
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (_isSameDay(time, yesterday)) {
      return '昨天';
    }
    if (_isSameWeek(time, now)) {
      return _weekdayZh[time.weekday - 1];
    }
    if (time.year == now.year) {
      return DateFormat('M/d').format(time);
    }
    return DateFormat('yyyy/M/d').format(time);
  }

  String get _conversationDisplayName {
    if (conversation.showName.isNotEmpty) return conversation.showName;
    final cid = conversation.conversationId;
    switch (conversation.conversationType) {
      case 1:
        if (conversation.userId.isNotEmpty &&
            !_isConversationIdPrefix(conversation.userId)) {
          return conversation.userId;
        }
        if (cid.startsWith('si_')) {
          final parts = cid.substring(3).split('_');
          if (parts.length >= 2) {
            final other = currentUserId != null && parts[0] == currentUserId
                ? parts[1]
                : parts[0];
            return other.isNotEmpty ? '用户 $other' : '未知用户';
          }
        }
        return '未知用户';
      case 2:
      case 3:
        if (conversation.groupId.isNotEmpty &&
            !_isConversationIdPrefix(conversation.groupId)) {
          return conversation.groupId;
        }
        if (cid.startsWith('sg_')) {
          final groupId = cid.substring(3);
          return groupId.isNotEmpty ? '群聊 $groupId' : '未知群组';
        }
        return '未知群组';
      case 4:
        return '通知';
      default:
        return _isConversationIdPrefix(cid) ? '会话' : cid;
    }
  }

  static bool _isConversationIdPrefix(String s) =>
      s.startsWith('si_') || s.startsWith('sg_') || s.startsWith('sn_');

  User _getUser() {
    String userId;
    String displayName;
    String? avatarUrl;

    if (conversation.conversationType == 1) {
      // 单聊：展示对方的信息
      if (conversation.userId.isNotEmpty &&
          conversation.userId != currentUserId) {
        userId = conversation.userId;
        displayName =
            cachedUserProfile?.nickname ??
            (conversation.showName.isNotEmpty
                ? conversation.showName
                : '用户 $userId');
        avatarUrl = cachedUserProfile?.faceUrl;
      } else if (currentUserId != null &&
          conversation.conversationId.startsWith('si_')) {
        // 从会话ID中解析对方ID
        final parts = conversation.conversationId.substring(3).split('_');
        if (parts.length >= 2) {
          final otherId = parts[0] == currentUserId ? parts[1] : parts[0];
          userId = otherId;
          displayName =
              cachedUserProfile?.nickname ??
              (conversation.showName.isNotEmpty
                  ? conversation.showName
                  : '用户 $otherId');
          avatarUrl = cachedUserProfile?.faceUrl;
        } else {
          userId = conversation.userId.isNotEmpty
              ? conversation.userId
              : conversation.conversationId;
          displayName = conversation.showName.isNotEmpty
              ? conversation.showName
              : '未知用户';
          avatarUrl = conversation.faceUrl.isNotEmpty
              ? conversation.faceUrl
              : null;
        }
      } else {
        userId = conversation.userId.isNotEmpty
            ? conversation.userId
            : conversation.conversationId;
        displayName = conversation.showName.isNotEmpty
            ? conversation.showName
            : '未知用户';
        avatarUrl = conversation.faceUrl.isNotEmpty
            ? conversation.faceUrl
            : null;
      }
    } else {
      // 群聊或其他类型：展示群组信息
      userId = conversation.groupId.isNotEmpty
          ? conversation.groupId
          : conversation.conversationId;
      displayName = conversation.showName.isNotEmpty
          ? conversation.showName
          : _conversationDisplayName;
      avatarUrl = conversation.faceUrl.isNotEmpty
          ? conversation.faceUrl
          : cachedUserProfile?.faceUrl;
    }

    // 优先使用缓存的用户资料头像，其次使用会话头像
    final finalAvatar = (avatarUrl != null && avatarUrl.isNotEmpty)
        ? avatarUrl
        : null;

    return User(
      id: userId,
      name: displayName,
      avatar: finalAvatar,
      status: null,
    );
  }

  /// 展示时间：取草稿时间和最新消息时间中较新的
  int get _displayTime {
    final draftTime = conversation.draftTextTime;
    final msgTime = conversation.latestMsgSendTime;
    if (draftTime > msgTime) return draftTime;
    return msgTime;
  }

  String get _contentPreview {
    if (conversation.draftText.isNotEmpty) {
      try {
        final map = jsonDecode(conversation.draftText) as Map<String, dynamic>?;
        final text = map?['text'] as String?;
        if (text != null && text.isNotEmpty) return text;
        // draftText 是 JSON 但无 text key，不显示原始 JSON
      } catch (_) {
        // 非 JSON 格式，直接作为纯文本
        return conversation.draftText;
      }
    }
    final preview = previewText ?? latestMessagePreview(conversation.latestMsg);
    return preview;
  }

  bool get _hasDraft => conversation.draftText.isNotEmpty;

  /// 免打扰：recvMsgOpt 1=接收但不通知
  bool get _isMuted => conversation.recvMsgOpt == 1;

  bool get _isGroup =>
      conversation.conversationType == 2 || conversation.conversationType == 3;

  Widget _buildContent(BuildContext context) {
    final colors = context.appColors;
    final user = _getUser();
    final unread = conversation.unreadCount;
    final isPinned = conversation.isPinned;

    return Material(
      color: isPinned
          ? colors.surfaceMuted
          : (isSelected
                ? colors.primary.withValues(alpha: 0.06)
                : colors.surface),
      child: InkWell(
        onTap: onTap,
        onLongPress: () => _showLongPressMenu(context),
        child: Column(
          children: [
            Container(
              height: 72,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  // 头像（带未读红点角标）
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      UserAvatar(user: user, radius: 24),
                      if (unread > 0)
                        Positioned(
                          right: -4,
                          top: -4,
                          child: Container(
                            constraints: const BoxConstraints(
                              minWidth: 18,
                              minHeight: 18,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: _isMuted
                                  ? colors.textSecondary
                                  : colors.danger,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: colors.surface,
                                width: 1.5,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              unread > 99 ? '99+' : '$unread',
                              style: TextStyle(
                                color: colors.surface,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  // 内容区
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 第一行：名称 + 标签 + 时间
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                user.name,
                                style: TextStyle(
                                  color: colors.textPrimary,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 16,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (_isGroup)
                              const _TagLabel(
                                text: '群聊',
                                color: Color(0xFF4CAF50),
                              ),
                            if (conversation.conversationType == 4)
                              const _TagLabel(
                                text: '通知',
                                color: Color(0xFF607D8B),
                              ),
                            if (ChatListViewModel.isAtMeConversation(
                              conversation,
                            ))
                              _TagLabel(
                                text: '@我',
                                color: context.appColors.primary,
                              ),
                            if (conversation.isPrivateChat ||
                                conversation.isMsgDestruct)
                              const _TagLabel(
                                text: '私聊',
                                color: Color(0xFFFF9800),
                              ),
                            if (conversation.burnDuration > 0 ||
                                conversation.isMsgDestruct)
                              const _TagLabel(
                                text: '阅后即焚',
                                color: Color(0xFFE91E63),
                              ),
                            if (conversation.isNotInGroup)
                              _TagLabel(text: '不在群内', color: colors.danger),
                            if (_isMuted)
                              Padding(
                                padding: const EdgeInsets.only(left: 4),
                                child: Icon(
                                  Icons.notifications_off_outlined,
                                  size: 14,
                                  color: colors.textSecondary.withValues(
                                    alpha: 0.6,
                                  ),
                                ),
                              ),
                            const SizedBox(width: 8),
                            Text(
                              timeText ?? _formatTime(_displayTime),
                              style: TextStyle(
                                fontSize: 12,
                                color: unread > 0
                                    ? colors.primary
                                    : colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // 第二行：消息预览
                        RichText(
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          text: TextSpan(
                            style: TextStyle(
                              fontSize: 13,
                              color: colors.textSecondary,
                            ),
                            children: [
                              if (_hasDraft)
                                TextSpan(
                                  text: '[草稿] ',
                                  style: TextStyle(color: colors.warning),
                                ),
                              TextSpan(text: _contentPreview),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // 底部分割线（缩进到头像之后）
            Padding(
              padding: const EdgeInsets.only(left: 68),
              child: Divider(height: 1, color: colors.divider),
            ),
          ],
        ),
      ),
    );
  }

  void _showLongPressMenu(BuildContext context) {
    final colors = context.appColors;
    showModalBottomSheet(
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
                  _isMuted
                      ? Icons.notifications_off_outlined
                      : Icons.notifications_none,
                ),
                title: Text(_isMuted ? '取消免打扰' : '免打扰'),
                onTap: () {
                  AppRouter.goBack(ctx);
                  onMuteToggle!();
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
                  onFlagToggle!();
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
                  onDoneToggle!();
                },
              ),
            if (onClear != null)
              ListTile(
                leading: const Icon(Icons.delete_sweep_outlined),
                title: const Text('清空聊天记录'),
                onTap: () {
                  AppRouter.goBack(ctx);
                  _confirmClear(context);
                },
              ),
            if (onHide != null)
              ListTile(
                leading: const Icon(Icons.visibility_off_outlined),
                title: const Text('不显示该聊天'),
                onTap: () {
                  AppRouter.goBack(ctx);
                  onHide!();
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

  Future<void> _confirmClear(BuildContext context) async {
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
            child: Text(
              '清空',
              style: TextStyle(color: context.appColors.danger),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      onClear?.call();
    }
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
class _TagLabel extends StatelessWidget {
  const _TagLabel({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
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
