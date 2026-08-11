import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../core/theme/app_theme.dart';
import 'attachment_panel.dart';
import 'format_toolbar.dart' show MarkdownFormat;

/// 消息内容类型
enum MessageContentType { text, markdown }

/// 输入面板展开状态
enum _InputPanel { none, emoji, attachment }

/// 底部输入区：
/// - 按钮变形（mic ↔ 发送）
/// - 内嵌表情面板
/// - 附件 Grid 面板
/// - Markdown 格式工具栏（长按发送切换）
/// - 输入框自适应扩展
class ChatInput extends StatefulWidget {
  final TextEditingController controller;
  final Function(String text, MessageContentType type) onSend;
  final VoidCallback? onImagePick;
  final VoidCallback? onCameraPick;
  final VoidCallback? onFilePick;
  final VoidCallback? onLocationPick;
  final VoidCallback? onVideoPick;
  final Function(int duration, String filePath)? onVoiceRecord;
  final VoidCallback? onCardSend;
  final VoidCallback? onAtMention;
  final bool isGroupChat;

  const ChatInput({
    super.key,
    required this.controller,
    required this.onSend,
    this.onImagePick,
    this.onCameraPick,
    this.onFilePick,
    this.onLocationPick,
    this.onVideoPick,
    this.onVoiceRecord,
    this.onCardSend,
    this.onAtMention,
    this.isGroupChat = false,
  });

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  late FocusNode _focusNode;
  bool _isMarkdownMode = false;
  bool _inputExpanded = false;
  _InputPanel _activePanel = _InputPanel.none;

  /// 避免每次按键 setState 重建整个组件树
  final ValueNotifier<bool> _hasTextNotifier = ValueNotifier<bool>(false);

  /// 语音录制状态
  Timer? _recordingTimer;
  String? _recordingPath;
  DateTime? _recordingStart;
  final AudioRecorder _recorder = AudioRecorder();

  /// 缓存的附件列表，避免每次 build 创建新对象
  late List<AttachmentItem> _cachedAttachmentItems;

