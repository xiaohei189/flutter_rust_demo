import 'package:flutter/material.dart';

import '../../../previews/app_theme_preview.dart';
import '../../../core/theme/app_theme.dart';
import 'format_toolbar.dart' show MarkdownFormat;

/// Markdown 格式栏：格式按钮 + 返回普通输入。
class MarkdownFormatBar extends StatelessWidget {
  const MarkdownFormatBar({
    super.key,
    required this.onFormat,
    required this.onClose,
    this.trailing,
  });

  final ValueChanged<MarkdownFormat> onFormat;
  final VoidCallback onClose;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.swap_vert, size: 20),
            tooltip: '返回普通输入',
            color: context.appColors.primary,
            onPressed: onClose,
          ),
          const SizedBox(width: 4),
          // 格式按钮区可横向滚动，窄屏不溢出；关闭/发送固定右侧
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _formatBtn(context, 'B', '粗体', () => onFormat(MarkdownFormat.bold)),
                  _formatBtn(
                    context,
                    'I',
                    '斜体',
                    () => onFormat(MarkdownFormat.italic),
                    italic: true,
                  ),
                  _formatBtn(
                    context,
                    'S',
                    '删除线',
                    () => onFormat(MarkdownFormat.strikethrough),
                    strikethrough: true,
                  ),
                  _formatBtn(
                    context,
                    'H',
                    '标题',
                    () => onFormat(MarkdownFormat.heading),
                  ),
                  _formatBtn(
                    context,
                    '<>',
                    '行内代码',
                    () => onFormat(MarkdownFormat.inlineCode),
                    mono: true,
                  ),
                  _formatBtn(context, '"', '引用', () => onFormat(MarkdownFormat.quote)),
                  _formatBtn(
                    context,
                    '•',
                    '列表',
                    () => onFormat(MarkdownFormat.bulletList),
                  ),
                  _formatBtn(context, '🔗', '链接', () => onFormat(MarkdownFormat.link)),
                ],
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }

  Widget _formatBtn(
    BuildContext context,
    String label,
    String tooltip,
    VoidCallback onTap, {
    bool italic = false,
    bool strikethrough = false,
    bool mono = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            width: 36,
            height: 44,
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: context.appColors.textPrimary.withValues(alpha: 0.7),
                  fontFamily: mono ? 'monospace' : null,
                  fontStyle: italic ? FontStyle.italic : null,
                  decoration: strikethrough ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ==================== 预览 ====================

@AppThemePreview(name: 'Markdown 格式栏（含关闭）', group: 'MarkdownFormatBar')
Widget markdownFormatBarPreview() {
  return const Padding(
    padding: EdgeInsets.all(16),
    child: MarkdownFormatBar(onFormat: _noopFormat, onClose: _noop),
  );
}

void _noopFormat(MarkdownFormat format) {}

void _noop() {}
