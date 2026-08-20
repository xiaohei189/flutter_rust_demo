import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../mappers/message_display.dart';
import '../../../../domain/models/chat_message.dart' show ChatMessage;
import '../../../core/theme/app_theme.dart';
import 'quick_reply_panel.dart';

const List<String> kMessageQuickReactions = ['👍', '❤️', '😄', '🙏'];
/// 消息操作回调
class MessageActions {
  final void Function(ChatMessage message) onCopy;
  final void Function(ChatMessage message) onRevoke;
  final void Function(ChatMessage message) onDelete;
  final void Function(ChatMessage message) onForward;
  final void Function(ChatMessage message) onQuote;
  final VoidCallback? onMultiSelect;
  final void Function(ChatMessage message)? onResend;
  final void Function(ChatMessage message)? onPin;
  final void Function(ChatMessage message, String emoji)? onReaction;
  final void Function(ChatMessage message, String text)? onQuickReply;

  const MessageActions({
    required this.onCopy,
    required this.onRevoke,
    required this.onDelete,
    required this.onForward,
    required this.onQuote,
    this.onMultiSelect,
    this.onResend,
    this.onPin,
    this.onReaction,
    this.onQuickReply,
  });
}

/// 长按消息弹出的消息工具面板。
void showMessageToolPanel({
  required BuildContext context,
  required Rect anchor,
  required ChatMessage message,
  required String currentUserId,
  required MessageActions actions,
  Set<String> reactions = const {},
}) {
  final overlay = Overlay.of(context);
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (overlayContext) => _MessageToolPanelOverlay(
      anchor: anchor,
      message: message,
      currentUserId: currentUserId,
      actions: actions,
      reactions: reactions,
      rootContext: context,
      onClose: () {
        if (entry.mounted) entry.remove();
      },
    ),
  );
  overlay.insert(entry);
}

class _MessageToolPanelOverlay extends StatelessWidget {
  const _MessageToolPanelOverlay({
    required this.anchor,
    required this.message,
    required this.currentUserId,
    required this.actions,
    required this.reactions,
    required this.rootContext,
    required this.onClose,
  });

  final Rect anchor;
  final ChatMessage message;
  final String currentUserId;
  final MessageActions actions;
  final Set<String> reactions;
  final BuildContext rootContext;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onClose,
          ),
        ),
        Positioned.fill(
          child: CustomSingleChildLayout(
            delegate: _MessageToolPanelLayoutDelegate(anchor: anchor),
            child: _MessageToolPanel(
              message: message,
              currentUserId: currentUserId,
              actions: actions,
              reactions: reactions,
              rootContext: rootContext,
              onClose: onClose,
            ),
          ),
        ),
      ],
    );
  }
}

class _MessageToolPanelLayoutDelegate extends SingleChildLayoutDelegate {
  const _MessageToolPanelLayoutDelegate({required this.anchor});

  final Rect anchor;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final maxWidth = math.min(
      360.0,
      math.max(0.0, constraints.maxWidth - 24),
    );
    return BoxConstraints(
      maxWidth: maxWidth,
      maxHeight: math.max(0.0, constraints.maxHeight - 24),
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final maxLeft = size.width - childSize.width - 12;
    final left = maxLeft < 12
        ? 12.0
        : ((anchor.left + anchor.right - childSize.width) / 2)
              .clamp(12.0, maxLeft)
              .toDouble();
    final above = anchor.top - childSize.height - 8;
    final below = anchor.bottom + 8;
    final top = above < 8 || below + childSize.height > size.height
        ? math.max(8.0, above)
        : below;
    return Offset(left, top);
  }

  @override
  bool shouldRelayout(covariant _MessageToolPanelLayoutDelegate oldDelegate) =>
      oldDelegate.anchor != anchor;
}

class _MessageToolPanel extends StatefulWidget {
  const _MessageToolPanel({
    required this.message,
    required this.currentUserId,
    required this.actions,
    required this.reactions,
    required this.rootContext,
    required this.onClose,
  });

  final ChatMessage message;
  final String currentUserId;
  final MessageActions actions;
  final Set<String> reactions;
  final BuildContext rootContext;
  final VoidCallback onClose;

  @override
  State<_MessageToolPanel> createState() => _MessageToolPanelState();
}

class _MessageToolPanelState extends State<_MessageToolPanel> {
  bool _showQuickReplyPanel = false;
  bool get _isFromMe => widget.message.sendId == widget.currentUserId;

