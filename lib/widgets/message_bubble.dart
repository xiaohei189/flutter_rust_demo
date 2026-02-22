import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/message.dart' show Message, MessageSendStatus;
import '../models/user.dart';
import '../theme/app_theme.dart';
import 'user_avatar.dart';

/// 消息气泡组件
class MessageBubble extends StatelessWidget {
  final Message message;
  final User otherUser;

  const MessageBubble({
    super.key,
    required this.message,
    required this.otherUser,
  });

  @override
  Widget build(BuildContext context) {
    final isFromMe = message.isFromMe;
    final timeFormat = DateFormat('HH:mm');

    // 当前用户在左侧：自己的消息在左，对方在右。气泡小角在靠近头像一侧。
    final bubbleContent = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: isFromMe
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.end,
      children: [
        Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: isFromMe
                ? AppTheme.myMessageColor
                : AppTheme.otherMessageColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(isFromMe ? 4 : 18),
              bottomRight: Radius.circular(isFromMe ? 18 : 4),
            ),
          ),
          child: Text(
            message.content,
            style: TextStyle(
              color: isFromMe ? Colors.white : Colors.black87,
              fontSize: 16,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: isFromMe
              ? MainAxisAlignment.start
              : MainAxisAlignment.end,
          children: [
            Text(
              timeFormat.format(message.timestamp),
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            if (isFromMe && message.sendStatus != null) ...[
              const SizedBox(width: 6),
              _buildSendStatusIcon(message.sendStatus!),
            ],
          ],
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isFromMe
            ? MainAxisAlignment.start
            : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 当前用户（自己）的消息：在左侧，头像在左、气泡在右
          if (isFromMe) ...[
            UserAvatar(user: User.currentUser, radius: 18),
            const SizedBox(width: 8),
            Flexible(
              child: Align(
                alignment: Alignment.centerLeft,
                child: bubbleContent,
              ),
            ),
          ],
          // 对方消息：在右侧，气泡在左、头像在右
          if (!isFromMe) ...[
            Flexible(
              child: Align(
                alignment: Alignment.centerRight,
                child: bubbleContent,
              ),
            ),
            const SizedBox(width: 8),
            UserAvatar(user: otherUser, radius: 18),
          ],
        ],
      ),
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
            color: Colors.white70,
          ),
        );
      case MessageSendStatus.sent:
        return Icon(Icons.done_all, size: 14, color: Colors.white70);
      case MessageSendStatus.failed:
        return Icon(Icons.error_outline, size: 14, color: Colors.red[200]);
    }
  }
}
