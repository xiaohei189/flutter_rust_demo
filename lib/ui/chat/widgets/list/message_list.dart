import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import '../../providers/message_service_provider.dart';

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
    this.groupReadReceipts,
    this.messageActionsBuilder,
    this.messageReactions = const {},
    this.flaggedClientMsgIds = const {},
    this.onPlayAudio,
    this.onRetrySend,
    this.unreadCountAtOpen = 0,
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
  final Map<String, GroupReadReceipt>? groupReadReceipts;
  final MessageActions Function(ChatMessage message)? messageActionsBuilder;
  final Map<String, List<MessageReactionGroup>> messageReactions;

  /// 被「标记」的消息 id（本地扩展），用于气泡上的标记胶囊与长按菜单文案。
  final Set<String> flaggedClientMsgIds;
  final void Function(String source)? onPlayAudio;
  final void Function(ChatMessage message)? onRetrySend;

  /// 进入会话时会话记录的未读数（进入瞬间的快照）。
  ///
  /// OpenIM 的会话未读数与消息 isRead 可能不一致（跨端已读、历史数据）：
  /// 消息全标已读但会话仍记未读时，用它兜底定位分割线位置。
  final int unreadCountAtOpen;

  @override
  State<MessageList> createState() => MessageListState();
}

class MessageListState extends State<MessageList> {
  final Map<String, GlobalKey> _messageKeys = {};
  static const int _maxMessageKeys = 300;

  /// 离开底部多远才显示「回到最新」按钮（reverse 列表：offset 越大越靠上）。
  static const double _awayFromBottomThreshold = 240;

  /// 进入会话时的未读边界消息 id。
  ///
  /// 只在首次拿到消息时快照一次：之后已读回执会把 isRead 翻成 true，
  /// 若跟着重算，「以下为新消息」分割线会在进入会话后立刻消失。
  String? _unreadBoundaryId;

  /// 边界之后的条数（消息数变化时重算），用于「N 条新消息」。
  int _unreadBoundaryNewCount = 0;
  int _unreadBoundaryTotal = -1;

  /// 当前是否已离开列表底部（决定是否显示回到底部按钮）。
  bool _awayFromBottom = false;

  /// 分组时间头的时间间隔阈值（分钟）
  static const int _timeHeaderGapMinutes = 5;
  List<String?> _cachedDateLabels = const [];
  String _cachedDateLabelHeadId = '';
  String _cachedDateLabelTailId = '';
  int _cachedDateLabelCount = -1;

