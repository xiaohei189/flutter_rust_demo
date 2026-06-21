import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../models/user.dart';
import '../src/rust/domain/model/message.dart' show MessageInfo;
import '../src/rust/domain/model/user.dart' show UserInfo;
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
    this.onMessageLongPress,
    this.onMessageVisible,
  });

  final List<MessageInfo> messages;
  final User otherUser;
  final String? currentUserId;
  final ScrollController scrollController;
  final bool isLoading;
  final Map<String, UserInfo>? cachedSenderProfiles;
  final UserInfo? cachedCurrentUserProfile;
  final void Function(MessageInfo message)? onMessageLongPress;
  final void Function(MessageInfo message)? onMessageVisible;

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
        return _VisibleMessageBubble(
          message: message,
          otherUser: otherUser,
          currentUserId: currentUserId,
          cachedSenderProfile: cachedSenderProfiles?[message.sendId],
          cachedCurrentUserProfile: cachedCurrentUserProfile,
          onLongPress: onMessageLongPress,
          onVisible: onMessageVisible,
        );
      },
    );
  }
}

/// 带可见性检测的消息气泡
class _VisibleMessageBubble extends StatelessWidget {
  const _VisibleMessageBubble({
    required this.message,
    required this.otherUser,
    required this.currentUserId,
    required this.cachedSenderProfile,
    required this.cachedCurrentUserProfile,
    required this.onLongPress,
    required this.onVisible,
  });

  final MessageInfo message;
  final User otherUser;
  final String? currentUserId;
  final UserInfo? cachedSenderProfile;
  final UserInfo? cachedCurrentUserProfile;
  final void Function(MessageInfo message)? onLongPress;
  final void Function(MessageInfo message)? onVisible;

  @override
  Widget build(BuildContext context) {
    if (onVisible == null) {
      return MessageBubble(
        message: message,
        otherUser: otherUser,
        currentUserId: currentUserId,
        cachedSenderProfile: cachedSenderProfile,
        cachedCurrentUserProfile: cachedCurrentUserProfile,
        onLongPress: onLongPress,
      );
    }

    return VisibilityDetector(
      key: Key('msg_${message.clientMsgId}'),
      onVisibilityChanged: (info) {
        if (info.visibleFraction > 0) {
          onVisible?.call(message);
        }
      },
      child: MessageBubble(
        message: message,
        otherUser: otherUser,
        currentUserId: currentUserId,
        cachedSenderProfile: cachedSenderProfile,
        cachedCurrentUserProfile: cachedCurrentUserProfile,
        onLongPress: onLongPress,
      ),
    );
  }
}
