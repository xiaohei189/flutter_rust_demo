import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/message.dart';
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

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isFromMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 对方头像
          if (!isFromMe) ...[
            UserAvatar(user: otherUser, radius: 18),
            const SizedBox(width: 8),
          ],

          // 消息内容
          Flexible(
            child: Column(
              crossAxisAlignment: isFromMe
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Container(
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
                      bottomLeft: Radius.circular(isFromMe ? 18 : 4),
                      bottomRight: Radius.circular(isFromMe ? 4 : 18),
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
                Text(
                  timeFormat.format(message.timestamp),
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),

          // 自己的头像
          if (isFromMe) ...[
            const SizedBox(width: 8),
            UserAvatar(user: User.currentUser, radius: 18),
          ],
        ],
      ),
    );
  }
}
