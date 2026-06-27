import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../router/app_router.dart';
import '../theme/app_theme.dart';

/// 底部输入区：语音/文字切换、自适应输入框、表情、加号（无内容）/发送（有内容）
class ChatInput extends StatefulWidget {
  final TextEditingController controller;
  final Function(String) onSend;
  final Function(String)? onSendMarkdown;
  final VoidCallback? onImagePick;
  final VoidCallback? onCameraPick;
  final VoidCallback? onFilePick;
  final VoidCallback? onLocationPick;
  final VoidCallback? onVideoPick;
  final VoidCallback? onEmojiTap;
  final Function(int duration, String filePath)? onVoiceRecord;
  final Function(String userId, String nickname, String faceUrl)? onCardSend;

  const ChatInput({
    super.key,
    required this.controller,
    required this.onSend,
    this.onSendMarkdown,
    this.onImagePick,
    this.onCameraPick,
    this.onFilePick,
    this.onLocationPick,
    this.onVideoPick,
    this.onEmojiTap,
    this.onVoiceRecord,
    this.onCardSend,
  });

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  late FocusNode _focusNode;
  bool _isVoiceMode = false;
  bool _isMarkdownMode = false;

  /// 语音录制状态
  Timer? _recordingTimer;
  String? _recordingPath;
  DateTime? _recordingStart;

