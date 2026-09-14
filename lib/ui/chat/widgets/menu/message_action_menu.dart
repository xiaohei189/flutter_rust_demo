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
///
/// 弹层高度可用手往上拖（0.5 → 0.92 两档吸附），「⋯」切换到完整表情界面。
void showMessageToolPanel({
  required BuildContext context,
  required ChatMessage message,
  required String currentUserId,
  required MessageActions actions,
  Set<String> reactions = const {},
}) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.25),
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => DraggableScrollableSheet(
      // 首屏约占屏幕一半（对齐飞书稿），可往上拖到接近全屏
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.92,
      expand: false,
      snap: true,
      snapSizes: const [0.5, 0.92],
      builder: (contentContext, scrollController) => DecoratedBox(
        decoration: BoxDecoration(
          color: context.appColors.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        ),
        child: MessageToolPanel(
          message: message,
          currentUserId: currentUserId,
          actions: actions,
          reactions: reactions,
          rootContext: context,
          scrollController: scrollController,
          onClose: () => Navigator.of(sheetContext).maybePop(),
        ),
      ),
    ),
  );
}
