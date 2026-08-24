import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../mappers/message_display.dart';
import '../../../../domain/models/message.dart';
import '../../../../domain/models/user.dart';
import '../../../../domain/models/group_read_receipt.dart'
    show GroupReadReceipt;
import '../../../../domain/models/chat_message.dart' show ChatMessage;
import '../../../../domain/models/user_profile.dart' show UserProfile;
import '../../../previews/app_theme_preview.dart';
import '../../../previews/fake_data.dart';
import '../../../../router/app_router.dart';
import 'message_content_builder.dart';
import 'message_status_icon.dart';
import 'parts/quote_message_content.dart' show QuoteMessagePreview;
import '../../../core/theme/app_theme.dart';
import '../menu/message_hover_toolbar.dart';
import '../../../core/widgets/user_avatar.dart';

/// 消息气泡：负责统一布局，内容按类型委托给独立组件。
class MessageBubble extends StatelessWidget {
  static final DateFormat _timeFormat = DateFormat('HH:mm');
  static final DateFormat _monthDayFormat = DateFormat('MM月dd日');
  static final DateFormat _fullDateFormat = DateFormat('yyyy年MM月dd日');

  final ChatMessage message;
  final User otherUser;
  final String? currentUserId;
  final String? currentUserAvatar;
  final double? maxBubbleWidth;
  final UserProfile? cachedSenderProfile;
  final UserProfile? cachedCurrentUserProfile;
  final void Function(ChatMessage message)? onLongPress;
  final void Function(ChatMessage message)? onTap;
  final Widget? selectionIndicator;
  final List<MessageReactionGroup> reactionGroups;
  final int? uploadProgress;
  final GroupReadReceipt? groupReadReceipt;
  final void Function(String source)? onPlayAudio;

  const MessageBubble({
    super.key,
    required this.message,
    required this.otherUser,
    this.currentUserId,
    this.currentUserAvatar,
    this.maxBubbleWidth,
    this.cachedSenderProfile,
    this.cachedCurrentUserProfile,
    this.onLongPress,
    this.onTap,
    this.selectionIndicator,
    this.reactionGroups = const [],
    this.uploadProgress,
    this.groupReadReceipt,
    this.onPlayAudio,
  });

  User _buildSenderUser() {
    final isFromMe = _isFromMe;
    final senderProfile = cachedSenderProfile;
    final meProfile = cachedCurrentUserProfile;
    if (isFromMe) {
      final nickname = meProfile?.nickname ?? message.senderNickname;
      final faceUrl = currentUserAvatar?.isNotEmpty == true
          ? currentUserAvatar
          : (meProfile?.faceUrl ?? message.senderFaceUrl);
      return User(
        id: message.sendId.isNotEmpty ? message.sendId : (currentUserId ?? ''),
        name: nickname.isNotEmpty ? nickname : (currentUserId ?? '我'),
        avatar: (faceUrl ?? '').isNotEmpty ? faceUrl : null,
        avatarColorValue: 0xFF6200EE,
        avatarIconName: 'person',
      );
    } else {
      final nickname = senderProfile?.nickname ?? message.senderNickname;
      final faceUrl = senderProfile?.faceUrl ?? message.senderFaceUrl;
      if (nickname.isNotEmpty || faceUrl.isNotEmpty) {
        return User(
          id: message.sendId,
          name: nickname.isNotEmpty ? nickname : otherUser.name,
          avatar: faceUrl.isNotEmpty ? faceUrl : otherUser.avatar,
          avatarColorValue: 0xFF6200EE,
          avatarIconName: 'person',
        );
      }
      return otherUser;
    }
  }

  bool get _isFromMe =>
      currentUserId != null &&
      currentUserId!.isNotEmpty &&
      message.sendId.isNotEmpty &&
      message.sendId == currentUserId;

  bool get isGroupChat => message.sessionType == 2 || message.sessionType == 3;

