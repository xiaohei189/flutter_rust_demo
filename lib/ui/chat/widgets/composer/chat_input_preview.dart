import 'package:flutter/material.dart';

import '../../../previews/app_theme_preview.dart';
import 'chat_input.dart';

/// 预览宿主：持有并管理输入框 controller，保证可交互、可输入、可展开面板。
class ChatInputPreviewHost extends StatefulWidget {
  final bool isGroupChat;

  const ChatInputPreviewHost({super.key, this.isGroupChat = false});

  @override
  State<ChatInputPreviewHost> createState() => _ChatInputPreviewHostState();
}

class _ChatInputPreviewHostState extends State<ChatInputPreviewHost> {
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
Widget chatInputSinglePreview() => const ChatInputPreviewHost();

@AppThemePreview(name: '群聊 - 带 @ 按钮', group: 'ChatInput')
Widget chatInputGroupPreview() => const ChatInputPreviewHost(isGroupChat: true);