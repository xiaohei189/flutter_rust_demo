import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../domain/extensions/message_ext.dart';
import '../../../domain/models/message.dart';
import '../../../domain/models/user.dart';
import '../../../generated/rust/event/events/message.dart'
    show GroupReadReceipt;
import '../../../generated/rust/model/message.dart' show MessageInfo;
import '../../../generated/rust/model/user.dart' show UserInfo;
import '../../../router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/user_avatar.dart';
import 'message_parts/media_message_content.dart';
import 'message_parts/quote_message_content.dart';
import 'message_parts/rich_message_content.dart';
import 'message_parts/text_message_content.dart';

/// 消息气泡：负责统一布局，内容按类型委托给独立组件。
class MessageBubble extends StatelessWidget {
  static final DateFormat _timeFormat = DateFormat('HH:mm');
  static final DateFormat _monthDayFormat = DateFormat('MM月dd日');
  static final DateFormat _fullDateFormat = DateFormat('yyyy年MM月dd日');

  final MessageInfo message;
  final User otherUser;
  final String? currentUserId;
  final String? currentUserAvatar;
  final UserInfo? cachedSenderProfile;
  final UserInfo? cachedCurrentUserProfile;
  final void Function(MessageInfo message)? onLongPress;
  final void Function(MessageInfo message)? onTap;
  final int? uploadProgress;
  final GroupReadReceipt? groupReadReceipt;

  const MessageBubble({
    super.key,
    required this.message,
    required this.otherUser,
    this.currentUserId,
    this.currentUserAvatar,
    this.cachedSenderProfile,
    this.cachedCurrentUserProfile,
    this.onLongPress,
    this.onTap,
    this.uploadProgress,
    this.groupReadReceipt,
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
      message.sendId == currentUserId ||
      (currentUserId != null &&
          currentUserId!.isNotEmpty &&
          message.sendId.isNotEmpty &&
          message.sendId == currentUserId);

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
    final screenWidth = MediaQuery.sizeOf(context).width;

    final bubble = Container(
      constraints: BoxConstraints(maxWidth: screenWidth * 0.65),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isFromMe
            ? context.appColors.bubbleMine
            : context.appColors.bubbleOther,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(isFromMe ? 18 : 4),
          bottomRight: Radius.circular(isFromMe ? 4 : 18),
        ),
      ),
      child: _buildMessageContent(context, isFromMe),
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
                      children: [quotePreview, bubble],
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
                if (isFromMe) ...[const SizedBox(width: 4), _buildStatusIcon()],
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

  Widget _buildStatusIcon() {
    final status = MessageSendStatus.fromValue(message.status);
    if (status == MessageSendStatus.sending) {
      return SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.grey.shade400),
        ),
      );
    }
    if (status == MessageSendStatus.sendFailed) {
      return const Icon(Icons.error_outline, size: 16, color: Colors.red);
    }
    if (message.isRead) {
      return Container(
        width: 16,
        height: 16,
        decoration: const BoxDecoration(
          color: Color(0xFF34C759),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.done, size: 11, color: Colors.white),
      );
    }
    if (status == MessageSendStatus.sendSuccess) {
      return Icon(Icons.done, size: 16, color: Colors.grey.shade400);
    }
    return const SizedBox.shrink();
  }

  Widget _buildMessageContent(BuildContext context, bool isFromMe) {
    return switch (message.messageType) {
      MessageType.image => ImageMessageContent(
        message: message,
        isFromMe: isFromMe,
        uploadProgress: uploadProgress,
      ),
      MessageType.video => VideoMessageContent(
        message: message,
        isFromMe: isFromMe,
        uploadProgress: uploadProgress,
      ),
      MessageType.audio => AudioMessageContent(
        message: message,
        isFromMe: isFromMe,
      ),
      MessageType.file => FileMessageContent(
        message: message,
        isFromMe: isFromMe,
        uploadProgress: uploadProgress,
      ),
      MessageType.card => CardMessageContent(
        message: message,
        isFromMe: isFromMe,
      ),
      MessageType.merge => MergeMessageContent(
        message: message,
        isFromMe: isFromMe,
      ),
      MessageType.quote => QuoteMessageContent(
        message: message,
        isFromMe: isFromMe,
      ),
      MessageType.at => AtMessageContent(message: message, isFromMe: isFromMe),
      MessageType.face => FaceMessageContent(message: message),
      MessageType.location => LocationMessageContent(
        message: message,
        isFromMe: isFromMe,
      ),
      MessageType.custom => CustomMessageContent(
        message: message,
        isFromMe: isFromMe,
      ),
      MessageType.system => SystemMessageContent(message: message),
      MessageType.markdown => MarkdownMessageContent(
        message: message,
        isFromMe: isFromMe,
      ),
      _ => TextMessageContent(message: message, isFromMe: isFromMe),
    };
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
