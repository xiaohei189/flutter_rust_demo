import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../message_content_type.dart';
import 'attachment_panel.dart';
import 'chat_action_toolbar.dart' show SendButton;
import 'emoji_panel.dart';
import 'format_toolbar.dart' show MarkdownFormat;
import 'input_toolbar_icon.dart';
import 'markdown_format_bar.dart';

/// 展开编辑抽屉（飞书式）：全宽大编辑区，用于长文 / Markdown 输入。
///
/// - 底部与主输入框共用同一套完整工具栏 [ChatActionToolbar]（含表情/更多面板）、
///   「发送」按钮直接发送并缩回抽屉
/// - Aa 在底部工具栏中切换 Markdown 模式
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
    this.sendToLabel = '发送消息',
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

  /// 输入区占位文案（飞书稿为「发送给 XXX」）
  final String sendToLabel;

  @override
  State<MessageComposerSheet> createState() => _MessageComposerSheetState();
}

/// 表情/附件面板互斥展开
enum _Panel { none, emoji, attachment }

class _MessageComposerSheetState extends State<MessageComposerSheet> {
  /// 是否 Markdown 模式（底部工具栏 Aa 切换，Markdown 时显示格式栏）
  bool _isMarkdownMode = false;

  _Panel _activePanel = _Panel.none;

  /// 面板按需构建（与主输入框同一标准）：从未打开过就不创建，
  /// 打开过一次后常驻树中（Offstage 保状态）并复用同一 widget 实例，
  /// 父级重建时 Flutter 直接复用 Element、不重建子树。
  late final Widget _emojiPanel = EmojiPanel(
    onEmojiSelected: _insertEmoji,
    onGifSelected: widget.onGifSelected,
  );
  late final Widget _attachmentPanel = AttachmentPanel(
    items: widget.attachmentItems,
    onItemTap: _closeAllPanels,
  );
  bool _emojiPanelOpened = false;
  bool _attachmentPanelOpened = false;

  /// 抽屉高度占屏幕比例（拖拽把手可调整 0.3~0.95）
  double _heightFactor = 0.85;

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
    final opening = _activePanel != panel;
    setState(() {
      _activePanel = opening ? panel : _Panel.none;
      if (opening) {
        if (panel == _Panel.emoji) _emojiPanelOpened = true;
        if (panel == _Panel.attachment) _attachmentPanelOpened = true;
      }
    });
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

