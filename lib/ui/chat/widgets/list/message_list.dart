import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../mappers/message_display.dart';
import '../../../../domain/models/message.dart' show MessageType;
import '../../../../domain/models/user.dart';
import '../../../../domain/models/group_read_receipt.dart'
    show GroupReadReceipt;
import '../../../../domain/models/chat_message.dart' show ChatMessage;
import '../../../../domain/models/user_profile.dart' show UserProfile;
import '../../../previews/app_theme_preview.dart';
import '../../../previews/fake_data.dart';
import '../../../core/theme/app_theme.dart';
import '../menu/message_action_menu.dart'
    show MessageActions, showMessageToolPanel;
import '../bubble/message_bubble.dart';
import '../menu/message_hover_toolbar.dart' show MessageReactionGroup;
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
    this.messageActionsBuilder,
    this.messageReactions = const {},
    this.onPlayAudio,
  });

  final List<ChatMessage> messages;
  final User otherUser;
  final String? currentUserId;
  final String? currentUserAvatar;
  final ScrollController scrollController;
  final bool isLoading;
  final Map<String, UserProfile>? cachedSenderProfiles;
  final UserProfile? cachedCurrentUserProfile;
  final void Function(ChatMessage message)? onMessageLongPress;
  final void Function(ChatMessage message)? onMessageVisible;
  final void Function(ChatMessage message)? onMessageTap;
  final bool selectMode;
  final Set<String> selectedClientMsgIds;
  final Map<String, int>? uploadProgress;
  final Map<String, GroupReadReceipt>? groupReadReceipts;
  final MessageActions Function(ChatMessage message)? messageActionsBuilder;
  final Map<String, List<MessageReactionGroup>> messageReactions;
  final void Function(String source)? onPlayAudio;

  @override
  State<MessageList> createState() => MessageListState();
}

class MessageListState extends State<MessageList> {
  final Map<String, GlobalKey> _messageKeys = {};
  static const int _maxMessageKeys = 300;
  List<String?> _cachedDateLabels = const [];
  String _cachedDateLabelTailId = '';
  int _cachedDateLabelCount = -1;

