import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import 'attachment_panel.dart';
import 'chat_action_toolbar.dart';
import 'emoji_panel.dart';
import 'format_toolbar.dart' show MarkdownFormat;
import 'message_content_type.dart';

/// 展开编辑抽屉（飞书式）：全宽大编辑区，用于长文 / Markdown 输入。
///
/// - 底部与主输入框共用同一套完整工具栏 [ChatActionToolbar]（含表情/更多面板）、
///   「发送」按钮直接发送并缩回抽屉
/// - Aa 在底部工具栏中切换，Markdown 模式下顶部展开格式按钮栏
/// - 与主输入框共享同一个 [TextEditingController]，草稿天然同步
class MessageComposerSheet extends StatefulWidget {
  const MessageComposerSheet({
    super.key,
    required this.controller,
    required this.hasText,
    required this.onSend,
    this.onImagePick,
    this.onAtMention,
    this.onGifSelected,
    this.attachmentItems = const [],
  });

  final TextEditingController controller;

  /// 输入框是否有文字（驱动发送按钮可用态）
  final ValueListenable<bool> hasText;

  /// 发送并关闭抽屉
  final void Function(String text, MessageContentType type) onSend;

  final VoidCallback? onImagePick;
  final VoidCallback? onAtMention;
  final ValueChanged<String>? onGifSelected;
  final List<AttachmentItem> attachmentItems;

  @override
  State<MessageComposerSheet> createState() => _MessageComposerSheetState();
}

/// 表情/附件面板互斥展开
enum _Panel { none, emoji, attachment }

class _MessageComposerSheetState extends State<MessageComposerSheet> {
  /// 是否 Markdown 模式（底部工具栏 Aa 切换，Markdown 时顶部展开格式栏）
  bool _isMarkdownMode = true;

  _Panel _activePanel = _Panel.none;

  // ==================== Markdown 格式插入（与主输入框同逻辑） ====================

  void _handleFormat(MarkdownFormat format) {
    switch (format) {
      case MarkdownFormat.bold:
        _insertMarkdown('**', '**');
      case MarkdownFormat.italic:
        _insertMarkdown('*', '*');
      case MarkdownFormat.strikethrough:
        _insertMarkdown('~~', '~~');
      case MarkdownFormat.heading:
        _insertMarkdown('## ', '');
      case MarkdownFormat.inlineCode:
        _insertMarkdown('`', '`');
      case MarkdownFormat.quote:
        _insertMarkdown('> ', '');
      case MarkdownFormat.bulletList:
        _insertMarkdown('- ', '');
      case MarkdownFormat.link:
        _insertMarkdown('[', '](url)');
    }
  }

