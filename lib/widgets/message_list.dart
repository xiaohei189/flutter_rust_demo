import 'package:flutter/material.dart';

import '../models/message.dart' show Message;
import '../models/user.dart';
import '../src/rust/api/bridge_client.dart' show UserProfile;
import '../theme/app_theme.dart';
import 'message_bubble.dart';
import 'message_skeleton.dart';

/// 消息列表组件
/// 显示聊天消息列表，支持加载更多、空状态、加载状态
class MessageList extends StatelessWidget {
  const MessageList({
    super.key,
    required this.messages,
    required this.otherUser,
    required this.currentUserId,
    required this.scrollController,
    this.isLoading = false,
    this.cachedSenderProfiles,
    this.cachedCurrentUserProfile,
  });

  final List<Message> messages;
  final User otherUser;
  final String? currentUserId;
  final ScrollController scrollController;
  final bool isLoading;
  final Map<String, UserProfile>? cachedSenderProfiles;
  final UserProfile? cachedCurrentUserProfile;

  @override
  Widget build(BuildContext context) {
    if (isLoading && messages.isEmpty) {
      return const MessageSkeleton();
    }

    if (messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: AppTheme.textSecondaryColor.withValues(
                alpha: 0.5,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '暂无消息',
              style: TextStyle(
                fontSize: 16,
                color: AppTheme.textSecondaryColor,
              ),
            ),
          ],
        ),
      );
    }

    const useReverse = true;
    final itemCount = messages.length + (isLoading ? 1 : 0);

    return ListView.builder(
      controller: scrollController,
      reverse: useReverse,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (isLoading && index == messages.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(
                color: AppTheme.primaryColor,
              ),
            ),
          );
        }

        final messageIndex = messages.length - 1 - index;
        if (messageIndex < 0 || messageIndex >= messages.length) {
          return const SizedBox.shrink();
        }

        final message = messages[messageIndex];
        return MessageBubble(
          message: message,
          otherUser: otherUser,
          currentUserId: currentUserId,
          cachedSenderProfile: cachedSenderProfiles?[message.senderId],
          cachedCurrentUserProfile: cachedCurrentUserProfile,
        );
      },
    );
  }
}