  /// 底部操作行（对齐飞书稿）：😊 @ 🖼 📄 Aa ——右侧固定纸飞机发送。
  Widget _buildActionRow(AppColors colors) {
    final emojiActive = _activePanel == _Panel.emoji;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          for (final icon in <Widget>[
            InputToolbarIcon(
              icon: emojiActive
                  ? Icons.emoji_emotions
                  : Icons.emoji_emotions_outlined,
              tooltip: '表情',
              active: emojiActive,
              onTap: () => _togglePanel(_Panel.emoji),
            ),
            InputToolbarIcon(
              icon: Icons.alternate_email,
              tooltip: '@ 提及',
              onTap: widget.onAtMention ?? () {},
            ),
            InputToolbarIcon(
              icon: Icons.image_outlined,
              tooltip: '相册',
              enabled: widget.onImagePick != null,
              onTap: widget.onImagePick ?? () {},
            ),
            InputToolbarIcon(
              icon: Icons.upload_file_outlined,
              tooltip: '文件',
              onTap: () => _togglePanel(_Panel.attachment),
            ),
            Tooltip(
              message: 'Markdown 格式',
              child: Semantics(
                label: 'Aa',
                button: true,
                child: InkResponse(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() => _isMarkdownMode = !_isMarkdownMode);
                    _closeAllPanels();
                  },
                  radius: 20,
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: Center(
                      child: Text(
                        'Aa',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ])
            Expanded(child: Center(child: icon)),
          const SizedBox(width: 4),
          ValueListenableBuilder<bool>(
            valueListenable: widget.hasText,
            builder: (_, hasText, __) => Tooltip(
              message: '发送',
              child: Semantics(
                label: '发送',
                button: true,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 44,
                    height: 36,
                  ),
                  onPressed: hasText ? _send : null,
                  icon: Icon(
                    Icons.send_outlined,
                    size: 26,
                    color: hasText
                        ? colors.primary
                        : colors.textSecondary.withValues(alpha: 0.4),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

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

  // ==================== 构建 ====================

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final mediaQuery = MediaQuery.of(context);
    // 可用高度 = 屏幕高度 - 顶部安全区 - 键盘占位，
    // 保证抽屉顶部始终在状态栏下方（把手/缩回按钮可正常选中）
    final availableHeight =
        mediaQuery.size.height -
        mediaQuery.padding.top -
        mediaQuery.viewInsets.bottom;
    return Padding(
      // 键盘弹出时整体抬起
      padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
      child: SizedBox(
        height: availableHeight * _heightFactor,
        child: Column(
          children: [
            // 头部：标题 + 缩回（对齐飞书稿）。整行仍可拖动调整高度，
            // 避免默认 BottomSheet 整体拖动导致工具栏消失。
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onVerticalDragUpdate: (details) {
                final availableHeight =
                    MediaQuery.of(context).size.height -
                    MediaQuery.of(context).padding.top -
                    MediaQuery.of(context).viewInsets.bottom;
                final next = _heightFactor - details.delta.dy / availableHeight;
                if (next <= 0.50) {
                  // 缩小到阈值以下：自动退出到单行编辑（关闭抽屉）
                  Navigator.of(context).pop();
                  return;
                }
                setState(() {
                  _heightFactor = next.clamp(0.35, 0.95);
                });
              },
              child: Container(
                width: double.infinity,
                height: 44,
                padding: const EdgeInsets.only(left: 16, right: 4),
                child: Row(
                  children: [
                    Text(
                      '无标题',
                      style: TextStyle(fontSize: 17, color: colors.textSecondary),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(
                        Icons.close_fullscreen,
                        size: 20,
                        color: colors.textSecondary,
                      ),
                      tooltip: '缩回',
                      onPressed: () => Navigator.of(context).pop(),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
            ),
            // 编辑区（缩回按钮已移到顶部标题行）
            Expanded(
              child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                      child: TextField(
                        controller: widget.controller,
                        autofocus: true,
                        // expands 填满抽屉剩余高度（minLines/maxLines 需为 null）
                        expands: true,
                        // expands 时默认垂直居中，显式顶部对齐避免首行距顶部大片空白
                        textAlignVertical: TextAlignVertical.top,
                        minLines: null,
                        maxLines: null,
                        maxLength: 4000,
                        buildCounter:
                            (
                              _, {
                              required currentLength,
                              required isFocused,
                              int? maxLength,
                            }) => const SizedBox.shrink(),
                        style: TextStyle(
                          fontSize: 16,
                          color: colors.textPrimary,
                          fontFamily: _isMarkdownMode ? 'monospace' : null,
                        ),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: colors.surface,
                          hintText: widget.sendToLabel,
                          hintStyle: TextStyle(
                            fontSize: 16,
                            color: colors.textSecondary,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
              ),
            ),
            // 底部工具栏：Markdown 模式切换为格式栏
            if (_isMarkdownMode)
              MarkdownFormatBar(
                onFormat: _handleFormat,
                onClose: () {
                  setState(() => _isMarkdownMode = false);
                  _closeAllPanels();
                },
                trailing: ValueListenableBuilder<bool>(
                  valueListenable: widget.hasText,
                  builder: (_, hasText, __) {
                    return SendButton(enabled: hasText, onSend: _send);
                  },
                ),
              )
            else
              _buildActionRow(colors),
            // 表情/附件面板（互斥展开，与主输入框一致）
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_emojiPanelOpened)
                    Offstage(
                      offstage: _activePanel != _Panel.emoji,
                      child: _emojiPanel,
                    ),
                  if (_attachmentPanelOpened)
                    Offstage(
                      offstage: _activePanel != _Panel.attachment,
                      child: _attachmentPanel,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
