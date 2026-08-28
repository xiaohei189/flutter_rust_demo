import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../domain/models/group_member.dart';
import '../../../core/theme/app_theme.dart';
import 'attachment_panel.dart';
import 'chat_action_toolbar.dart';
import 'chat_composer_controller.dart';
import 'input_toolbar_icon.dart';
import 'voice_recorder_controller.dart';
import 'emoji_panel.dart';
import 'format_toolbar.dart' show MarkdownFormat;
import 'chat_input_field.dart';
import 'markdown_format_bar.dart';
import 'message_composer_sheet.dart';
import 'at_member_suggestions.dart';
import 'recording_overlay.dart';
import '../message_content_type.dart';

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
  final VoidCallback? onImagesPick;
  final VoidCallback? onCameraPick;
  final VoidCallback? onFilePick;
  final VoidCallback? onLocationPick;
  final VoidCallback? onVideoPick;
  final Function(int duration, String filePath)? onVoiceRecord;
  final VoidCallback? onCardSend;
  final VoidCallback? onAtMention;
  final ValueChanged<String>? onGifSelected;
  final List<GroupMember>? atMembers;
  final ValueChanged<String>? onAtMemberSelected;
  final bool isGroupChat;

  const ChatInput({
    super.key,
    required this.controller,
    required this.onSend,
    this.onImagePick,
    this.onImagesPick,
    this.onCameraPick,
    this.onFilePick,
    this.onLocationPick,
    this.onVideoPick,
    this.onVoiceRecord,
    this.onCardSend,
    this.onAtMention,
    this.onGifSelected,
    this.atMembers,
    this.onAtMemberSelected,
    this.isGroupChat = false,
  });

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  late FocusNode _focusNode;
  late final ChatComposerController _composer;

  /// 聚焦或面板展开时保持完整输入布局，避免打开面板后工具栏被折叠行替换。
  bool get _isInputExpanded => _focusNode.hasFocus || _composer.hasActivePanel;

  /// 语音录制状态（权限、临时文件、上滑取消、60s 上限）
  late final VoiceRecorderController _voiceRecorder;

  /// 缓存的附件列表，避免每次 build 创建新对象
  late List<AttachmentItem> _cachedAttachmentItems;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.onKeyEvent = _handleKeyEvent;
    _focusNode.addListener(_onFocusChanged);
    widget.controller.addListener(_onTextChanged);
    _composer = ChatComposerController(
      onAtMemberSelected: widget.onAtMemberSelected,
    )..addListener(_onComposerChanged);
    _composer.updateText(
      widget.controller.text,
      widget.controller.selection,
      isGroupChat: widget.isGroupChat,
      atMembers: widget.atMembers,
    );
    _initAttachmentItems();
    _voiceRecorder = VoiceRecorderController(
      onVoiceRecord: widget.onVoiceRecord,
    )..addListener(_onRecordingChanged);
  }

  void _onFocusChanged() {
    // 微信式互斥：面板展开时点击输入框 → 收面板、弹键盘；
    // 失焦（如点击消息区）只收键盘，面板保持展开。
    if (_focusNode.hasFocus && _composer.hasActivePanel) {
      _composer.closePanels();
    }
    // 焦点变化会切换“默认一行（声音+输入框+表情+更多）”与
    // “聚焦态（输入行+底部完整工具栏）”两种布局，刷新 build
    if (mounted) setState(() {});
  }

  void _initAttachmentItems() {
    _cachedAttachmentItems = [
      AttachmentItem(
        icon: Icons.photo_library_outlined,
        label: '相册',
        onTap: widget.onImagesPick ?? widget.onImagePick,
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

    // @ 成员列表激活时：↑/↓ 切换高亮、Enter 确认、Esc 关闭
    if (_composer.atKeyword != null && _filteredAtMembers.isNotEmpty) {
      if (key == LogicalKeyboardKey.arrowDown) {
        _composer.moveAtSelection(1, _filteredAtMembers.length);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowUp) {
        _composer.moveAtSelection(-1, _filteredAtMembers.length);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.escape) {
        _composer.setAtKeyword(null);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.enter ||
          key == LogicalKeyboardKey.numpadEnter) {
        if (!HardwareKeyboard.instance.isShiftPressed) {
          final members = _filteredAtMembers;
          final index = _composer.atMemberQuery.normalizedIndex(
            _composer.atSelectionIndex,
            members.length,
          );
          _composer.selectAtMember(widget.controller, members[index]);
          _focusNode.requestFocus();
          return KeyEventResult.handled;
        }
      }
    }

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
    _voiceRecorder.removeListener(_onRecordingChanged);
    _voiceRecorder.dispose();
    _composer.removeListener(_onComposerChanged);
    _composer.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    _composer.updateText(
      widget.controller.text,
      widget.controller.selection,
      isGroupChat: widget.isGroupChat,
      atMembers: widget.atMembers,
    );
  }

  void _onComposerChanged() {
    if (mounted) setState(() {});
  }

  void _onRecordingChanged() {
    if (mounted) setState(() {});
  }

  void _doSend() {
    _composer.sendText(widget.controller, onSend: widget.onSend);
  }

  // ==================== 面板管理 ====================

  /// 面板与键盘互斥切换（微信式）：
  /// - 键盘态点面板按钮 → 收键盘、展开面板
  /// - 面板态再点同一按钮 → 收面板、弹键盘
  void _togglePanel(ComposerPanel panel) {
    final opening = _composer.activePanel != panel;
    _composer.togglePanel(panel);
    if (opening) {
      FocusScope.of(context).unfocus();
    } else {
      _focusNode.requestFocus();
    }
  }

  void _closeAllPanels() {
    _composer.closePanels();
  }

  /// 打开"展开编辑"抽屉（飞书式半屏大编辑区）。
  /// 与输入框共享同一个 controller，草稿天然同步；只编辑不发送，关闭后回主界面发送。
  void _openComposerSheet() {
    _closeAllPanels();
    // 不主动收键盘：抽屉内输入框 autofocus 会接管焦点，键盘保持连续，
    // 避免“先收起键盘、抽屉弹出后再弹键盘”导致的键盘翻动。
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      // 覆盖 M3 BottomSheet 默认 maxWidth 640，抽屉全宽
      constraints: const BoxConstraints(maxWidth: double.infinity),
      // surface 随深浅色主题变化（onPrimary 恒为白，不能当背景用）
      backgroundColor: context.appColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => MessageComposerSheet(
        controller: widget.controller,
        hasText: _composer.hasText,
        onSend: widget.onSend,
        onImagePick: widget.onImagePick,
        onAtMention: widget.onAtMention,
        onGifSelected: widget.onGifSelected,
        attachmentItems: _attachmentItems,
      ),
    );
  }

  // ==================== Markdown 格式插入 ====================

  void _handleFormat(MarkdownFormat format) {
    _composer.handleFormat(
      widget.controller,
      format,
      onRequestFocus: () => _focusNode.requestFocus(),
    );
  }

  // ==================== Emoji 插入 ====================

  void _insertEmoji(String emoji) {
    _composer.insertEmoji(widget.controller, emoji);
    // 面板态插入不弹键盘，保持连续选择；切回键盘用面板内"键盘"按钮
  }

  // ==================== 附件列表 ====================

  List<AttachmentItem> get _attachmentItems => _cachedAttachmentItems;

  // ==================== 实时 @（Telegram 式） ====================

  /// 按关键字过滤群成员（昵称 / ID 模糊匹配）
  List<GroupMember> get _filteredAtMembers => _composer.atMemberQuery.filter(
    _composer.atKeyword,
    widget.atMembers ?? const [],
  );

  /// 成员选择列表（输入框上方，随关键字过滤）
  Widget _buildAtMemberList() => AtMemberSuggestions(
    members: _filteredAtMembers,
    selectedIndex: _composer.atSelectionIndex,
    onSelect: (member) {
      _composer.selectAtMember(widget.controller, member);
      _focusNode.requestFocus();
    },
  );

  // ==================== 构建 ====================

  @override
  Widget build(BuildContext context) {
    final isExpanded = _isInputExpanded;
    final emojiActive = _composer.activePanel == ComposerPanel.emoji;
    final moreActive = _composer.activePanel == ComposerPanel.attachment;
    // SafeArea 只在外层与屏幕边缘之间留间隙，内部组件无缝紧贴
    return SafeArea(
      top: false,
      bottom: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_voiceRecorder.isRecording)
            RecordingOverlay(cancel: _voiceRecorder.recordingCancel),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            decoration: BoxDecoration(
              color: context.appColors.onPrimary,
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
              // 子项撑满宽度，避免工具栏/面板被默认居中
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 输入行结构恒定：🎤 + 输入框 + 😊 + ➕。
                // 折叠/展开只切换行内图标的显隐（Visibility 保留 Element）与底部工具栏，
                // 输入框始终是同一个 Element，避免同帧替换 TextField 导致 IME 连接丢失（首次点击键盘不弹出）。
                Row(
                  children: [
                    Visibility(
                      visible: !isExpanded,
                      maintainState: true,
                      child: InputToolbarIcon(
                        icon: Icons.mic_none,
                        tooltip: '语音（长按录音，上滑取消）',
                        onTap: () => _focusNode.requestFocus(),
                        onLongPressStart: (details) =>
                            _voiceRecorder.start(context, details),
                        onLongPressMoveUpdate: _voiceRecorder.onMove,
                        onLongPressEnd: (details) =>
                            _voiceRecorder.stop(context, details),
                      ),
                    ),
                    Expanded(child: _buildInputRow()),
                    Visibility(
                      visible: !isExpanded,
                      maintainState: true,
                      child: InputToolbarIcon(
                        icon: emojiActive
                            ? Icons.emoji_emotions
                            : Icons.emoji_emotions_outlined,
                        tooltip: '表情',
                        onTap: () => _togglePanel(ComposerPanel.emoji),
                      ),
                    ),
                    Visibility(
                      visible: !isExpanded,
                      maintainState: true,
                      child: InputToolbarIcon(
                        icon: moreActive
                            ? Icons.add_circle
                            : Icons.add_circle_outline,
                        tooltip: '更多',
                        onTap: () => _togglePanel(ComposerPanel.attachment),
                      ),
                    ),
                  ],
                ),
                if (isExpanded) ...[
                  if (_composer.atKeyword != null) _buildAtMemberList(),
                  const SizedBox(height: 8),
                  _composer.isMarkdownMode
                      ? _buildFormatBar()
                      : _buildToolbarRow(),
                ],
              ],
            ),
          ),
          // 两个面板常驻树中（Offstage 保状态），切换只动画高度，不重建不重读磁盘。
          // Flexible 让面板在输入区高度受限（多行输入 + 面板超出可用高度）时自动收缩，避免 RenderFlex 溢出。
          Flexible(
            fit: FlexFit.loose,
            child: AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Offstage(
                    offstage: _composer.activePanel != ComposerPanel.emoji,
                    child: EmojiPanel(
                      onEmojiSelected: _insertEmoji,
                      onGifSelected: widget.onGifSelected,
                    ),
                  ),
                  Offstage(
                    offstage: _composer.activePanel != ComposerPanel.attachment,
                    child: AttachmentPanel(
                      items: _attachmentItems,
                      onItemTap: () => _composer.closePanels(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 第二层：输入框行（全宽圆角、自适应高度）
  Widget _buildInputRow() {
    return ChatInputField(
      controller: widget.controller,
      focusNode: _focusNode,
      isMarkdownMode: _composer.isMarkdownMode,
      onOpenComposer: _openComposerSheet,
      onSubmitted: _doSend,
    );
  }

  /// 第三层：工具栏行（与展开抽屉共用 [ChatActionToolbar]）。
  Widget _buildToolbarRow() {
    return ChatActionToolbar(
      emojiActive: _composer.activePanel == ComposerPanel.emoji,
      moreActive: _composer.activePanel == ComposerPanel.attachment,
      markdownActive: _composer.isMarkdownMode,
      markdownTooltip: _composer.isMarkdownMode ? '关闭 Markdown' : 'Markdown 格式',
      hasText: _composer.hasText,
      // 😊
      onEmoji: () => _togglePanel(ComposerPanel.emoji),
      // @ 提及
      onAt: () => widget.onAtMention?.call(),
      // 🎤 语音（长按录音，上滑取消）
      onVoiceLongPressStart: (details) =>
          _voiceRecorder.start(context, details),
      onVoiceLongPressMoveUpdate: _voiceRecorder.onMove,
      onVoiceLongPressEnd: (details) => _voiceRecorder.stop(context, details),
      onVoiceTap: () => _focusNode.requestFocus(), // 聚焦自动收起面板
      // 🖼️ 相册
      onImage: widget.onImagePick ?? () {},
      imageEnabled: widget.onImagePick != null,
      // Aa 格式
      onFormat: () {
        HapticFeedback.lightImpact();
        final enteringMarkdown = !_composer.isMarkdownMode;
        _composer.setMarkdownMode(enteringMarkdown);
        if (enteringMarkdown) {
          // 进入 Markdown 模式时收起面板，避免面板+格式栏同屏
          _composer.closePanels();
          _focusNode.requestFocus();
        }
      },
      // ➕ 更多
      onMore: () => _togglePanel(ComposerPanel.attachment),
      // ➡️ 发送
      onSend: _doSend,
    );
  }

  /// 第二层（Markdown 模式）：格式按钮栏，替换普通工具栏。
  /// 发送统一走普通工具栏：先点 ↩ 退出 Markdown，再点发送（右侧只留返回按钮）。
  /// 退出后聚焦输入框继续输入（与进入时对称）。
  Widget _buildFormatBar() {
    return MarkdownFormatBar(
      onFormat: _handleFormat,
      onClose: () {
        _composer.setMarkdownMode(false);
        _focusNode.requestFocus();
      },
      trailing: ValueListenableBuilder<bool>(
        valueListenable: _composer.hasText,
        builder: (_, hasText, __) {
          return SendButton(enabled: hasText, onSend: _doSend);
        },
      ),
    );
  }

  // ==================== 辅助 ====================
}
