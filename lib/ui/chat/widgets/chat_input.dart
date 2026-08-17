import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../../domain/models/group_member.dart';
import '../../core/theme/app_theme.dart';
import '../../previews/app_theme_preview.dart';
import '../../core/widgets/app_image.dart';
import 'attachment_panel.dart';
import 'chat_action_toolbar.dart';
import 'emoji_panel.dart';
import 'format_toolbar.dart' show MarkdownFormat;
import 'markdown_format_bar.dart';
import 'message_composer_sheet.dart';
import 'message_content_type.dart';

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
  bool _isMarkdownMode = false;
  _InputPanel _activePanel = _InputPanel.none;

  /// 实时 @ 查询关键字（非 null 且输入框含 '@' 时显示成员列表）
  String? _atKeyword;

  /// @ 成员列表当前高亮项（桌面端 ↑/↓ 键导航）
  int _atSelectionIndex = 0;

  /// 聚焦或面板展开时保持完整输入布局，避免打开面板后工具栏被折叠行替换。
  bool get _isInputExpanded =>
      _focusNode.hasFocus || _activePanel != _InputPanel.none;

  /// 避免每次按键 setState 重建整个组件树
  final ValueNotifier<bool> _hasTextNotifier = ValueNotifier<bool>(false);

  /// 语音录制状态
  Timer? _recordingTimer;
  String? _recordingPath;
  DateTime? _recordingStart;
  final AudioRecorder _recorder = AudioRecorder();

  /// 录音手势状态（横滑/上滑取消）
  bool _isRecording = false;
  bool _recordingCancel = false;
  double _recordingStartDy = 0;

  /// 缓存的附件列表，避免每次 build 创建新对象
  late List<AttachmentItem> _cachedAttachmentItems;

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
    // 微信式互斥：面板展开时点击输入框 → 收面板、弹键盘；
    // 失焦（如点击消息区）只收键盘，面板保持展开。
    if (_focusNode.hasFocus && _activePanel != _InputPanel.none) {
      _closeAllPanels();
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
    if (_atKeyword != null && _filteredAtMembers.isNotEmpty) {
      if (key == LogicalKeyboardKey.arrowDown) {
        setState(() {
          _atSelectionIndex =
              (_atSelectionIndex + 1) % _filteredAtMembers.length;
        });
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowUp) {
        setState(() {
          _atSelectionIndex = (_atSelectionIndex - 1 +
                  _filteredAtMembers.length) %
              _filteredAtMembers.length;
        });
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.escape) {
        _setAtQuery(null);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.enter ||
          key == LogicalKeyboardKey.numpadEnter) {
        if (!HardwareKeyboard.instance.isShiftPressed) {
          final members = _filteredAtMembers;
          final index = _atSelectionIndex % members.length;
          _selectAtMember(members[index]);
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
    _recordingTimer?.cancel();
    _recorder.dispose();
    _hasTextNotifier.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final text = widget.controller.text;
    final hasText = text.trim().isNotEmpty;
    if (_hasTextNotifier.value != hasText) {
      _hasTextNotifier.value = hasText;
    }
    _updateAtQuery(text);
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

  /// 面板与键盘互斥切换（微信式）：
  /// - 键盘态点面板按钮 → 收键盘、展开面板
  /// - 面板态再点同一按钮 → 收面板、弹键盘
  void _togglePanel(_InputPanel panel) {
    final opening = _activePanel != panel;
    setState(() => _activePanel = opening ? panel : _InputPanel.none);
    if (opening) {
      FocusScope.of(context).unfocus();
    } else {
      _focusNode.requestFocus();
    }
  }

  void _closeAllPanels() {
    setState(() => _activePanel = _InputPanel.none);
  }

  /// 打开"展开编辑"抽屉（飞书式半屏大编辑区）。
  /// 与输入框共享同一个 controller，草稿天然同步；只编辑不发送，关闭后回主界面发送。
  void _openComposerSheet() {
    _closeAllPanels();
    FocusScope.of(context).unfocus(); // 收起键盘，给抽屉让位
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
        hasText: _hasTextNotifier,
        onSend: widget.onSend,
        onImagePick: widget.onImagePick,
        onAtMention: widget.onAtMention,
        onGifSelected: widget.onGifSelected,
        attachmentItems: _attachmentItems,
      ),
    );
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

    // 键盘态下插入后保持焦点；面板展开时聚焦会打断面板操作
    if (_activePanel == _InputPanel.none) {
      _focusNode.requestFocus();
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
    setState(() {
      _isRecording = true;
      _recordingCancel = false;
      _recordingStartDy = details?.globalPosition.dy ?? 0;
    });
    final dir = await getTemporaryDirectory();
    _recordingPath =
        '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.aac';
    _recordingStart = DateTime.now();

    try {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        _recordingPath = null;
        _recordingStart = null;
        setState(() => _isRecording = false);
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
      setState(() => _isRecording = false);
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
  }

  /// 录音手势移动：上滑超过 60px 进入取消态（业界"上滑取消"）
  void _onRecordingMove(LongPressMoveUpdateDetails details) {
    final cancel = details.globalPosition.dy < _recordingStartDy - 60;
    if (cancel != _recordingCancel) {
      setState(() => _recordingCancel = cancel);
    }
  }

  Future<void> _stopRecording([LongPressEndDetails? details]) async {
    _recordingTimer?.cancel();
    _recordingTimer = null;
    setState(() => _isRecording = false);

    if (_recordingPath == null || _recordingStart == null) return;

    // 横滑/上滑取消：先停止录音（否则麦克风会一直占用），再丢弃文件
    if (_recordingCancel) {
      final path = _recordingPath;
      _recordingPath = null;
      _recordingStart = null;
      try {
        await _recorder.stop();
      } catch (_) {
        // 停止失败也要继续清理文件
      }
      if (path != null) {
        try {
          await File(path).delete();
        } catch (_) {
          // 删除临时文件失败可忽略
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('已取消录音'),
            duration: Duration(milliseconds: 800),
          ),
        );
      }
      return;
    }

    final path = await _recorder.stop() ?? _recordingPath;
    final duration = DateTime.now().difference(_recordingStart!).inSeconds;

    _recordingPath = null;
    _recordingStart = null;

    if (duration < 1) {
      // 过短录音不发送，清理临时文件
      if (path != null) {
        try {
          await File(path).delete();
        } catch (_) {
          // 删除临时文件失败可忽略
        }
      }
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

  /// 录音状态浮层：默认提示"上滑取消"，上滑后变"松手取消"
  Widget _buildRecordingOverlay() {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      color: colors.surface.withValues(alpha: 0.92),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _recordingCancel ? Icons.keyboard_arrow_up : Icons.mic,
            size: 18,
            color: _recordingCancel ? colors.danger : colors.primary,
          ),
          const SizedBox(width: 6),
          Text(
            _recordingCancel ? '松手取消' : '上滑取消',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: _recordingCancel ? colors.danger : colors.textPrimary,
            ),
          ),
        ],
      ),
    );
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
    // 面板态插入不弹键盘，保持连续选择；切回键盘用面板内"键盘"按钮
  }

  // ==================== 附件列表 ====================

  List<AttachmentItem> get _attachmentItems => _cachedAttachmentItems;

  // ==================== 实时 @（Telegram 式） ====================

  /// 根据输入内容更新 @ 查询状态：光标前存在 '@' 时激活成员列表
  void _updateAtQuery(String text) {
    if (!widget.isGroupChat ||
        widget.atMembers == null ||
        widget.atMembers!.isEmpty) {
      _setAtQuery(null);
      return;
    }
    final caret = widget.controller.selection.isValid
        ? widget.controller.selection.baseOffset
        : text.length;
    final searchFrom = caret > 0 ? caret - 1 : 0;
    final lastAt = text.lastIndexOf('@', searchFrom);
    if (lastAt < 0) {
      _setAtQuery(null);
      return;
    }
    final keyword = text.substring(lastAt + 1, caret).trim();
    _setAtQuery(keyword);
  }

  void _setAtQuery(String? keyword) {
    if (_atKeyword == keyword) return;
    setState(() {
      _atKeyword = keyword;
      _atSelectionIndex = 0;
    });
  }

  /// 按关键字过滤群成员（昵称 / ID 模糊匹配）
  List<GroupMember> get _filteredAtMembers {
    final keyword = _atKeyword;
    if (keyword == null) return const [];
    final members = widget.atMembers ?? const [];
    if (keyword.isEmpty) return members;
    final lower = keyword.toLowerCase();
    return members
        .where(
          (m) =>
              m.nickname.toLowerCase().contains(lower) ||
              m.userId.toLowerCase().contains(lower),
        )
        .toList();
  }

  /// 选择成员：替换 "@关键字" 为 "@昵称 "，并回调外部记录 atUserId
  void _selectAtMember(GroupMember member) {
    final controller = widget.controller;
    final text = controller.text;
    final caret = controller.selection.isValid
        ? controller.selection.baseOffset
        : text.length;
    final searchFrom = caret > 0 ? caret - 1 : 0;
    final lastAt = text.lastIndexOf('@', searchFrom);
    if (lastAt < 0) return;
    final displayName = member.nickname.isNotEmpty
        ? member.nickname
        : member.userId;
    final newText = '${text.substring(0, lastAt)}@$displayName ';
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
    widget.onAtMemberSelected?.call(member.userId);
    _setAtQuery(null);
    _focusNode.requestFocus();
  }

  /// 成员选择列表（输入框上方，随关键字过滤）
  Widget _buildAtMemberList() {
    final members = _filteredAtMembers;
    final colors = context.appColors;
    return Material(
      color: colors.surface,
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: colors.divider, width: 0.5),
          ),
        ),
        child: members.isEmpty
            ? Center(
                child: Text(
                  '无匹配成员',
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              )
            : ListView.builder(
                itemCount: members.length,
                itemBuilder: (_, i) {
                  final member = members[i];
                  return ListTile(
                    dense: true,
                    selected: i == _atSelectionIndex,
                    selectedTileColor: colors.surfaceMuted,
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: colors.surfaceMuted,
                      child: member.faceUrl.isNotEmpty
                          ? ClipOval(
                              child: AppImage(
                                source: member.faceUrl,
                                width: 32,
                                height: 32,
                                fit: BoxFit.cover,
                              ),
                            )
                          : Icon(
                              Icons.person,
                              size: 18,
                              color: colors.textSecondary,
                            ),
                    ),
                    title: Text(
                      member.nickname.isNotEmpty
                          ? member.nickname
                          : member.userId,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      member.userId,
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.textSecondary,
                      ),
                    ),
                    onTap: () => _selectAtMember(member),
                  );
                },
              ),
      ),
    );
  }

  // ==================== 构建 ====================

  @override
  Widget build(BuildContext context) {
    final isExpanded = _isInputExpanded;
    // SafeArea 只在外层与屏幕边缘之间留间隙，内部组件无缝紧贴
    return SafeArea(
      top: false,
      bottom: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isRecording) _buildRecordingOverlay(),
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
                // 聚焦/面板展开态：输入行 + 底部完整工具栏
                // 未聚焦态：默认一行（声音+输入框+表情+更多）
                if (isExpanded)
                  ...[
                    _buildInputRow(),
                    if (_atKeyword != null) _buildAtMemberList(),
                    const SizedBox(height: 8),
                    _isMarkdownMode ? _buildFormatBar() : _buildToolbarRow(),
                  ]
                else
                  _buildCollapsedRow(),
              ],
            ),
          ),
          // 两个面板常驻树中（Offstage 保状态），切换只动画高度，不重建不重读磁盘
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                  Offstage(
                    offstage: _activePanel != _InputPanel.emoji,
                    child: EmojiPanel(
                      onEmojiSelected: _insertEmoji,
                      onGifSelected: widget.onGifSelected,
                    ),
                  ),
                Offstage(
                  offstage: _activePanel != _InputPanel.attachment,
                  child: AttachmentPanel(
                    items: _attachmentItems,
                    onItemTap: _closeAllPanels,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 未聚焦默认态：一行 [🎤] [输入框] [😊] [➕]。
  /// 点击输入框聚焦后切换到“输入行 + 底部完整工具栏”。
  Widget _buildCollapsedRow() {
    return Row(
      children: [
        // 声音切换按钮（长按录音 / 点击聚焦弹键盘）
        _buildToolbarIcon(
          icon: Icons.mic_none,
          tooltip: '语音（长按录音，上滑取消）',
          onLongPressStart: _startRecording,
          onLongPressMoveUpdate: _onRecordingMove,
          onLongPressEnd: _stopRecording,
          onTap: () => _focusNode.requestFocus(),
        ),
        const SizedBox(width: 4),
        // 输入框占满剩余宽度
        Expanded(child: _buildInputRow()),
        // 表情（面板互斥展开）
        _buildToolbarIcon(
          icon: _activePanel == _InputPanel.emoji
              ? Icons.emoji_emotions
              : Icons.emoji_emotions_outlined,
          tooltip: '表情',
          onTap: () => _togglePanel(_InputPanel.emoji),
        ),
        // 更多（附件面板互斥展开）
        _buildToolbarIcon(
          icon: _activePanel == _InputPanel.attachment
              ? Icons.add_circle
              : Icons.add_circle_outline,
          tooltip: '更多',
          onTap: () => _togglePanel(_InputPanel.attachment),
        ),
      ],
    );
  }

  /// 第二层：输入框行（全宽圆角、自适应高度）
  Widget _buildInputRow() {
    return TextField(
      controller: widget.controller,
      focusNode: _focusNode,
      minLines: 1,
      // 自动增高：普通 1-8 行、Markdown 1-12 行，超出内部滚动；长文用 ⤢ 抽屉
      maxLines: _isMarkdownMode ? 12 : 8,
      // 对齐 OpenIM 服务端消息长度限制
      maxLength: 4000,
      buildCounter:
          (_, {required currentLength, required isFocused, int? maxLength}) =>
              const SizedBox.shrink(),
      textInputAction: TextInputAction.send,
      style: TextStyle(
        fontSize: 16,
        color: context.appColors.textPrimary,
        fontFamily: _isMarkdownMode ? 'monospace' : null,
      ),
      decoration: InputDecoration(
        hintText: '输入消息...',
        hintStyle: TextStyle(
          color: context.appColors.textSecondary,
          fontSize: 16,
        ),
        filled: true,
        // 与抽屉/卡片统一为 surface（浅色纯白、深色深灰）
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
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 10,
        ),
        // 飞书式展开：点击打开半屏大编辑抽屉（长文 / Markdown）
        suffixIcon: IconButton(
          icon: const Icon(Icons.open_in_full, size: 18),
          tooltip: '展开编辑',
          onPressed: _openComposerSheet,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
        suffixIconConstraints: const BoxConstraints(
          minWidth: 32,
          minHeight: 32,
        ),
      ),
      // 点击发送/工具栏按钮时保持输入焦点，避免 TapRegion 先收起工具栏吞掉点击。
      onTapOutside: (_) {},
      onSubmitted: (_) => _doSend(),
    );
  }

  /// 第三层：工具栏行（与展开抽屉共用 [ChatActionToolbar]）。
  Widget _buildToolbarRow() {
    return ChatActionToolbar(
      emojiActive: _activePanel == _InputPanel.emoji,
      moreActive: _activePanel == _InputPanel.attachment,
      markdownActive: _isMarkdownMode,
      markdownTooltip: _isMarkdownMode ? '关闭 Markdown' : 'Markdown 格式',
      hasText: _hasTextNotifier,
      // 😊
      onEmoji: () => _togglePanel(_InputPanel.emoji),
      // @ 提及
      onAt: () => widget.onAtMention?.call(),
      // 🎤 语音（长按录音，上滑取消）
      onVoiceLongPressStart: _startRecording,
      onVoiceLongPressMoveUpdate: _onRecordingMove,
      onVoiceLongPressEnd: _stopRecording,
      onVoiceTap: () => _focusNode.requestFocus(), // 聚焦自动收起面板
      // 🖼️ 相册
      onImage: widget.onImagePick ?? () {},
      imageEnabled: widget.onImagePick != null,
      // Aa 格式
      onFormat: () {
        HapticFeedback.lightImpact();
        final enteringMarkdown = !_isMarkdownMode;
        setState(() {
          _isMarkdownMode = enteringMarkdown;
          // 进入 Markdown 模式时收起面板，避免面板+格式栏同屏
          if (enteringMarkdown) _activePanel = _InputPanel.none;
        });
        if (enteringMarkdown) _focusNode.requestFocus();
      },
      // ➕ 更多
      onMore: () => _togglePanel(_InputPanel.attachment),
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
        setState(() => _isMarkdownMode = false);
        _focusNode.requestFocus();
      },
      trailing: ValueListenableBuilder<bool>(
        valueListenable: _hasTextNotifier,
        builder: (_, hasText, __) {
          return SendButton(enabled: hasText, onSend: _doSend);
        },
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
    void Function(LongPressMoveUpdateDetails)? onLongPressMoveUpdate,
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
        onLongPressMoveUpdate: onLongPressMoveUpdate,
        onLongPressEnd: onLongPressEnd,
        child: btn,
      );
    }
    return btn;
  }

  // ==================== 辅助 ====================
}

// ==================== 预览 ====================

/// 预览宿主：持有并管理输入框 controller，保证可交互、可输入、可展开面板。
class _ChatInputPreviewHost extends StatefulWidget {
  final bool isGroupChat;

  const _ChatInputPreviewHost({this.isGroupChat = false});

  @override
  State<_ChatInputPreviewHost> createState() => _ChatInputPreviewHostState();
}

class _ChatInputPreviewHostState extends State<_ChatInputPreviewHost> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ChatInput(
          controller: _controller,
          onSend: (_, __) {},
          isGroupChat: widget.isGroupChat,
          onImagePick: () {},
          onImagesPick: () {},
          onCameraPick: () {},
          onFilePick: () {},
          onLocationPick: () {},
        ),
      ),
    );
  }
}

@AppThemePreview(name: '单聊 - 默认', group: 'ChatInput')
Widget chatInputSinglePreview() => const _ChatInputPreviewHost();

@AppThemePreview(name: '群聊 - 带 @ 按钮', group: 'ChatInput')
Widget chatInputGroupPreview() =>
    const _ChatInputPreviewHost(isGroupChat: true);
