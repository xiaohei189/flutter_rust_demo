import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../domain/models/group_member.dart';
import '../../../core/theme/app_theme.dart';
import '../message_content_type.dart';
import 'at_member_suggestions.dart';
import 'attachment_panel.dart';
import 'chat_composer_controller.dart';
import 'chat_input_field.dart';
import 'emoji_panel.dart';
import 'format_toolbar.dart' show MarkdownFormat;
import 'input_toolbar_icon.dart';
import 'markdown_format_bar.dart';
import 'message_composer_sheet.dart';
import 'recording_overlay.dart';
import 'voice_recorder_controller.dart';

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

  /// 语音录制状态（权限、临时文件、上滑取消、60s 上限）
  late final VoiceRecorderController _voiceRecorder;

  /// 缓存的附件列表，避免每次 build 创建新对象
  late List<AttachmentItem> _cachedAttachmentItems;

  /// 两个面板按需构建：从未打开过就不创建（进入会话不付面板的 build/layout 成本）；
  /// 打开过一次后常驻树中（Offstage 保状态），并且缓存 widget 实例——Flutter 在
  /// `child.widget == newWidget` 时直接复用 Element 不重建子树（Element.updateChild 快路径），
  /// 约束未变时 layout 也提前返回。因此「首次进入零成本 + 之后重建零成本 + 状态保留」。
  late final Widget _emojiPanel = EmojiPanel(
    onEmojiSelected: _insertEmoji,
    onGifSelected: widget.onGifSelected,
  );
  late final Widget _attachmentPanel = AttachmentPanel(
    items: _cachedAttachmentItems,
    onItemTap: () => _composer.closePanels(),
  );
  bool _emojiPanelOpened = false;
  bool _attachmentPanelOpened = false;

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
    // 颜色对齐飞书稿：文件/拍照橙、位置/相册/名片蓝、视频紫
    const blue = Color(0xFF3370FF);
    const orange = Color(0xFFFF8A00);
    const purple = Color(0xFF7F3BF5);
    _cachedAttachmentItems = [
      AttachmentItem(
        icon: Icons.photo_library_outlined,
        label: '相册',
        color: blue,
        onTap: widget.onImagesPick ?? widget.onImagePick,
      ),
      AttachmentItem(
        icon: Icons.camera_alt_outlined,
        label: '拍照',
        color: orange,
        onTap: widget.onCameraPick,
      ),
      AttachmentItem(
        icon: Icons.videocam_outlined,
        label: '视频',
        color: purple,
        onTap: widget.onVideoPick,
      ),
      AttachmentItem(
        icon: Icons.location_on_outlined,
        label: '位置',
        color: blue,
        onTap: widget.onLocationPick,
      ),
      AttachmentItem(
        icon: Icons.insert_drive_file_outlined,
        label: '文件',
        color: orange,
        onTap: widget.onFilePick,
      ),
      AttachmentItem(
        icon: Icons.person_add_outlined,
        label: '名片',
        color: blue,
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
    // 面板第一次被激活时才标记：build 里据此决定是否把面板放进树（按需构建）
    switch (_composer.activePanel) {
      case ComposerPanel.emoji:
        _emojiPanelOpened = true;
      case ComposerPanel.attachment:
        _attachmentPanelOpened = true;
      case ComposerPanel.none:
        break;
    }
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
    final wasFocused = _focusNode.hasFocus;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      // 高度由抽屉内拖拽把手自管理：enableDrag 会让整体拖动（工具栏被拖到键盘下）且松手自动回弹，
      // 改为把手拖动调整高度并保持，底部工具栏固定
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
    ).then((_) {
      // 缩回后恢复打开前的输入区状态：若打开前未聚焦（工具栏收起），
      // 则取消主输入框焦点，避免抽屉关闭后焦点回弹导致底部工具栏意外展开。
      if (mounted && !wasFocused && _focusNode.hasFocus) {
        _focusNode.unfocus();
      }
    });
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
            color: context.appColors.inputBackground,
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              // 子项撑满宽度，避免工具栏/面板被默认居中
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // @ 成员候选：贴在胶囊上方
                if (_composer.atKeyword != null) _buildAtMemberList(),
                // 输入胶囊：白底圆角，右侧内嵌「展开编辑」
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: _buildInputRow(),
                ),
                const SizedBox(height: 4),
                // Markdown 模式用格式栏替换操作行（避免出现两个发送按钮）
                if (_composer.isMarkdownMode)
                  _buildFormatBar()
                else
                  // 常驻操作行：😊 @ 🎤 🖼 Aa ⊕ ——右侧固定发送
                  _buildActionRow(emojiActive, moreActive),
                const SizedBox(height: 6),
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
                  if (_emojiPanelOpened)
                    Offstage(
                      offstage: _composer.activePanel != ComposerPanel.emoji,
                      child: _emojiPanel,
                    ),
                  if (_attachmentPanelOpened)
                    Offstage(
                      offstage:
                          _composer.activePanel != ComposerPanel.attachment,
                      child: _attachmentPanel,
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

  /// 常驻操作行（飞书稿）：😊 @ 🎤 🖼 Aa ⊕ 均匀分布，最右固定发送。
  /// 开关面板只改图标形态（蓝色/实心），行结构与输入框 Element 始终不变，
  /// 因此聚焦、切面板都不会替换 TextField（键盘不会闪）。
  Widget _buildActionRow(bool emojiActive, bool moreActive) {
    final colors = context.appColors;
    final imagePicker = widget.onImagesPick ?? widget.onImagePick;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          for (final icon in <Widget>[
            InputToolbarIcon(
              icon: emojiActive
                  ? Icons.emoji_emotions
                  : Icons.emoji_emotions_outlined,
              tooltip: '表情',
              active: emojiActive,
              onTap: () => _togglePanel(ComposerPanel.emoji),
            ),
            InputToolbarIcon(
              icon: Icons.alternate_email,
              tooltip: '@ 提及',
              onTap: () => widget.onAtMention?.call(),
            ),
            InputToolbarIcon(
              icon: Icons.mic_none,
              tooltip: '语音（长按录音，上滑取消）',
              onTap: () => _focusNode.requestFocus(),
              onLongPressStart: (details) =>
                  _voiceRecorder.start(context, details),
              onLongPressMoveUpdate: _voiceRecorder.onMove,
              onLongPressEnd: (details) =>
                  _voiceRecorder.stop(context, details),
            ),
            InputToolbarIcon(
              icon: Icons.image_outlined,
              tooltip: '相册',
              enabled: imagePicker != null,
              onTap: () => imagePicker?.call(),
            ),
            _buildMarkdownToggle(colors),
            InputToolbarIcon(
              icon: moreActive ? Icons.cancel : Icons.add_circle_outline,
              tooltip: moreActive ? '收起' : '更多',
              active: moreActive,
              onTap: () => _togglePanel(ComposerPanel.attachment),
            ),
          ])
            Expanded(child: Center(child: icon)),
          const SizedBox(width: 4),
          _buildSendButton(colors),
        ],
      ),
    );
  }

  /// Aa：Markdown 模式开关（激活时蓝色）
  Widget _buildMarkdownToggle(AppColors colors) {
    final active = _composer.isMarkdownMode;
    return Tooltip(
      message: active ? '关闭 Markdown' : 'Markdown 格式',
      child: Semantics(
        label: 'Aa',
        button: true,
        child: InkResponse(
          onTap: _toggleMarkdown,
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
                  color: active
                      ? colors.primary
                      : colors.textPrimary.withValues(alpha: 0.8),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 发送：纸飞机图标，无文字时置灰不可点
  Widget _buildSendButton(AppColors colors) {
    return ValueListenableBuilder<bool>(
      valueListenable: _composer.hasText,
      builder: (_, hasText, __) => Tooltip(
        message: '发送',
        child: Semantics(
          label: '发送',
          button: true,
          child: IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 44, height: 36),
            onPressed: hasText ? _doSend : null,
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
    );
  }

  /// Aa 点击：切换 Markdown 模式（进入时收起面板并聚焦）
  void _toggleMarkdown() {
    HapticFeedback.lightImpact();
    final enteringMarkdown = !_composer.isMarkdownMode;
    _composer.setMarkdownMode(enteringMarkdown);
    if (enteringMarkdown) {
      // 进入 Markdown 模式时收起面板，避免面板+格式栏同屏
      _composer.closePanels();
      _focusNode.requestFocus();
    }
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
        builder: (_, __, ___) => _buildSendButton(context.appColors),
      ),
    );
  }

  // ==================== 辅助 ====================
}