  bool get _canRevoke =>
      _isFromMe &&
      DateTime.now().difference(widget.message.sendDateTime).inMinutes < 2;

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Material(
      color: colors.surface,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      ),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: _showQuickReplyPanel
            ? QuickReplyPanel(
                onBack: () => setState(() => _showQuickReplyPanel = false),
                onQuickReply: (emoji) {
                  widget.onClose();
                  widget.actions.onQuickReply?.call(widget.message, emoji);
                },
              )
            : _buildQuickPanel(context, colors),
      ),
    );
  }

  Widget _buildQuickPanel(BuildContext context, AppColors colors) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            for (final emoji in kMessageQuickReactions)
              Expanded(
                child: _QuickReactionButton(
                  emoji: emoji,
                  selected: widget.reactions.contains(emoji),
                  onTap: () {
                    widget.onClose();
                    widget.actions.onReaction?.call(widget.message, emoji);
                  },
                ),
              ),
            IconButton(
              icon: const Icon(Icons.swap_horiz),
              tooltip: '切换快速回复',
              onPressed: () => setState(() => _showQuickReplyPanel = true),
            ),
          ],
        ),
        Divider(height: 1, color: colors.divider),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 12),
          child: Wrap(
            spacing: 8,
            runSpacing: 10,
            children: _buildActions(),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildActions() {
    final actions = <_MessageToolAction>[
      _MessageToolAction(
        icon: Icons.copy_rounded,
        label: '复制',
        onTap: () => _runAction(widget.actions.onCopy),
      ),
      _MessageToolAction(
        icon: Icons.reply_rounded,
        label: '回复',
        onTap: () => _runAction(widget.actions.onQuote),
      ),
      _MessageToolAction(
        icon: Icons.forward_rounded,
        label: '转发',
        onTap: () => _runAction(widget.actions.onForward),
      ),
    ];

    if (widget.actions.onPin != null) {
      actions.add(
        _MessageToolAction(
          icon: Icons.push_pin_outlined,
          label: '置顶',
          onTap: () {
            widget.onClose();
            widget.actions.onPin!(widget.message);
          },
        ),
      );
    }

    if (widget.actions.onMultiSelect != null) {
      actions.add(
        _MessageToolAction(
          icon: Icons.library_add_check_outlined,
          label: '多选',
          onTap: () {
            widget.onClose();
            widget.actions.onMultiSelect!();
          },
        ),
      );
    }

    if (_canRevoke) {
      actions.add(
        _MessageToolAction(
          icon: Icons.undo_rounded,
          label: '撤回',
          onTap: () => _runAction(widget.actions.onRevoke),
        ),
      );
    }

    if (_isFromMe &&
        widget.message.status == 3 &&
        widget.actions.onResend != null) {
      actions.add(
        _MessageToolAction(
          icon: Icons.refresh_rounded,
          label: '重发',
          onTap: () => _runAction(widget.actions.onResend!),
        ),
      );
    }

    actions.add(
      _MessageToolAction(
        icon: Icons.delete_outline_rounded,
        label: '删除',
        isDestructive: true,
        onTap: _confirmDelete,
      ),
    );

    return actions
        .map(
          (action) => _MessageToolTile(
            action: action,
            onTap: action.onTap,
          ),
        )
        .toList();
  }

  void _runAction(void Function(ChatMessage message) action) {
    widget.onClose();
    action(widget.message);
  }

  void _confirmDelete() {
    widget.onClose();
    showDialog<void>(
      context: widget.rootContext,
      builder: (ctx) => AlertDialog(
        title: const Text('删除消息'),
        content: const Text('确定删除这条消息吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              widget.actions.onDelete(widget.message);
            },
            child: Text(
              '删除',
              style: TextStyle(color: ctx.appColors.danger),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickReactionButton extends StatelessWidget {
  const _QuickReactionButton({
    required this.emoji,
    required this.selected,
    required this.onTap,
  });

  final String emoji;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return InkResponse(
      onTap: onTap,
      radius: 20,
      child: Container(
        height: 44,
        alignment: Alignment.center,
        decoration: selected
            ? BoxDecoration(
                color: colors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              )
            : null,
        child: Text(emoji, style: const TextStyle(fontSize: 20)),
      ),
    );
  }
}


class _MessageToolAction {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  const _MessageToolAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });
}

class _MessageToolTile extends StatelessWidget {
  const _MessageToolTile({
    required this.action,
    required this.onTap,
  });

  final _MessageToolAction action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final color = action.isDestructive ? colors.danger : colors.textPrimary;
    return SizedBox(
      width: 76,
      height: 62,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(action.icon, size: 22, color: color),
            const SizedBox(height: 5),
            Text(
              action.label,
              style: TextStyle(fontSize: 12, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

