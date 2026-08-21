import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../domain/models/conversation.dart';
import '../../../../domain/models/user.dart';
import '../../../../domain/models/user_profile.dart' show UserProfile;
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../utils/conversation_display.dart';
import '../../view_models/chat_list_view_model.dart';

/// 会话列表项内容行：头像角标、名称/标签/时间、消息预览。
class ChatListItemContent extends StatelessWidget {
  const ChatListItemContent({
    super.key,
    required this.conversation,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
    this.currentUserId,
    this.cachedUserProfile,
    this.previewText,
    this.timeText,
  });

  final Conversation conversation;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final String? currentUserId;
  final UserProfile? cachedUserProfile;
  final String? previewText;
  final String? timeText;

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

  @override
  Widget build(BuildContext context) {
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
        onLongPress: onLongPress,
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
}

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