  @override
  Widget build(BuildContext context) {
    if (message.messageType == MessageType.system) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Center(
          child: Text(
            message.displayText,
            style: TextStyle(
              color: context.appColors.textSecondary,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final isFromMe = _isFromMe;
    final timeText = _formatMessageTime(message.sendDateTime);
    final senderUser = _buildSenderUser();
    final screenWidth = maxBubbleWidth ?? MediaQuery.sizeOf(context).width;

    // 图片与合并转发消息不使用外层气泡背景：图片直接展示，合并转发自带卡片背景，避免两层颜色重叠
    final isPlainContent =
        message.messageType == MessageType.image ||
        message.messageType == MessageType.merge;

    final bubble = Container(
      constraints: BoxConstraints(maxWidth: screenWidth * 0.65),
      padding: isPlainContent
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isPlainContent
            ? Colors.transparent
            : (isFromMe
                  ? context.appColors.bubbleMine
                  : context.appColors.bubbleOther),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(isFromMe ? 18 : 4),
          bottomRight: Radius.circular(isFromMe ? 4 : 18),
        ),
      ),
      child: buildMessageContent(
        message: message,
        isFromMe: isFromMe,
        uploadProgress: uploadProgress,
        onPlayAudio: onPlayAudio,
      ),
    );

    final quotePreview = message.messageType == MessageType.quote
        ? QuoteMessagePreview(message: message, isFromMe: isFromMe)
        : const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: isFromMe
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isFromMe) ...[
                if (selectionIndicator != null) ...[
                  selectionIndicator!,
                  const SizedBox(width: 8),
                ],
                GestureDetector(
                  onTap: () => _navigateToProfile(context, senderUser, false),
                  child: UserAvatar(user: senderUser, radius: 18),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: GestureDetector(
                  onTap: onTap != null ? () => onTap!(message) : null,
                  onLongPress: onLongPress != null
                      ? () => onLongPress!(message)
                      : null,
                  child: Align(
                    alignment: isFromMe
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: isFromMe
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      children: [
                        quotePreview,
                        _buildBubbleWithReactions(bubble, isFromMe),
                      ],
                    ),
                  ),
                ),
              ),
              if (isFromMe) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _navigateToProfile(context, senderUser, true),
                  child: UserAvatar(user: senderUser, radius: 18),
                ),
                if (selectionIndicator != null) ...[
                  const SizedBox(width: 8),
                  selectionIndicator!,
                ],
              ],
            ],
          ),
          Padding(
            padding: EdgeInsets.only(
              left: isFromMe ? 0 : 44,
              right: isFromMe ? 44 : 0,
              top: 4,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  timeText,
                  style: TextStyle(
                    fontSize: 11,
                    color: context.appColors.textSecondary.withValues(
                      alpha: 0.8,
                    ),
                  ),
                ),
                if (isFromMe) ...[
                  const SizedBox(width: 4),
                  MessageStatusIcon(message: message),
                ],
              ],
            ),
          ),

          if (isFromMe &&
              isGroupChat &&
              groupReadReceipt != null &&
              groupReadReceipt!.hasReadCount > 0)
            Padding(
              padding: EdgeInsets.only(
                left: isFromMe ? 0 : 44,
                right: isFromMe ? 44 : 0,
                top: 2,
              ),
              child: Text(
                '已读 ${groupReadReceipt!.hasReadCount}/${groupReadReceipt!.groupMemberCount}',
                style: TextStyle(
                  fontSize: 11,
                  color: context.appColors.textSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBubbleWithReactions(Widget bubble, bool isFromMe) {
    if (reactionGroups.isEmpty) return bubble;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: isFromMe
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        bubble,
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: MessageReactionBar(groups: reactionGroups),
        ),
      ],
    );
  }

  void _navigateToProfile(BuildContext context, User user, bool isFromMeHint) {
    AppRouter.goToUserProfile(context, userId: user.id, user: user);
  }

  String _formatMessageTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(dateTime.year, dateTime.month, dateTime.day);
    final diff = today.difference(msgDay).inDays;
    final timeStr = _timeFormat.format(dateTime);

    if (diff == 0) {
      return timeStr;
    } else if (diff == 1) {
      return '昨天 $timeStr';
    } else if (diff < 7) {
      const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
      return '${weekdays[dateTime.weekday - 1]} $timeStr';
    } else if (now.year == dateTime.year) {
      return '${_monthDayFormat.format(dateTime)} $timeStr';
    } else {
      return '${_fullDateFormat.format(dateTime)} $timeStr';
    }
  }
}

// ==================== 预览 ====================

Widget _previewBubble(ChatMessage message) {
  return Padding(
    padding: const EdgeInsets.all(16),
    child: MessageBubble(
      message: message,
      otherUser: User.mockUsers[1],
      currentUserId: kPreviewMyUserId,
    ),
  );
}

@AppThemePreview(name: '文本 - 对方', group: 'MessageBubble')
Widget messageBubbleTextOtherPreview() {
  return _previewBubble(fakeTextMessage());
}

@AppThemePreview(name: '文本 - 我（已读）', group: 'MessageBubble')
Widget messageBubbleTextMinePreview() {
  return _previewBubble(fakeTextMessage(text: '收到，晚上见！', fromMe: true));
}

@AppThemePreview(name: '文本 - 我（发送失败）', group: 'MessageBubble')
Widget messageBubbleTextFailedPreview() {
  return _previewBubble(
    fakeTextMessage(text: '这条消息发送失败了', fromMe: true, status: 3),
  );
}

@AppThemePreview(name: '图片 - 对方', group: 'MessageBubble')
Widget messageBubbleImagePreview() {
  return _previewBubble(fakeImageMessage());
}

@AppThemePreview(name: '引用 - 对方', group: 'MessageBubble')
Widget messageBubbleQuotePreview() {
  return _previewBubble(fakeQuoteMessage());
}

@AppThemePreview(name: '合并转发 - 对方', group: 'MessageBubble')
Widget messageBubbleMergePreview() {
  return _previewBubble(fakeMergeMessage());
}

@AppThemePreview(name: '名片 - 对方', group: 'MessageBubble')
Widget messageBubbleCardPreview() {
  return _previewBubble(fakeCardMessage());
}

@AppThemePreview(name: '位置 - 对方', group: 'MessageBubble')
Widget messageBubbleLocationPreview() {
  return _previewBubble(fakeLocationMessage());
}

@AppThemePreview(name: '系统消息', group: 'MessageBubble')
Widget messageBubbleSystemPreview() {
  return _previewBubble(fakeSystemMessage());
}