  void _pruneMessageKeys(List<ChatMessage> messages) {
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

  void _openMessageToolPanel(ChatMessage message, GlobalKey messageKey) {
    if (widget.selectMode) return;
    final actions = widget.messageActionsBuilder?.call(message);
    if (actions == null) {
      widget.onMessageLongPress?.call(message);
      return;
    }
    final renderObject = messageKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox) return;
    final anchor = renderObject.localToGlobal(Offset.zero) & renderObject.size;
    showMessageToolPanel(
      context: context,
      anchor: anchor,
      message: message,
      currentUserId: widget.currentUserId ?? '',
      actions: actions,
      reactions:
          widget.messageReactions[message.clientMsgId]
              ?.map((group) => group.emoji)
              .toSet() ??
          const {},
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
    final dateLabels = _dateLabelsFor(widget.messages);
    // maybeOf 不注册 MediaQuery 依赖：键盘动画期间 viewInsets 逐帧变化不会让列表每帧重建。
    final maxBubbleWidth =
        (MediaQuery.maybeOf(context)?.size.width ?? 0) * 0.65;

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

        final Widget messageBody = _VisibleMessageBubble(
          message: message,
          otherUser: widget.otherUser,
          currentUserId: widget.currentUserId,
          currentUserAvatar: widget.currentUserAvatar,
          maxBubbleWidth: maxBubbleWidth,
          cachedSenderProfile: widget.cachedSenderProfiles?[message.sendId],
          cachedCurrentUserProfile: widget.cachedCurrentUserProfile,
          onLongPress: (msg) => _openMessageToolPanel(msg, messageKey),
          onVisible: widget.onMessageVisible,
          onTap: widget.onMessageTap,
          selectionIndicator:
              widget.selectMode && message.messageType != MessageType.system
              ? _SelectionCheckbox(
                  selected: selected,
                  onTap: () => widget.onMessageTap?.call(message),
                )
              : null,
          reactionGroups:
              widget.messageReactions[message.clientMsgId] ?? const [],
          uploadProgress: widget.uploadProgress,
          groupReadReceipts: widget.groupReadReceipts,
          onPlayAudio: widget.onPlayAudio,
        );

        return Column(
          key: messageKey,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dateLabel != null) _buildDateSeparator(context, dateLabel),
            messageBody,
          ],
        );
      },
    );
  }

  /// 按「最新消息 id + 消息数」做 O(1) 缓存标记，
  /// 避免键盘弹出动画等高频 build 时全量比较消息 id 列表。
  List<String?> _dateLabelsFor(List<ChatMessage> messages) {
    final tailId = messages.isEmpty ? '' : messages.last.clientMsgId;
    if (messages.length == _cachedDateLabelCount &&
        tailId == _cachedDateLabelTailId) {
      return _cachedDateLabels;
    }
    final labels = _buildDateLabels(messages);
    _cachedDateLabels = labels;
    _cachedDateLabelCount = messages.length;
    _cachedDateLabelTailId = tailId;
    return labels;
  }

  /// 预计算每条消息是否需要日期分隔符及对应文案，避免 itemBuilder 内重复格式化。
  static List<String?> _buildDateLabels(List<ChatMessage> messages) {
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
    required this.maxBubbleWidth,
    required this.cachedSenderProfile,
    required this.cachedCurrentUserProfile,
    required this.onLongPress,
    required this.onVisible,
    this.onTap,
    this.selectionIndicator,
    this.reactionGroups = const [],
    this.uploadProgress,
    this.groupReadReceipts,
    this.onPlayAudio,
  });

  final ChatMessage message;
  final User otherUser;
  final String? currentUserId;
  final String? currentUserAvatar;
  final double maxBubbleWidth;
  final UserProfile? cachedSenderProfile;
  final UserProfile? cachedCurrentUserProfile;
  final void Function(ChatMessage message)? onLongPress;
  final void Function(ChatMessage message)? onVisible;
  final void Function(ChatMessage message)? onTap;
  final Widget? selectionIndicator;
  final List<MessageReactionGroup> reactionGroups;
  final Map<String, int>? uploadProgress;
  final Map<String, GroupReadReceipt>? groupReadReceipts;
  final void Function(String source)? onPlayAudio;

  @override
  Widget build(BuildContext context) {
    if (onVisible == null) {
      return MessageBubble(
        message: message,
        otherUser: otherUser,
        currentUserId: currentUserId,
        currentUserAvatar: currentUserAvatar,
        maxBubbleWidth: maxBubbleWidth,
        cachedSenderProfile: cachedSenderProfile,
        cachedCurrentUserProfile: cachedCurrentUserProfile,
        onLongPress: onLongPress,
        onTap: onTap,
        selectionIndicator: selectionIndicator,
        reactionGroups: reactionGroups,
        uploadProgress: uploadProgress?[message.clientMsgId],
        groupReadReceipt:
            groupReadReceipts?[message.clientMsgId] ??
            groupReadReceipts?[message.serverMsgId],
        onPlayAudio: onPlayAudio,
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
        maxBubbleWidth: maxBubbleWidth,
        cachedSenderProfile: cachedSenderProfile,
        cachedCurrentUserProfile: cachedCurrentUserProfile,
        onLongPress: onLongPress,
        onTap: onTap,
        selectionIndicator: selectionIndicator,
        reactionGroups: reactionGroups,
        uploadProgress: uploadProgress?[message.clientMsgId],
        groupReadReceipt:
            groupReadReceipts?[message.clientMsgId] ??
            groupReadReceipts?[message.serverMsgId],
        onPlayAudio: onPlayAudio,
      ),
    );
  }
}

/// 多选模式下显示在消息气泡同行的圆形勾选框。
class _SelectionCheckbox extends StatelessWidget {
  const _SelectionCheckbox({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Semantics(
      checked: selected,
      label: selected ? '取消选择消息' : '选择消息',
      button: true,
      child: InkResponse(
        onTap: onTap,
        radius: 18,
        child: SizedBox(
          width: 32,
          height: 32,
          child: Icon(
            selected ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 22,
            color: selected ? colors.primary : colors.textSecondary,
          ),
        ),
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
