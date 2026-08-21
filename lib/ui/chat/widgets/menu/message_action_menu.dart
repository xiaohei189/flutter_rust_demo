import 'package:flutter/material.dart';

import '../../../../domain/models/chat_message.dart' show ChatMessage;
import 'message_tool_panel_overlay.dart';

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
    builder: (overlayContext) => MessageToolPanelOverlay(
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
