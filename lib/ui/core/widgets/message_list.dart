import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../../domain/models/message_ext.dart';
import '../../../domain/models/user.dart';
import '../../../src/rust/event/events/message.dart' show GroupReadReceipt;
import '../../../src/rust/model/message.dart' show MessageInfo;
import '../../../src/rust/model/user.dart' show UserInfo;
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
    this.onMessageTap,
    this.selectMode = false,
    this.selectedClientMsgIds = const {},
    this.uploadProgress,
    this.groupReadReceipts,
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
  final void Function(MessageInfo message)? onMessageTap;
  final bool selectMode;
  final Set<String> selectedClientMsgIds;
  final Map<String, int>? uploadProgress;
  final Map<String, GroupReadReceipt>? groupReadReceipts;

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
              color: AppTheme.textSecondaryColor.withValues(alpha: 0.5),
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
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            ),
          );
        }

        final messageIndex = messages.length - 1 - index;
        if (messageIndex < 0 || messageIndex >= messages.length) {
          return const SizedBox.shrink();
        }

        final message = messages[messageIndex];
        final showDateSeparator = _shouldShowDateSeparator(
          messages,
          messageIndex,
        );

        final selected =
            selectMode && selectedClientMsgIds.contains(message.clientMsgId);

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showDateSeparator) _buildDateSeparator(message.sendDateTime),
            Stack(
              children: [
                _VisibleMessageBubble(
                  message: message,
                  otherUser: otherUser,
                  currentUserId: currentUserId,
                  cachedSenderProfile: cachedSenderProfiles?[message.sendId],
                  cachedCurrentUserProfile: cachedCurrentUserProfile,
                  onLongPress: onMessageLongPress,
                  onVisible: onMessageVisible,
                  onTap: onMessageTap,
                  uploadProgress: uploadProgress,
                  groupReadReceipts: groupReadReceipts,
                ),
                if (selectMode)
                  Positioned(
                    right: 4,
                    top: 4,
                    child: Icon(
                      selected
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      size: 20,
                      color: selected
                          ? AppTheme.primaryColor
                          : AppTheme.textSecondaryColor,
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }

  /// 判断是否应该显示日期分隔符
  bool _shouldShowDateSeparator(List<MessageInfo> messages, int index) {
    if (index == 0) return true;

    final currentMsg = messages[index];
    final prevMsg = messages[index - 1];

    final currentDate = DateFormat(
      'yyyy-MM-dd',
    ).format(currentMsg.sendDateTime);
    final prevDate = DateFormat('yyyy-MM-dd').format(prevMsg.sendDateTime);

    return currentDate != prevDate;
  }

  /// 构建日期分隔符
  Widget _buildDateSeparator(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateFormat('yyyy-MM-dd').format(now);
    final msgDate = DateFormat('yyyy-MM-dd').format(dateTime);

    String dateText;
    if (today == msgDate) {
      dateText = '今天';
    } else {
      final yesterday = now.subtract(const Duration(days: 1));
      final yesterdayStr = DateFormat('yyyy-MM-dd').format(yesterday);
      if (yesterdayStr == msgDate) {
        dateText = '昨天';
      } else {
        // 判断是否在同一周
        final weekStart = now.subtract(Duration(days: now.weekday - 1));
        if (dateTime.isAfter(weekStart) ||
            dateTime.isAtSameMomentAs(weekStart)) {
          final weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
          dateText = weekdays[dateTime.weekday - 1];
        } else {
          // 判断是否在同一年
          if (now.year == dateTime.year) {
            dateText = DateFormat('MM月dd日').format(dateTime);
          } else {
            dateText = DateFormat('yyyy年MM月dd日').format(dateTime);
          }
        }
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.textSecondaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            dateText,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondaryColor.withValues(alpha: 0.6),
            ),
          ),
        ),
      ),
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
    this.onTap,
    this.uploadProgress,
    this.groupReadReceipts,
  });

  final MessageInfo message;
  final User otherUser;
  final String? currentUserId;
  final UserInfo? cachedSenderProfile;
  final UserInfo? cachedCurrentUserProfile;
  final void Function(MessageInfo message)? onLongPress;
  final void Function(MessageInfo message)? onVisible;
  final void Function(MessageInfo message)? onTap;
  final Map<String, int>? uploadProgress;
  final Map<String, GroupReadReceipt>? groupReadReceipts;

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
        onTap: onTap,
        uploadProgress: uploadProgress?[message.clientMsgId],
        groupReadReceipt:
            groupReadReceipts?[message.clientMsgId] ??
            groupReadReceipts?[message.serverMsgId],
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
        onTap: onTap,
        uploadProgress: uploadProgress?[message.clientMsgId],
        groupReadReceipt:
            groupReadReceipts?[message.clientMsgId] ??
            groupReadReceipts?[message.serverMsgId],
      ),
    );
  }
}
