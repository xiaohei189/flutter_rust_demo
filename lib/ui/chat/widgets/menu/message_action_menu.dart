import 'package:flutter/material.dart';

import '../../../../domain/models/chat_message.dart' show ChatMessage;
import '../../../core/theme/app_theme.dart';
import 'message_tool_panel.dart';

/// 消息操作面板顶部的快捷表情（对齐飞书稿：一行 6 个 + 末尾「⋯」）
const List<String> kMessageQuickReactions = [
  '👍',
  '❤️',
  '😄',
  '🎉',
  '😭',
  '🙏',
];

/// 面板顶部表情的分页（「⋯」就地切换，展示更多图形，对齐飞书稿）
const List<List<String>> kMessageQuickReactionPages = [
  kMessageQuickReactions,
  ['😮', '🥺', '😁', '😊', '👏', '🔥'],
  ['🤝', '💪', '🥳', '😅', '😘', '😢'],
];

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
  });
}

/// 长按消息弹出的消息工具面板（底部弹层，对齐飞书稿）。
void showMessageToolPanel({
  required BuildContext context,
  required ChatMessage message,
  required String currentUserId,
  required MessageActions actions,
  Set<String> reactions = const {},
}) {
  final colors = context.appColors;
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: colors.background,
    barrierColor: Colors.black.withValues(alpha: 0.25),
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (sheetContext) => ConstrainedBox(
      constraints: BoxConstraints(
        // 对齐飞书稿：首次弹出约占屏幕一半高度，内容在弹层内滚动
        maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.5,
      ),
      child: MessageToolPanel(
        message: message,
        currentUserId: currentUserId,
        actions: actions,
        reactions: reactions,
        rootContext: context,
        onClose: () => Navigator.of(sheetContext).maybePop(),
      ),
    ),
  );
}