  /// 「是否需要对每条消息做可见性检测」的记忆化缓存。
  ///
  /// 该判断是整表扫描（历史已读的会话要扫完全部消息才能得出 false），
  /// 而列表会因新消息、已读回执等频繁重建；只在消息列表或当前用户变化时重算。
  bool _cachedNeedsVisibilityTracking = false;
  List<ChatMessage>? _cachedTrackingMessages;
  String? _cachedTrackingUserId;

  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_onScrollChanged);
  }

  @override
  void didUpdateWidget(MessageList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController.removeListener(_onScrollChanged);
      widget.scrollController.addListener(_onScrollChanged);
    }
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScrollChanged);
    super.dispose();
  }

  /// 列表是 reverse 的：offset 0 = 最新消息，越往上翻 offset 越大。
  void _onScrollChanged() {
    final controller = widget.scrollController;
    if (!controller.hasClients) return;
    final away = controller.position.pixels > _awayFromBottomThreshold;
    if (away != _awayFromBottom) {
      setState(() => _awayFromBottom = away);
    }
  }

  /// 首次拿到消息时快照未读边界；之后仅在消息数变化时刷新边界之后的条数。
  void _resolveUnreadBoundary(
    List<ChatMessage> messages,
    String? currentUserId,
  ) {
    if (messages.isEmpty) return;
    final boundaryId = _unreadBoundaryId;

    if (boundaryId == null) {
      if (_unreadBoundaryTotal == messages.length) return;
      _unreadBoundaryTotal = messages.length;
      final userId = currentUserId ?? '';
      for (var i = 0; i < messages.length; i++) {
        final message = messages[i];
        if (message.isRead || message.messageType == MessageType.system) {
          continue;
        }
        if (userId.isNotEmpty && message.sendId == userId) continue;
        _unreadBoundaryId = message.clientMsgId;
        _unreadBoundaryNewCount = messages.length - i;
        return;
      }
      // 兜底：消息都被标了已读、会话未读数却仍 > 0（跨端已读/历史数据常见），
      // 从尾部往回数未读数条对方消息，把分割线放在最早的那条上。
      if (widget.unreadCountAtOpen > 0) {
        var remaining = widget.unreadCountAtOpen;
        for (var i = messages.length - 1; i >= 0; i--) {
          final message = messages[i];
          if (message.messageType == MessageType.system) continue;
          if (userId.isNotEmpty && message.sendId == userId) continue;
          remaining--;
          if (remaining <= 0) {
            _unreadBoundaryId = message.clientMsgId;
            _unreadBoundaryNewCount = messages.length - i;
            return;
          }
        }
      }
      _unreadBoundaryNewCount = 0;
      return;
    }

    if (_unreadBoundaryTotal == messages.length) return;
    _unreadBoundaryTotal = messages.length;
    final index = messages.indexWhere((m) => m.clientMsgId == boundaryId);
    if (index < 0) {
      // 边界消息被删除/清空：分割线与计数一并失效。
      _unreadBoundaryId = null;
      _unreadBoundaryNewCount = 0;
      return;
    }
    _unreadBoundaryNewCount = messages.length - index;
  }

  void _scrollToBottom() {
    final controller = widget.scrollController;
    if (!controller.hasClients) return;
    controller.animateTo(
      0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  /// 该消息是否是本次进入会话时的未读起点（多选模式下不展示分割线）。
  bool _isUnreadBoundary(ChatMessage message) =>
      !widget.selectMode &&
      _unreadBoundaryId != null &&
      message.clientMsgId == _unreadBoundaryId;

  /// 未读分割线：对齐列表语汇，只留居中文字，不画两侧横线。
  Widget _buildUnreadDivider(BuildContext context) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Text(
          '以下为新消息',
          style: TextStyle(
            fontSize: 12,
            color: colors.primary.withValues(alpha: 0.9),
          ),
        ),
      ),
    );
  }

  /// 回到底部：离开底部时出现，带上「N 条新消息」提示。
  Widget _buildJumpToBottomButton(BuildContext context, AppColors colors) {
    final count = _unreadBoundaryNewCount;
    return Material(
      color: colors.surface,
      elevation: 3,
      shadowColor: colors.shadow,
      borderRadius: BorderRadius.circular(AppTheme.radiusPill),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _scrollToBottom,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (count > 0) ...[
                Text(
                  '$count 条新消息',
                  style: TextStyle(fontSize: 12, color: colors.primary),
                ),
                const SizedBox(width: 4),
              ],
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: colors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _needsVisibilityTracking(
    List<ChatMessage> messages,
    String? currentUserId,
  ) {
    final userId = currentUserId ?? '';
    if (identical(_cachedTrackingMessages, messages) &&
        _cachedTrackingUserId == userId) {
      return _cachedNeedsVisibilityTracking;
    }
    _cachedTrackingMessages = messages;
    _cachedTrackingUserId = userId;
    _cachedNeedsVisibilityTracking = messages.any(
      (m) => !m.isRead && (userId.isEmpty || m.sendId != userId),
    );
    return _cachedNeedsVisibilityTracking;
  }

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
    showMessageToolPanel(
      context: context,
      message: message,
      currentUserId: widget.currentUserId ?? '',
      actions: actions,
      flagged: widget.flaggedClientMsgIds.contains(message.clientMsgId),
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
    _resolveUnreadBoundary(widget.messages, widget.currentUserId);
    final itemCount = widget.messages.length + (widget.isLoading ? 1 : 0);
    final dateLabels = _dateLabelsFor(widget.messages);
    // 只有列表里还存在「对方发来的未读消息」时才逐项挂可见性检测（记忆化，见
    // _needsVisibilityTracking）：历史已读的会话不再为每条消息付订阅与逐帧计算。
    final trackVisibility =
        widget.onMessageVisible != null &&
        _needsVisibilityTracking(widget.messages, widget.currentUserId);
    // 只依赖 size.width 这一个 aspect：键盘动画期间 viewInsets 逐帧变化不会让列表
    // 每帧重建（MediaQuery.maybeOf 会注册无条件依赖，任何字段变化都会重建）。
    final maxBubbleWidth = (MediaQuery.maybeWidthOf(context) ?? 0) * 0.65;

    return Stack(
      children: [
        ListView.builder(
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
            final timeHeader = _timeHeaderFor(widget.messages, messageIndex);
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
              onVisible: trackVisibility ? widget.onMessageVisible : null,
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
              flagged: widget.flaggedClientMsgIds.contains(
                message.clientMsgId,
              ),
              groupReadReceipts: widget.groupReadReceipts,
              onPlayAudio: widget.onPlayAudio,
              onRetrySend: widget.onRetrySend,
            );

            return Column(
              key: messageKey,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (dateLabel != null) _buildDateSeparator(context, dateLabel),
                if (timeHeader != null) _buildTimeHeader(context, timeHeader),
                if (_isUnreadBoundary(message)) _buildUnreadDivider(context),
                messageBody,
              ],
            );
          },
        ),
        if (_awayFromBottom)
          Positioned(
            right: 16,
            bottom: 12,
            child: _buildJumpToBottomButton(context, colors),
          ),
      ],
    );
  }

  /// 日期分隔标签（每条消息是否需要 + 文案）。
  ///
  /// 用「首条 id + 尾条 id + 条数」做 O(1) 命中判断；未命中时只在两种常见变更上做
  /// 增量计算（尾部追加新消息 / 头部前插更早一页），其余情况才整表重算。
  /// 这样每翻一页不再对整表重新分配 DateTime（长历史下是 O(n) 的实时开销）。
  List<String?> _dateLabelsFor(List<ChatMessage> messages) {
    final count = messages.length;
    final headId = count == 0 ? '' : messages.first.clientMsgId;
    final tailId = count == 0 ? '' : messages.last.clientMsgId;
    if (count == _cachedDateLabelCount &&
        headId == _cachedDateLabelHeadId &&
        tailId == _cachedDateLabelTailId) {
      return _cachedDateLabels;
    }

    final now = DateTime.now();
    List<String?>? labels;
    if (_cachedDateLabelCount > 0 && count > _cachedDateLabelCount) {
      if (headId == _cachedDateLabelHeadId &&
          messages[_cachedDateLabelCount - 1].clientMsgId ==
              _cachedDateLabelTailId) {
        // 尾部追加（收到/发出新消息）：旧标签全部有效，只续算新增部分
        labels = List<String?>.of(_cachedDateLabels, growable: true);
        _appendDateLabels(labels, messages, _cachedDateLabelCount, now);
      } else if (tailId == _cachedDateLabelTailId &&
          messages[count - _cachedDateLabelCount].clientMsgId ==
              _cachedDateLabelHeadId) {
        // 头部前插（加载更早一页）：除旧块首条外，旧标签都可复用
        labels = _buildPrependedDateLabels(
          messages,
          count - _cachedDateLabelCount,
          now,
        );
      }
    }
    labels ??= _buildDateLabels(messages, now);

    _cachedDateLabels = labels;
    _cachedDateLabelCount = count;
    _cachedDateLabelHeadId = headId;
    _cachedDateLabelTailId = tailId;
    return labels;
  }

  /// 头部前插更早一页：只算前插块自身的标签，并按新前驱重判旧块首条；
  /// 旧块其余标签直接复用。
  List<String?> _buildPrependedDateLabels(
    List<ChatMessage> messages,
    int prependCount,
    DateTime now,
  ) {
    final labels = List<String?>.filled(messages.length, null);
    for (var i = 0; i < prependCount; i++) {
      final current = messages[i].sendDateTime;
      if (i == 0 || !_isSameDate(current, messages[i - 1].sendDateTime)) {
        labels[i] = _formatDateLabel(current, now);
      }
    }
    final firstOld = messages[prependCount].sendDateTime;
    labels[prependCount] =
        _isSameDate(firstOld, messages[prependCount - 1].sendDateTime)
        ? null
        : _formatDateLabel(firstOld, now);
    for (var i = 1; i < _cachedDateLabelCount; i++) {
      labels[prependCount + i] = _cachedDateLabels[i];
    }
    return labels;
  }

  /// 尾部追加：从 [start] 开始续算标签（[start] 之前已是有效标签）。
  static void _appendDateLabels(
    List<String?> labels,
    List<ChatMessage> messages,
    int start,
    DateTime now,
  ) {
    for (var i = start; i < messages.length; i++) {
      final current = messages[i].sendDateTime;
      if (i == 0 || !_isSameDate(current, messages[i - 1].sendDateTime)) {
        labels.add(_formatDateLabel(current, now));
      } else {
        labels.add(null);
      }
    }
  }

  /// 预计算每条消息是否需要日期分隔符及对应文案，避免 itemBuilder 内重复格式化。
  static List<String?> _buildDateLabels(
    List<ChatMessage> messages,
    DateTime now,
  ) {
    final labels = List<String?>.filled(messages.length, null);
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

  /// 构建日期分隔标签。
  ///
  /// 对齐飞书态：只有居中的日期文字，不画两侧横线（会话列表/设置页同样是
  /// 「靠留白分组、不靠分割线」，见 docs/conventions.md 的列表语汇）。
  Widget _buildDateSeparator(BuildContext context, String dateText) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Text(
          dateText,
          style: TextStyle(
            fontSize: 12,
            color: colors.textSecondary.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }

  /// 分组时间头：新的一天、或与上一条消息间隔 ≥ [_timeHeaderGapMinutes] 分钟时，
  /// 在消息上方居中显示时间（对齐飞书稿，气泡下方只留状态图标）。
  String? _timeHeaderFor(List<ChatMessage> messages, int index) {
    final current = messages[index];
    if (index > 0) {
      final previous = messages[index - 1];
      final sameDay = _isSameDate(current.sendDateTime, previous.sendDateTime);
      final gapMinutes = current.sendDateTime
          .difference(previous.sendDateTime)
          .inMinutes;
      if (sameDay && gapMinutes.abs() < _timeHeaderGapMinutes) return null;
    }
    return formatMessageTime(current.sendDateTime);
  }

  Widget _buildTimeHeader(BuildContext context, String timeText) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 6),
      child: Center(
        child: Text(
          timeText,
          style: TextStyle(
            fontSize: 12,
            color: context.appColors.textSecondary.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }
}

/// 带可见性检测的消息气泡
/// 单条消息气泡（带可见性检测）。
///
/// 上传进度**在这里订阅**（只订阅本条消息的进度）：进度每 tick 都会产生一张新 Map，
/// 若在上层订阅会让整段列表跟着重建；下沉后只有正在上传的那条气泡重建。
class _VisibleMessageBubble extends ConsumerWidget {
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
    this.flagged = false,
    this.groupReadReceipts,
    this.onPlayAudio,
    this.onRetrySend,
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
  final bool flagged;
  final Map<String, GroupReadReceipt>? groupReadReceipts;
  final void Function(String source)? onPlayAudio;
  final void Function(ChatMessage message)? onRetrySend;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uploadProgress = ref.watch(
      messageServiceProvider.select(
        (s) => s.uploadProgress[message.clientMsgId],
      ),
    );
    final groupReadReceipt =
        groupReadReceipts?[message.clientMsgId] ??
        groupReadReceipts?[message.serverMsgId];
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
        flagged: flagged,
        uploadProgress: uploadProgress,
        groupReadReceipt: groupReadReceipt,
        onPlayAudio: onPlayAudio,
        onRetrySend: onRetrySend,
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
        flagged: flagged,
        uploadProgress: uploadProgress,
        groupReadReceipt: groupReadReceipt,
        onPlayAudio: onPlayAudio,
        onRetrySend: onRetrySend,
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
  // 气泡内部订阅上传进度，预览需要 ProviderScope
  return ProviderScope(
    child: Padding(
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
    ),
  );
}