  /// 常用 emoji 列表
  static const List<String> _commonEmojis = [
    '😀', '😃', '😄', '😁', '😆', '😅', '🤣', '😂',
    '🙂', '🙃', '😉', '😊', '😇', '🥰', '😍', '🤩',
    '😘', '😗', '😚', '😙', '🥲', '😋', '😛', '😜',
    '🤪', '😝', '🤑', '🤗', '🤭', '🤫', '🤔', '🤐',
    '🤨', '😐', '😑', '😶', '😏', '😒', '🙄', '😬',
    '😮', '😯', '😲', '😳', '🥺', '😦', '😧', '😨',
    '😰', '😥', '😢', '😭', '😱', '😖', '😣', '😞',
    '😓', '😩', '😫', '🥱', '😤', '😡', '😠', '🤬',
    '👍', '👎', '👏', '🙏', '💪', '❤️', '🔥', '⭐',
    '🎉', '🎊', '💯', '✅', '❌', '⚡', '🌟', '💫',
  ];

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.onKeyEvent = _handleKeyEvent;
    widget.controller.addListener(_onTextChanged);
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
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {});
  }

  void _doSend() {
    final text = widget.controller.text.trim();
    if (text.isEmpty) return;
    if (_isMarkdownMode && widget.onSendMarkdown != null) {
      widget.onSendMarkdown!(text);
    } else {
      widget.onSend(text);
    }
  }

  bool get _hasText {
    return widget.controller.text.trim().isNotEmpty;
  }

  /// 开始录音（长按触发）
  void _startRecording(LongPressStartDetails details) async {
    final dir = await getTemporaryDirectory();
    _recordingPath =
        '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.aac';
    _recordingStart = DateTime.now();

    // 启动录音计时器（最长60秒自动停止）
    _recordingTimer = Timer(const Duration(seconds: 60), () {
      _stopRecording(LongPressEndDetails());
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

  /// 停止录音（松手触发）
  void _stopRecording(LongPressEndDetails details) async {
    _recordingTimer?.cancel();
    _recordingTimer = null;

    if (_recordingPath == null || _recordingStart == null) return;
    final duration = DateTime.now().difference(_recordingStart!).inSeconds;

    final path = _recordingPath;
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

    // 回调通知父组件发送语音消息
    widget.onVoiceRecord?.call(duration, path!);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
      child: SafeArea(
        child: _isVoiceMode ? _buildVoiceMode() : _buildTextMode(),
      ),
    );
  }

  /// 语音模式：按住说话
  Widget _buildVoiceMode() {
    return Row(
      children: [
        // 语音/文字切换
        IconButton(
          icon: Icon(
            Icons.keyboard_alt_outlined,
            size: 26,
            color: AppTheme.textSecondaryColor,
          ),
          onPressed: () {
            setState(() => _isVoiceMode = false);
            _focusNode.requestFocus();
          },
        ),
        const Spacer(),
        // 按住说话按钮
        GestureDetector(
          onLongPressStart: _startRecording,
          onLongPressEnd: _stopRecording,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              '按住  说话',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        const Spacer(),
        // 表情
        IconButton(
          icon: Icon(
            Icons.emoji_emotions_outlined,
            size: 26,
            color: AppTheme.textSecondaryColor,
          ),
          onPressed: () => _showEmojiPanel(context),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  /// 文字模式
  Widget _buildTextMode() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // 语音/文字切换
        IconButton(
          icon: Icon(
            Icons.mic_none,
            size: 26,
            color: AppTheme.textSecondaryColor,
          ),
          onPressed: () {
            setState(() => _isVoiceMode = true);
          },
        ),
        // 输入框
        Expanded(
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 40, maxHeight: 120),
            child: TextField(
              controller: widget.controller,
              focusNode: _focusNode,
              maxLines: null,
              textInputAction: TextInputAction.send,
              style: TextStyle(
                fontSize: 16,
                color: AppTheme.textPrimaryColor,
                fontFamily: _isMarkdownMode ? 'monospace' : null,
              ),
              decoration: InputDecoration(
                hintText: _isMarkdownMode ? '输入 Markdown...' : '输入消息...',
                hintStyle: const TextStyle(
                  color: AppTheme.textSecondaryColor,
                  fontSize: 16,
                ),
                filled: true,
                fillColor: AppTheme.backgroundColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
              onSubmitted: (_) => _doSend(),
            ),
          ),
        ),
        // Markdown 切换
        if (widget.onSendMarkdown != null)
          IconButton(
            icon: Icon(
              Icons.code,
              size: 24,
              color: _isMarkdownMode
                  ? AppTheme.primaryColor
                  : AppTheme.textSecondaryColor,
            ),
            onPressed: () {
              setState(() => _isMarkdownMode = !_isMarkdownMode);
            },
          ),
        // 表情
        IconButton(
          icon: Icon(
            Icons.emoji_emotions_outlined,
            size: 26,
            color: AppTheme.textSecondaryColor,
          ),
          onPressed: () => _showEmojiPanel(context),
        ),
        // 有内容时显示发送，否则显示加号
        if (_hasText)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: TextButton(
              onPressed: _doSend,
              style: TextButton.styleFrom(
                backgroundColor: _isMarkdownMode
                    ? AppTheme.textSecondaryColor
                    : AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                minimumSize: Size.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: Text(
                _isMarkdownMode ? 'MD' : '发送',
                style: const TextStyle(fontSize: 15),
              ),
            ),
          )
        else
          IconButton(
            icon: Icon(
              Icons.add_circle_outline,
              size: 28,
              color: AppTheme.textSecondaryColor,
            ),
            onPressed: () => _showMoreOptions(context),
          ),
      ],
    );
  }

  /// 显示表情面板
  void _showEmojiPanel(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: 280,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          children: [
            // 标题栏
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '表情',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimaryColor,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // emoji 网格
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 8,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemCount: _commonEmojis.length,
                itemBuilder: (context, index) {
                  final emoji = _commonEmojis[index];
                  return InkWell(
                    onTap: () {
                      final text = widget.controller.text;
                      final selection = widget.controller.selection;
                      final start = selection.start >= 0 ? selection.start : text.length;
                      final end = selection.end >= 0 ? selection.end : text.length;
                      final newText = text.replaceRange(start, end, emoji);
                      widget.controller.text = newText;
                      widget.controller.selection = TextSelection.fromPosition(
                        TextPosition(offset: start + emoji.length),
                      );
                    },
                    child: Center(
                      child: Text(
                        emoji,
                        style: const TextStyle(fontSize: 26),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMoreOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildOptionItem(context, Icons.photo_library_outlined, '相册', widget.onImagePick),
                    const SizedBox(width: 32),
                    _buildOptionItem(context, Icons.camera_alt_outlined, '相机', widget.onCameraPick),
                    const SizedBox(width: 32),
                    _buildOptionItem(context, Icons.videocam_outlined, '视频', widget.onVideoPick),
                    const SizedBox(width: 32),
                    _buildOptionItem(context, Icons.location_on_outlined, '定位', widget.onLocationPick),
                    const SizedBox(width: 32),
                    _buildOptionItem(context, Icons.insert_drive_file_outlined, '文件', widget.onFilePick),
                    const SizedBox(width: 32),
                    _buildOptionItem(context, Icons.person_add_outlined, '名片', widget.onCardSend != null ? () => _showCardSendDialog(context) : null),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 显示名片发送对话框（选择好友发送名片）
  void _showCardSendDialog(BuildContext context) {
    // 先关闭 more options 底部弹出层
    Navigator.of(context).pop();
    // 通知父组件处理名片发送
    // 这里先弹出一个简单提示，实际选择好友的逻辑由父组件的 onCardSend 回调处理
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('发送名片'),
        content: const Text('请选择要发送名片的好友'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // 默认发送当前用户自己的名片（父组件应覆盖此逻辑）
              widget.onCardSend?.call('', '', '');
            },
            child: const Text('确认'),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionItem(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback? onTap,
  ) {
    return InkWell(
      onTap: onTap != null
          ? () {
              AppRouter.goBack(context);
              onTap();
            }
          : null,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppTheme.backgroundColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 28,
              color: onTap != null ? AppTheme.primaryColor : AppTheme.textSecondaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: onTap != null ? AppTheme.textSecondaryColor : AppTheme.textSecondaryColor.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}
