import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// 聊天输入框：自适应高度、Markdown 字体、展开编辑抽屉入口。
class ChatInputField extends StatelessWidget {
  const ChatInputField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.isMarkdownMode,
    required this.onOpenComposer,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isMarkdownMode;
  final VoidCallback onOpenComposer;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      minLines: 1,
      maxLines: isMarkdownMode ? 12 : 8,
      maxLength: 4000,
      buildCounter:
          (_, {required currentLength, required isFocused, int? maxLength}) =>
              const SizedBox.shrink(),
      textInputAction: TextInputAction.send,
      style: TextStyle(
        fontSize: 16,
        color: context.appColors.textPrimary,
        fontFamily: isMarkdownMode ? 'monospace' : null,
      ),
      decoration: InputDecoration(
        hintText: '输入消息...',
        hintStyle: TextStyle(
          color: context.appColors.textSecondary,
          fontSize: 16,
        ),
        filled: true,
        fillColor: context.appColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        suffixIcon: IconButton(
          icon: const Icon(Icons.open_in_full, size: 18),
          tooltip: '展开编辑',
          onPressed: onOpenComposer,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
        suffixIconConstraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      ),
      onTapOutside: (_) {},
      onSubmitted: (_) => onSubmitted(),
    );
  }
}