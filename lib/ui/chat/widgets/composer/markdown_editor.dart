import 'package:flutter/material.dart';

import 'format_toolbar.dart' show MarkdownFormat;

/// Markdown 标记插入：包裹选中文本或插入占位符。
class MarkdownEditor {
  const MarkdownEditor();

  void handleFormat(TextEditingController controller, MarkdownFormat format) {
    switch (format) {
      case MarkdownFormat.bold:
        _insertMarkup(controller, '**', '**');
      case MarkdownFormat.italic:
        _insertMarkup(controller, '*', '*');
      case MarkdownFormat.strikethrough:
        _insertMarkup(controller, '~~', '~~');
      case MarkdownFormat.heading:
        _insertMarkup(controller, '## ', '');
      case MarkdownFormat.inlineCode:
        _insertMarkup(controller, '`', '`');
      case MarkdownFormat.quote:
        _insertMarkup(controller, '> ', '');
      case MarkdownFormat.bulletList:
        _insertMarkup(controller, '- ', '');
      case MarkdownFormat.link:
        _insertMarkup(controller, '[', '](url)');
    }
  }

  String placeholderFor(String prefix) {
    return switch (prefix) {
      '**' => '粗体',
      '*' => '斜体',
      '~~' => '删除线',
      '## ' => '标题',
      '`' => '代码',
      '> ' => '引用',
      '- ' => '列表',
      '[' => '文字',
      _ => '',
    };
  }

  /// 在光标处插入/包裹 Markdown 标记。
  void _insertMarkup(
    TextEditingController controller,
    String prefix,
    String suffix,
  ) {
    final text = controller.text;
    final selection = controller.selection;

    if (selection.isValid && selection.start < selection.end) {
      // 有选中文字：包裹选中内容
      final selected = selection.textInside(text);
      final newText = text.replaceRange(
        selection.start,
        selection.end,
        '$prefix$selected$suffix',
      );
      controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
          offset:
              selection.start + prefix.length + selected.length + suffix.length,
        ),
      );
    } else {
      // 无选中：插入标记，光标放在标记中间
      final offset = selection.baseOffset >= 0
          ? selection.baseOffset
          : text.length;
      final placeholder = placeholderFor(prefix);
      final newText = text.replaceRange(
        offset,
        offset,
        '$prefix$placeholder$suffix',
      );
      controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection(
          baseOffset: offset + prefix.length,
          extentOffset: offset + prefix.length + placeholder.length,
        ),
      );
    }
  }
}