  /// 常用 emoji 列表
  static const List<String> _commonEmojis = [
    '😀',
    '😃',
    '😄',
    '😁',
    '😆',
    '😅',
    '🤣',
    '😂',
    '🙂',
    '🙃',
    '😉',
    '😊',
    '😇',
    '🥰',
    '😍',
    '🤩',
    '😘',
    '😗',
    '😚',
    '😙',
    '🥲',
    '😋',
    '😛',
    '😜',
    '🤪',
    '😝',
    '🤑',
    '🤗',
    '🤭',
    '🤫',
    '🤔',
    '🤐',
    '🤨',
    '😐',
    '😑',
    '😶',
    '😏',
    '😒',
    '🙄',
    '😬',
    '😮',
    '😯',
    '😲',
    '😳',
    '🥺',
    '😦',
    '😧',
    '😨',
    '😰',
    '😥',
    '😢',
    '😭',
    '😱',
    '😖',
    '😣',
    '😞',
    '😓',
    '😩',
    '😫',
    '🥱',
    '😤',
    '😡',
    '😠',
    '🤬',
    '👍',
    '👎',
    '👏',
    '🙏',
    '💪',
    '❤️',
    '🔥',
    '⭐',
    '🎉',
    '🎊',
    '💯',
    '✅',
    '❌',
    '⚡',
    '🌟',
    '💫',
  ];

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.onKeyEvent = _handleKeyEvent;
    _focusNode.addListener(_onFocusChanged);
    widget.controller.addListener(_onTextChanged);
    _hasTextNotifier.value = widget.controller.text.trim().isNotEmpty;
    _initAttachmentItems();
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus && _activePanel != _InputPanel.none) {
      _closeAllPanels();
    }
  }

  void _initAttachmentItems() {
    _cachedAttachmentItems = [
      AttachmentItem(
        icon: Icons.photo_library_outlined,
        label: '相册',
        onTap: widget.onImagePick,
      ),
      AttachmentItem(
        icon: Icons.camera_alt_outlined,
        label: '拍照',
        onTap: widget.onCameraPick,
      ),
      AttachmentItem(
        icon: Icons.videocam_outlined,
        label: '视频',
        onTap: widget.onVideoPick,
      ),
      AttachmentItem(
        icon: Icons.location_on_outlined,
        label: '位置',
        onTap: widget.onLocationPick,
      ),
      AttachmentItem(
        icon: Icons.insert_drive_file_outlined,
        label: '文件',
        onTap: widget.onFilePick,
      ),
      AttachmentItem(
        icon: Icons.person_add_outlined,
        label: '名片',
        onTap: widget.onCardSend != null ? () => widget.onCardSend!() : null,
      ),
    ];
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key != LogicalKeyboardKey.enter &&
        key != LogicalKeyboardKey.numpadEnter) {
      return KeyEventResult.ignored;
    }
    if (HardwareKeyboard.instance.isShiftPressed) {
      return KeyEventResult.ignored;
    }
    _doSend();
    return KeyEventResult.handled;
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _focusNode.dispose();
    _recordingTimer?.cancel();
    _recorder.dispose();
    _hasTextNotifier.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final hasText = widget.controller.text.trim().isNotEmpty;
    if (_hasTextNotifier.value != hasText) {
      _hasTextNotifier.value = hasText;
    }
  }

  void _doSend() {
    final text = widget.controller.text.trim();
    if (text.isEmpty) return;
    widget.onSend(
      text,
      _isMarkdownMode ? MessageContentType.markdown : MessageContentType.text,
    );
  }

  // ==================== 面板管理 ====================

  void _togglePanel(_InputPanel panel) {
    setState(() {
      _activePanel = _activePanel == panel ? _InputPanel.none : panel;
    });
  }

  void _closeAllPanels() {
    setState(() => _activePanel = _InputPanel.none);
  }

  // ==================== Markdown 格式插入 ====================

  /// 在光标处插入/包裹 Markdown 标记
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

    // 插入后聚焦输入框
    _focusNode.requestFocus();
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

  // ==================== 语音录制 ====================

  void _startRecording([LongPressStartDetails? details]) async {
    final dir = await getTemporaryDirectory();
    _recordingPath =
        '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.aac';
    _recordingStart = DateTime.now();

    try {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        _recordingPath = null;
        _recordingStart = null;
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('没有录音权限')));
        }
        return;
      }
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: _recordingPath!,
      );
    } catch (_) {
      _recordingPath = null;
      _recordingStart = null;
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('录音启动失败')));
      }
      return;
    }

    _recordingTimer = Timer(const Duration(seconds: 60), () {
      _stopRecording();
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('录音中...松开发送'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _stopRecording([LongPressEndDetails? details]) async {
    _recordingTimer?.cancel();
    _recordingTimer = null;

    if (_recordingPath == null || _recordingStart == null) return;
    final path = await _recorder.stop() ?? _recordingPath;
    final duration = DateTime.now().difference(_recordingStart!).inSeconds;

    _recordingPath = null;
    _recordingStart = null;

    if (duration < 1) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('录音时间太短'),
            duration: Duration(seconds: 1),
          ),
        );
      }
      return;
    }

    if (path != null) {
      widget.onVoiceRecord?.call(duration, path);
    }
  }

  // ==================== Emoji 插入 ====================

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
    _focusNode.requestFocus();
  }

  // ==================== 附件列表 ====================

  List<AttachmentItem> get _attachmentItems => _cachedAttachmentItems;

  // ==================== 构建 ====================

  @override
  Widget build(BuildContext context) {
    // SafeArea 只在外层与屏幕边缘之间留间隙，内部组件无缝紧贴
    return SafeArea(
      top: false,
      bottom: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 6,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildInputRow(),
                const SizedBox(height: 8),
                _isMarkdownMode ? _buildFormatBar() : _buildToolbarRow(),
              ],
            ),
          ),
          if (_activePanel == _InputPanel.emoji) _buildEmojiPanel(),
          if (_activePanel == _InputPanel.attachment)
            AttachmentPanel(
              items: _attachmentItems,
              onItemTap: _closeAllPanels,
            ),
        ],
      ),
    );
  }

  /// 第二层：输入框行（全宽圆角、自适应高度）
  Widget _buildInputRow() {
    return TextField(
      controller: widget.controller,
      focusNode: _focusNode,
      minLines: 1,
      maxLines: _inputExpanded ? null : 5,
      textInputAction: TextInputAction.send,
      style: TextStyle(
        fontSize: 16,
        color: context.appColors.textPrimary,
        fontFamily: _isMarkdownMode ? 'monospace' : null,
      ),
      decoration: InputDecoration(
        hintText: _isMarkdownMode ? 'Markdown...' : '输入消息...',
        hintStyle: TextStyle(
          color: context.appColors.textSecondary,
          fontSize: 16,
        ),
        filled: true,
        fillColor: context.appColors.inputBackground,
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
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 10,
        ),
        suffixIcon: ValueListenableBuilder<bool>(
          valueListenable: _hasTextNotifier,
          builder: (_, hasText, __) {
            if (hasText) return const SizedBox(width: 32, height: 32);
            return IconButton(
              icon: Icon(
                _inputExpanded ? Icons.zoom_in_map : Icons.zoom_out_map,
                size: 18,
                color: context.appColors.textSecondary,
              ),
              onPressed: () => setState(() => _inputExpanded = !_inputExpanded),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            );
          },
        ),
        suffixIconConstraints: const BoxConstraints(
          minWidth: 32,
          minHeight: 32,
        ),
      ),
      onSubmitted: (_) => _doSend(),
    );
  }

  /// 第三层：工具栏行（飞书风格，图标均匀排列）
  Widget _buildToolbarRow() {
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          // 😊 表情
          _buildToolbarIcon(
            icon: _activePanel == _InputPanel.emoji
                ? Icons.emoji_emotions
                : Icons.emoji_emotions_outlined,
            tooltip: '表情',
            onTap: () => _togglePanel(_InputPanel.emoji),
          ),
          // @ 提及
          if (widget.isGroupChat)
            _buildToolbarIcon(
              icon: Icons.alternate_email,
              tooltip: '@ 提及',
              onTap: () => widget.onAtMention?.call(),
            ),
          // 🎤 语音（长按录音）
          _buildToolbarIcon(
            icon: Icons.mic_none,
            tooltip: '语音（长按录音）',
            onLongPressStart: _startRecording,
            onLongPressEnd: _stopRecording,
            onTap: () {
              _focusNode.requestFocus();
              _closeAllPanels();
            },
          ),
          // 🖼️ 相册
          _buildToolbarIcon(
            icon: Icons.photo_library_outlined,
            tooltip: '相册',
            onTap: widget.onImagePick ?? () {},
            enabled: widget.onImagePick != null,
          ),
          // Aa 格式
          _buildToolbarIcon(
            icon: Icons.text_fields,
            tooltip: _isMarkdownMode ? '关闭 Markdown' : 'Markdown 格式',
            active: _isMarkdownMode,
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() => _isMarkdownMode = !_isMarkdownMode);
              if (_isMarkdownMode) {
                _focusNode.requestFocus();
              }
            },
          ),
          // ➕ 更多
          _buildToolbarIcon(
            icon: _activePanel == _InputPanel.attachment
                ? Icons.add_circle
                : Icons.add_circle_outline,
            tooltip: '更多',
            onTap: () => _togglePanel(_InputPanel.attachment),
          ),
          const Spacer(),
          // ➡️ 发送
          _buildSendButton(),
        ],
      ),
    );
  }

  /// 第二层（Markdown 模式）：格式按钮栏，替换普通工具栏
  Widget _buildFormatBar() {
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          _formatBtn('B', '粗体', () => _handleFormat(MarkdownFormat.bold)),
          _formatBtn(
            'I',
            '斜体',
            () => _handleFormat(MarkdownFormat.italic),
            italic: true,
          ),
          _formatBtn(
            'S',
            '删除线',
            () => _handleFormat(MarkdownFormat.strikethrough),
            strikethrough: true,
          ),
          _formatBtn('H', '标题', () => _handleFormat(MarkdownFormat.heading)),
          _formatBtn(
            '<>',
            '行内代码',
            () => _handleFormat(MarkdownFormat.inlineCode),
            mono: true,
          ),
          _formatBtn('"', '引用', () => _handleFormat(MarkdownFormat.quote)),
          _formatBtn('•', '列表', () => _handleFormat(MarkdownFormat.bulletList)),
          _formatBtn('🔗', '链接', () => _handleFormat(MarkdownFormat.link)),
          const Spacer(),
          // 返回普通工具栏
          _buildToolbarIcon(
            icon: Icons.text_fields,
            tooltip: '关闭 Markdown',
            active: true,
            onTap: () => setState(() => _isMarkdownMode = false),
          ),
          _buildSendButton(),
        ],
      ),
    );
  }

  Widget _formatBtn(
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

  /// 工具栏图标按钮（飞书风格：24px 线性图标，等宽）
  Widget _buildToolbarIcon({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    bool enabled = true,
    bool active = false,
    void Function(LongPressStartDetails)? onLongPressStart,
    void Function(LongPressEndDetails)? onLongPressEnd,
  }) {
    final hasLongPress = onLongPressStart != null;
    final btn = Tooltip(
      message: tooltip,
      child: Semantics(
        label: tooltip,
        button: true,
        child: SizedBox(
          width: 44,
          height: 44,
          child: IconButton(
            icon: Icon(
              icon,
              size: 24,
              color: enabled
                  ? (active
                        ? context.appColors.primary
                        : context.appColors.textPrimary.withValues(alpha: 0.7))
                  : context.appColors.textSecondary.withValues(alpha: 0.3),
            ),
            onPressed: hasLongPress ? null : (enabled ? onTap : null),
            padding: EdgeInsets.zero,
          ),
        ),
      ),
    );
    if (hasLongPress) {
      return GestureDetector(
        onTap: enabled ? onTap : null,
        onLongPressStart: onLongPressStart,
        onLongPressEnd: onLongPressEnd,
        child: btn,
      );
    }
    return btn;
  }

  /// 发送按钮（工具栏最右侧），只随 _hasText 变化重建
  Widget _buildSendButton() {
    return ValueListenableBuilder<bool>(
      valueListenable: _hasTextNotifier,
      builder: (_, hasText, __) {
        final enabled = hasText;
        return GestureDetector(
          onTap: enabled ? _doSend : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: enabled
                  ? (_isMarkdownMode
                        ? context.appColors.textSecondary
                        : context.appColors.primary)
                  : context.appColors.background,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Icon(
              Icons.arrow_forward,
              size: 22,
              color: enabled ? Colors.white : context.appColors.textSecondary,
            ),
          ),
        );
      },
    );
  }

  // ==================== 表情面板（飞书风格：最常使用 + 默认表情） ====================

  Widget _buildEmojiPanel() {
    const recentCount = 16;
    final recentEmojis = _commonEmojis.take(recentCount).toList();
    final defaultEmojis = _commonEmojis.skip(recentCount).toList();

    return Container(
      constraints: const BoxConstraints(maxHeight: 260),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: context.appColors.divider, width: 0.5),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '最常使用',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.appColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _buildEmojiGrid(recentEmojis),
                  const SizedBox(height: 8),
                  Text(
                    '默认表情',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.appColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _buildEmojiGrid(defaultEmojis),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          SizedBox(
            height: 40,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Icon(
                  Icons.add,
                  size: 20,
                  color: context.appColors.textSecondary,
                ),
                Icon(
                  Icons.emoji_emotions_outlined,
                  size: 20,
                  color: context.appColors.primary,
                ),
                Icon(
                  Icons.favorite_border,
                  size: 20,
                  color: context.appColors.textSecondary,
                ),
                IconButton(
                  icon: Icon(
                    Icons.keyboard,
                    size: 20,
                    color: context.appColors.textSecondary,
                  ),
                  onPressed: () {
                    _closeAllPanels();
                    _focusNode.requestFocus();
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmojiGrid(List<String> emojis) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 8,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
      ),
      itemCount: emojis.length,
      itemBuilder: (_, i) => InkWell(
        onTap: () => _insertEmoji(emojis[i]),
        child: Center(
          child: Text(emojis[i], style: const TextStyle(fontSize: 22)),
        ),
      ),
    );
  }

  // ==================== 辅助 ====================
}
