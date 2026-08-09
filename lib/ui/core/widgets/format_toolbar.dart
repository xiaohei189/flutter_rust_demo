import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Markdown 格式操作类型
enum MarkdownFormat {
  bold,
  italic,
  strikethrough,
  heading,
  inlineCode,
  quote,
  bulletList,
  link,
}

/// 格式操作回调
typedef MarkdownFormatCallback = void Function(MarkdownFormat format);

/// Markdown 格式工具栏：一行紧凑按钮，水平可滚动
class FormatToolbar extends StatelessWidget {
  final MarkdownFormatCallback onFormat;
  final VoidCallback? onClose;

  const FormatToolbar({
    super.key,
    required this.onFormat,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppTheme.formatBarHeight,
      decoration: const BoxDecoration(
        color: AppTheme.formatBarBg,
        border: Border(
          top: BorderSide(color: AppTheme.dividerColor, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                _buildButton(MarkdownFormat.bold, 'B', '粗体'),
                _buildButton(MarkdownFormat.italic, 'I', '斜体'),
                _buildButton(MarkdownFormat.strikethrough, 'S', '删除线',
                    strikethrough: true),
                _buildButton(MarkdownFormat.heading, 'H', '标题'),
                _buildButton(MarkdownFormat.inlineCode, '<>', '行内代码',
                    monospace: true),
                _buildButton(MarkdownFormat.quote, '"', '引用'),
                _buildButton(MarkdownFormat.bulletList, '•', '列表'),
                _buildButton(MarkdownFormat.link, '🔗', '链接'),
              ],
            ),
          ),
          // 关闭按钮
          if (onClose != null)
            SizedBox(
              width: 32,
              height: AppTheme.formatBarHeight,
              child: IconButton(
                icon: const Icon(Icons.close, size: 16),
                onPressed: onClose,
                padding: EdgeInsets.zero,
                color: AppTheme.textSecondaryColor,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildButton(
    MarkdownFormat format,
    String label,
    String tooltip, {
    bool strikethrough = false,
    bool monospace = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onFormat(format),
          borderRadius: BorderRadius.circular(6),
          child: Container(
            width: 36,
            height: AppTheme.formatBarHeight,
            alignment: Alignment.center,
            child: strikethrough
                ? Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimaryColor,
                      decoration: TextDecoration.lineThrough,
                    ),
                  )
                : Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimaryColor,
                      fontFamily: monospace ? 'monospace' : null,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
