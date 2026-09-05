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
      maxLines: isMarkdownMode ? 12 : 5,
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
        contentPadding: const EdgeInsets.only(
          left: 12, // 输入框左侧内边距（文字距输入框左缘）
          right: 0, // 输入框右侧内边距（放大箭头在右侧，0 让箭头尽量贴右）
          top: 10, // 输入框上下内边距（决定单行高度/行高）
          bottom: 10,
        ),
        suffixIcon: Tooltip(
          message: '展开编辑',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onOpenComposer,
            child: const SizedBox(
              // 放大箭头区域：width 越大箭头越靠输入框左（右侧留白越多）；越小越贴右缘（与「输入框→表情」间距相关）
              width: 26,
              height: 32, // 箭头点击高度
              child: Icon(Icons.open_in_full, size: 18),
            ),
          ),
        ),
        suffixIconConstraints: const BoxConstraints(
          minWidth: 26, // 与上方箭头区域宽度保持一致
          minHeight: 32,
        ),
      ),
      onTapOutside: (_) {},
      onSubmitted: (_) => onSubmitted(),
    );
  }
}
