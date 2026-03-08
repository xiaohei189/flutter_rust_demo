import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// 底部输入区：语音/文字切换、自适应输入框、表情、加号（无内容）/发送（有内容）
class ChatInput extends StatefulWidget {
  final TextEditingController controller;
  final Function(String) onSend;

  const ChatInput({
    super.key,
    required this.controller,
    required this.onSend,
  });

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  late FocusNode _focusNode;
  bool _isVoiceMode = false;

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
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {});
  }

  void _doSend() {
    final text = widget.controller.text.trim();
    if (text.isNotEmpty) widget.onSend(text);
  }

  bool get _hasText {
    return widget.controller.text.trim().isNotEmpty;
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
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // 语音/文字切换
            IconButton(
              icon: Icon(
                _isVoiceMode ? Icons.keyboard_alt_outlined : Icons.mic_none,
                size: 26,
                color: AppTheme.textSecondaryColor,
              ),
              onPressed: () {
                setState(() => _isVoiceMode = !_isVoiceMode);
                if (!_isVoiceMode) _focusNode.requestFocus();
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
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppTheme.textPrimaryColor,
                  ),
                  decoration: InputDecoration(
                    hintText: '输入消息...',
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
            // 表情
            IconButton(
              icon: Icon(
                Icons.emoji_emotions_outlined,
                size: 26,
                color: AppTheme.textSecondaryColor,
              ),
              onPressed: () {
                // TODO: 打开表情面板
              },
            ),
            // 有内容时显示发送，否则显示加号
            if (_hasText)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: TextButton(
                  onPressed: _doSend,
                  style: TextButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
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
                  child: const Text('发送', style: TextStyle(fontSize: 15)),
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
                    _buildOptionItem(context, Icons.photo_library_outlined, '相册', () {}),
                    const SizedBox(width: 32),
                    _buildOptionItem(context, Icons.camera_alt_outlined, '相机', () {}),
                    const SizedBox(width: 32),
                    _buildOptionItem(context, Icons.location_on_outlined, '定位', () {}),
                    const SizedBox(width: 32),
                    _buildOptionItem(context, Icons.insert_drive_file_outlined, '文件', () {}),
                    const SizedBox(width: 32),
                    _buildOptionItem(context, Icons.card_giftcard_outlined, '红包', () {}),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionItem(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
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
            child: Icon(icon, size: 28, color: AppTheme.primaryColor),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondaryColor,
            ),
          ),
        ],
      ),
    );
  }
}
