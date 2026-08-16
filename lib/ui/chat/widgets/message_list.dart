import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../../domain/extensions/message_ext.dart';
import '../../../domain/models/user.dart';
import '../../../generated/rust/event/events/message.dart'
    show GroupReadReceipt;
import '../../../generated/rust/model/message.dart' show MessageInfo;
import '../../../generated/rust/model/user.dart' show UserInfo;
import '../../previews/app_theme_preview.dart';
import '../../previews/fake_data.dart';
import '../../core/theme/app_theme.dart';
import 'message_bubble.dart';
import 'message_skeleton.dart';

/// 消息列表组件
/// 显示聊天消息列表，支持加载更多、空状态、加载状态与消息定位。
class MessageList extends StatefulWidget {
  const MessageList({
    super.key,
    required this.messages,
    required this.otherUser,
    required this.currentUserId,
    this.currentUserAvatar,
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
  final String? currentUserAvatar;
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
  State<MessageList> createState() => MessageListState();
}

class MessageListState extends State<MessageList> {
  final Map<String, GlobalKey> _messageKeys = {};
  static const int _maxMessageKeys = 300;

  void _pruneMessageKeys(List<MessageInfo> messages) {
    if (_messageKeys.length <= _maxMessageKeys) return;
    final recentIds = messages
        .skip(messages.length - _maxMessageKeys)
        .map((m) => m.clientMsgId)
        .toSet();
    _messageKeys.removeWhere((id, _) => !recentIds.contains(id));
  }

  /// 滚动到指定消息并尽量居中显示。
  void scrollToMessage(String clientMsgId) {
    final key = _messageKeys[clientMsgId];
    final targetContext = key?.currentContext;
    if (targetContext == null) return;
    Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      alignment: 0.5,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    _pruneMessageKeys(widget.messages);
    if (widget.isLoading && widget.messages.isEmpty) {
      return const MessageSkeleton();
    }

    if (widget.messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: colors.textSecondary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              '暂无消息',
              style: TextStyle(fontSize: 16, color: colors.textSecondary),
            ),
          ],
        ),
      );
    }

    const useReverse = true;
    final itemCount = widget.messages.length + (widget.isLoading ? 1 : 0);
    final dateLabels = _buildDateLabels(widget.messages);

    return ListView.builder(
      controller: widget.scrollController,
      reverse: useReverse,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (widget.isLoading && index == widget.messages.length) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: CircularProgressIndicator(color: colors.primary),
            ),
          );
        }

        final messageIndex = widget.messages.length - 1 - index;
        if (messageIndex < 0 || messageIndex >= widget.messages.length) {
          return const SizedBox.shrink();
        }

        final message = widget.messages[messageIndex];
        final dateLabel = dateLabels[messageIndex];
        final messageKey = _messageKeys.putIfAbsent(
          message.clientMsgId,
          () => GlobalKey(),
        );
        final selected =
            widget.selectMode &&
            widget.selectedClientMsgIds.contains(message.clientMsgId);

        return Column(
          key: messageKey,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dateLabel != null) _buildDateSeparator(context, dateLabel),
            Stack(
              children: [
                _VisibleMessageBubble(
                  message: message,
                  otherUser: widget.otherUser,
                  currentUserId: widget.currentUserId,
                  currentUserAvatar: widget.currentUserAvatar,
                  cachedSenderProfile:
                      widget.cachedSenderProfiles?[message.sendId],
                  cachedCurrentUserProfile: widget.cachedCurrentUserProfile,
                  onLongPress: widget.onMessageLongPress,
                  onVisible: widget.onMessageVisible,
                  onTap: widget.onMessageTap,
                  uploadProgress: widget.uploadProgress,
                  groupReadReceipts: widget.groupReadReceipts,
                ),
                if (widget.selectMode)
                  Positioned(
                    right: 4,
                    top: 4,
                    child: Icon(
                      selected
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      size: 20,
                      color: selected ? colors.primary : colors.textSecondary,
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }

  /// 预计算每条消息是否需要日期分隔符及对应文案，避免 itemBuilder 内重复格式化。
  static List<String?> _buildDateLabels(List<MessageInfo> messages) {
    final labels = List<String?>.filled(messages.length, null);
    final now = DateTime.now();
    for (var i = 0; i < messages.length; i++) {
      final current = messages[i].sendDateTime;
      if (i == 0 || !_isSameDate(current, messages[i - 1].sendDateTime)) {
        labels[i] = _formatDateLabel(current, now);
      }
    }
    return labels;
  }

  static bool _isSameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static String _formatDateLabel(DateTime dateTime, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final msgDate = DateTime(dateTime.year, dateTime.month, dateTime.day);
    final diff = today.difference(msgDate).inDays;
    if (diff == 0) return '今天';
    if (diff == 1) return '昨天';
    final weekStart = today.subtract(Duration(days: now.weekday - 1));
    if (!dateTime.isBefore(weekStart)) {
      const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
      return weekdays[dateTime.weekday - 1];
    }
    if (now.year == dateTime.year) {
      return DateFormat('MM月dd日').format(dateTime);
    }
    return DateFormat('yyyy年MM月dd日').format(dateTime);
  }

  /// 构建日期分隔符
  Widget _buildDateSeparator(BuildContext context, String dateText) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: colors.textSecondary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
          child: Text(
            dateText,
            style: TextStyle(
              fontSize: 12,
              color: colors.textSecondary.withValues(alpha: 0.6),
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
    required this.currentUserAvatar,
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
  final String? currentUserAvatar;
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
        currentUserAvatar: currentUserAvatar,
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
        currentUserAvatar: currentUserAvatar,
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

// ==================== 预览 ====================

@AppThemePreview(name: '消息列表（混合内容）', group: 'MessageList')
Widget messageListPreview() {
  return Padding(
    padding: const EdgeInsets.all(16),
    child: SizedBox(
      height: 480,
      child: MessageList(
        messages: fakeMessageList(),
        otherUser: User.mockUsers[1],
        currentUserId: kPreviewMyUserId,
        scrollController: ScrollController(),
      ),
    ),
  );
}