  void _insertMarkdown(String prefix, String suffix) {
    final controller = widget.controller;
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
      final placeholder = _placeholderFor(prefix);
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

  String _placeholderFor(String prefix) {
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

  void _insertEmoji(String emoji) {
    final controller = widget.controller;
    final text = controller.text;
    final selection = controller.selection;
    final start = selection.start >= 0 ? selection.start : text.length;
    final end = selection.end >= 0 ? selection.end : text.length;
    final newText = text.replaceRange(start, end, emoji);
    controller.text = newText;
    controller.selection = TextSelection.fromPosition(
      TextPosition(offset: start + emoji.length),
    );
  }

  void _togglePanel(_Panel panel) {
    setState(() => _activePanel = _activePanel == panel ? _Panel.none : panel);
  }

  void _closeAllPanels() {
    setState(() => _activePanel = _Panel.none);
  }

  void _send() {
    final text = widget.controller.text.trim();
    if (text.isEmpty) return;
    widget.onSend(
      text,
      _isMarkdownMode ? MessageContentType.markdown : MessageContentType.text,
    );
    Navigator.of(context).pop();
  }

  // ==================== 构建 ====================

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Padding(
      // 键盘弹出时整体抬起
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        child: Column(
          children: [
            // 拖拽把手（下滑缩回提示）
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // 顶栏：仅保留 Markdown 格式区 + 回缩按钮
            SizedBox(
              height: 44,
              child: Row(
                children: [
                  Expanded(
                    child: _isMarkdownMode
                        ? SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            child: Row(
                              children: [
                                _formatBtn('B', '粗体', MarkdownFormat.bold),
                                _formatBtn(
                                  'I',
                                  '斜体',
                                  MarkdownFormat.italic,
                                  italic: true,
                                ),
                                _formatBtn(
                                  'S',
                                  '删除线',
                                  MarkdownFormat.strikethrough,
                                  strikethrough: true,
                                ),
                                _formatBtn('H', '标题', MarkdownFormat.heading),
                                _formatBtn(
                                  '<>',
                                  '行内代码',
                                  MarkdownFormat.inlineCode,
                                  mono: true,
                                ),
                                _formatBtn('"', '引用', MarkdownFormat.quote),
                                _formatBtn(
                                  '•',
                                  '列表',
                                  MarkdownFormat.bulletList,
                                ),
                                _formatBtn('🔗', '链接', MarkdownFormat.link),
                              ],
                            ),
                          )
                        : const Spacer(),
                  ),
                  // 回缩按钮：与主输入框的 open_in_full 展开按钮成对（close_fullscreen）
                  IconButton(
                    icon: Icon(
                      Icons.close_fullscreen,
                      size: 20,
                      color: colors.textSecondary, // 与其他图标统一
                    ),
                    tooltip: '缩回',
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
            Divider(color: colors.divider, height: 1),
            // 大编辑区：无填充背景，与抽屉融为一体
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: TextField(
                  controller: widget.controller,
                  autofocus: true,
                  // expands 填满抽屉剩余高度（minLines/maxLines 需为 null）
                  expands: true,
                  minLines: null,
                  maxLines: null,
                  maxLength: 4000,
                  buildCounter: (
                    _,
                    {
                    required currentLength,
                    required isFocused,
                    int? maxLength,
                  }) =>
                      const SizedBox.shrink(),
                  style: TextStyle(
                    fontSize: 16,
                    color: colors.textPrimary,
                    fontFamily: _isMarkdownMode ? 'monospace' : null,
                  ),
                  decoration: InputDecoration(
                    hintText: _isMarkdownMode ? '输入 Markdown...' : '输入长消息...',
                    hintStyle: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 16,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ),
            // 表情/附件面板（互斥展开，与主输入框一致）
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Offstage(
                    offstage: _activePanel != _Panel.emoji,
                    child: EmojiPanel(
                      onEmojiSelected: _insertEmoji,
                      onGifSelected: widget.onGifSelected,
                      onClose: () => _closeAllPanels(),
                    ),
                  ),
                  Offstage(
                    offstage: _activePanel != _Panel.attachment,
                    child: AttachmentPanel(
                      items: widget.attachmentItems,
                      onItemTap: _closeAllPanels,
                    ),
                  ),
                ],
              ),
            ),
            Divider(color: colors.divider, height: 1),
            // 底部完整工具栏（与主输入框共用）
            ChatActionToolbar(
              emojiActive: _activePanel == _Panel.emoji,
              moreActive: _activePanel == _Panel.attachment,
              markdownActive: _isMarkdownMode,
              markdownTooltip: _isMarkdownMode ? '关闭 Markdown' : 'Markdown 格式',
              hasText: widget.hasText,
              onEmoji: () => _togglePanel(_Panel.emoji),
              onAt: widget.onAtMention ?? () {},
              onImage: widget.onImagePick ?? () {},
              imageEnabled: widget.onImagePick != null,
              onFormat: () {
                HapticFeedback.lightImpact();
                setState(() => _isMarkdownMode = !_isMarkdownMode);
                _closeAllPanels();
              },
              onMore: () => _togglePanel(_Panel.attachment),
              onSend: _send,
            ),
          ],
        ),
      ),
    );
  }

  /// 透明背景格式按钮（与抽屉背景融为一体）
  Widget _formatBtn(
    String label,
    String tooltip,
    MarkdownFormat format, {
    bool italic = false,
    bool strikethrough = false,
    bool mono = false,
  }) {
    final colors = context.appColors;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _handleFormat(format),
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
                  color: colors.textPrimary.withValues(alpha: 0.7),
                  fontStyle: italic ? FontStyle.italic : null,
                  decoration: strikethrough ? TextDecoration.lineThrough : null,
                  fontFamily: mono ? 'monospace' : null,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
