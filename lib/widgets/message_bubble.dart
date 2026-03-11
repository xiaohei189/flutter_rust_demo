import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/message.dart' show Message, MessageSendStatus;
import '../models/user.dart';
import '../router/app_router.dart';
import '../src/rust/api/bridge_client.dart';
import '../theme/app_theme.dart';
import 'user_avatar.dart';

/// 消息气泡：我=左侧蓝色，对方=右侧浅灰；头像优先显示图片，无图片显示名字首字
class MessageBubble extends StatelessWidget {
  final Message message;
  final User otherUser;
  final String? currentUserId;
  final UserProfile? cachedSenderProfile;
  final UserProfile? cachedCurrentUserProfile;

  const MessageBubble({
    super.key,
    required this.message,
    required this.otherUser,
    this.currentUserId,
    this.cachedSenderProfile,
    this.cachedCurrentUserProfile,
  });

  /// 根据消息的发送者信息构建头像 User，优先用消息自带的昵称/头像
  User _buildSenderUser() {
    final isFromMe = _isFromMe;
    final senderProfile = cachedSenderProfile;
    final meProfile = cachedCurrentUserProfile;
    if (isFromMe) {
      final nickname = meProfile?.nickname ?? message.senderNickname ?? '';
      final faceUrl = meProfile?.faceUrl ?? message.senderFaceUrl;
      return User(
        id: message.senderId.isNotEmpty ? message.senderId : (currentUserId ?? ''),
        name: nickname.isNotEmpty ? nickname : (currentUserId ?? '我'),
        avatar: faceUrl?.isNotEmpty == true ? faceUrl : null,
      );
    } else {
      final nickname = senderProfile?.nickname ?? message.senderNickname ?? '';
      final faceUrl = senderProfile?.faceUrl ?? message.senderFaceUrl;
      if (nickname.isNotEmpty || (faceUrl?.isNotEmpty == true)) {
        return User(
          id: message.senderId,
          name: nickname.isNotEmpty ? nickname : otherUser.name,
          avatar: faceUrl?.isNotEmpty == true
              ? faceUrl
              : otherUser.avatar,
        );
      }
      return otherUser;
    }
  }

  bool get _isFromMe =>
      message.isFromMe ||
      (currentUserId != null &&
          currentUserId!.isNotEmpty &&
          message.senderId.isNotEmpty &&
          message.senderId == currentUserId);

  @override
  Widget build(BuildContext context) {
    final isFromMe = _isFromMe;
    final timeFormat = DateFormat('HH:mm');
    final senderUser = _buildSenderUser();

    final bubbleContent = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: isFromMe
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isFromMe
                ? AppTheme.myMessageColor
                : AppTheme.otherMessageColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(isFromMe ? 18 : 4),
              bottomRight: Radius.circular(isFromMe ? 4 : 18),
            ),
          ),
          child: Text(
            message.content,
            style: TextStyle(
              color: isFromMe ? Colors.white : AppTheme.otherMessageTextColor,
              fontSize: 16,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              timeFormat.format(message.timestamp),
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondaryColor.withValues(alpha: 0.8),
              ),
            ),
            if (isFromMe && message.sendStatus != null) ...[
              const SizedBox(width: 4),
              _buildSendStatusIcon(message.sendStatus!),
            ],
          ],
        ),
      ],
    );

    // 自己：右侧（气泡在左、头像在右）；对方：左侧（头像在左、气泡在右）
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isFromMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
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
            child: Align(
              alignment: isFromMe
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: bubbleContent,
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
    );
  }

  void _navigateToProfile(BuildContext context, User user, bool isFromMeHint) {
    AppRouter.goToUserProfile(
      context,
      userId: user.id,
      user: user,
    );
  }

  Widget _buildSendStatusIcon(MessageSendStatus status) {
    switch (status) {
      case MessageSendStatus.sending:
        return SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppTheme.myMessageColor.withValues(alpha: 0.9),
          ),
        );
      case MessageSendStatus.sent:
        return Icon(
          Icons.done_all,
          size: 14,
          color: AppTheme.textSecondaryColor.withValues(alpha: 0.8),
        );
      case MessageSendStatus.failed:
        return Icon(
          Icons.error_outline,
          size: 14,
          color: AppTheme.unreadRed.withValues(alpha: 0.9),
        );
    }
  }
}
