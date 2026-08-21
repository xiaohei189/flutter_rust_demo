import 'package:flutter/material.dart';

import 'chat_input_field.dart';
import 'input_toolbar_icon.dart';

/// 未聚焦默认态：一行 [🎤] [输入框] [😊] [➕]。
class CollapsedInputBar extends StatelessWidget {
  const CollapsedInputBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.isMarkdownMode,
    required this.onOpenComposer,
    required this.onSubmitted,
    required this.emojiActive,
    required this.moreActive,
    required this.onToggleEmoji,
    required this.onToggleMore,
    required this.onVoiceLongPressStart,
    required this.onVoiceLongPressMoveUpdate,
    required this.onVoiceLongPressEnd,
    required this.onVoiceTap,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isMarkdownMode;
  final VoidCallback onOpenComposer;
  final VoidCallback onSubmitted;
  final bool emojiActive;
  final bool moreActive;
  final VoidCallback onToggleEmoji;
  final VoidCallback onToggleMore;
  final void Function(LongPressStartDetails)? onVoiceLongPressStart;
  final void Function(LongPressMoveUpdateDetails)? onVoiceLongPressMoveUpdate;
  final void Function(LongPressEndDetails)? onVoiceLongPressEnd;
  final VoidCallback onVoiceTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        InputToolbarIcon(
          icon: Icons.mic_none,
          tooltip: '语音（长按录音，上滑取消）',
          onLongPressStart: onVoiceLongPressStart,
          onLongPressMoveUpdate: onVoiceLongPressMoveUpdate,
          onLongPressEnd: onVoiceLongPressEnd,
          onTap: onVoiceTap,
        ),
        const SizedBox(width: 4),
        Expanded(
          child: ChatInputField(
            controller: controller,
            focusNode: focusNode,
            isMarkdownMode: isMarkdownMode,
            onOpenComposer: onOpenComposer,
            onSubmitted: onSubmitted,
          ),
        ),
        InputToolbarIcon(
          icon: emojiActive
              ? Icons.emoji_emotions
              : Icons.emoji_emotions_outlined,
          tooltip: '表情',
          onTap: onToggleEmoji,
        ),
        InputToolbarIcon(
          icon: moreActive ? Icons.add_circle : Icons.add_circle_outline,
          tooltip: '更多',
          onTap: onToggleMore,
        ),
      ],
    );
  }
}