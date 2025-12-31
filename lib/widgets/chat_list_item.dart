import 'package:flutter/material.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:intl/intl.dart';

import '../models/user.dart';
import '../src/rust/im/types.dart';
import 'user_avatar.dart';

/// 聊天列表项组件
class ChatListItem extends StatelessWidget {
  final LocalConversation conversation;
  final VoidCallback onTap;

  const ChatListItem({
    super.key,
    required this.conversation,
    required this.onTap,
  });

  String _formatTime(PlatformInt64? timeMs) {
    if (timeMs == null || timeMs.toInt() <= 0) return '';

    final time = DateTime.fromMillisecondsSinceEpoch(timeMs.toInt());
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}分钟前';
    } else if (difference.inHours < 24) {
      return DateFormat('HH:mm').format(time);
    } else if (difference.inDays == 1) {
      return '昨天';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}天前';
    } else {
      return DateFormat('MM/dd').format(time);
    }
  }

  User _getUser() {
    final userId = conversation.userId.isNotEmpty
        ? conversation.userId
        : conversation.groupId;
    final userName = conversation.showName.isNotEmpty
        ? conversation.showName
        : conversation.conversationId;

    return User(
      id: userId,
      name: userName,
      avatar: conversation.faceUrl.isNotEmpty ? conversation.faceUrl : null,
      status: null, // LocalConversation 中没有状态信息
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _getUser();
    final latestMsgTime = conversation.latestMsgSendTime;

    return ListTile(
      leading: Stack(
        children: [
          UserAvatar(user: user, radius: 28),
          // 置顶标识
          if (conversation.isPinned)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Colors.orange,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.push_pin,
                  size: 12,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              user.name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          Text(
            _formatTime(latestMsgTime),
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
      subtitle: Row(
        children: [
          Expanded(
            child: Text(
              conversation.latestMsg.isNotEmpty
                  ? conversation.latestMsg
                  : '暂无消息',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.grey[700], fontSize: 14),
            ),
          ),
          // 未读消息数量
          if (conversation.unreadCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
              child: Text(
                conversation.unreadCount > 99
                    ? '99+'
                    : '${conversation.unreadCount}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
      onTap: onTap,
    );
  }
}
