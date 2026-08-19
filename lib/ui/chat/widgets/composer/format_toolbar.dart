import 'package:flutter/material.dart';

import '../../../previews/app_theme_preview.dart';
import '../../../core/theme/app_theme.dart';

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

  const FormatToolbar({super.key, required this.onFormat, this.onClose});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      height: AppTheme.formatBarHeight,
      decoration: BoxDecoration(
        color: colors.formatBarBackground,
        border: Border(top: BorderSide(color: colors.divider, width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                _buildButton(context, MarkdownFormat.bold, 'B', '粗体'),
                _buildButton(context, MarkdownFormat.italic, 'I', '斜体'),
                _buildButton(
                  context,
                  MarkdownFormat.strikethrough,
                  'S',
                  '删除线',
                  strikethrough: true,
                ),
                _buildButton(context, MarkdownFormat.heading, 'H', '标题'),
                _buildButton(
                  context,
                  MarkdownFormat.inlineCode,
                  '<>',
                  '行内代码',
                  monospace: true,
                ),
                _buildButton(context, MarkdownFormat.quote, '"', '引用'),
                _buildButton(context, MarkdownFormat.bulletList, '•', '列表'),
                _buildButton(context, MarkdownFormat.link, '🔗', '链接'),
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
                color: colors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildButton(
    BuildContext context,
    MarkdownFormat format,
    String label,
    String tooltip, {
    bool strikethrough = false,
    bool monospace = false,
  }) {
    final colors = context.appColors;
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
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                      decoration: TextDecoration.lineThrough,
                    ),
                  )
                : Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                      fontFamily: monospace ? 'monospace' : null,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

// ==================== 预览 ====================

@AppThemePreview(name: 'Markdown 格式工具栏', group: 'FormatToolbar')
Widget formatToolbarPreview() {
  return const Padding(
    padding: EdgeInsets.all(16),
    child: FormatToolbar(onFormat: _noopFormat, onClose: _noop),
  );
}

void _noopFormat(MarkdownFormat format) {}

void _noop() {}
