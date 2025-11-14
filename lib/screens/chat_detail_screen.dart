import 'package:flutter/material.dart';

import '../models/chat.dart';
import '../models/message.dart';
import '../widgets/chat_input.dart';
import '../widgets/message_bubble.dart';
import '../widgets/user_avatar.dart';

/// 聊天详情页面
class ChatDetailScreen extends StatefulWidget {
  final Chat chat;

  const ChatDetailScreen({super.key, required this.chat});

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Message> _messages = [];

  @override
  void initState() {
    super.initState();
    _loadMockMessages();
  }

  void _loadMockMessages() {
    // 模拟历史消息
    _messages.addAll([
      Message(
        id: '1',
        senderId: widget.chat.user.id,
        content: '你好！',
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      Message(
        id: '2',
        senderId: '1',
        content: '你好，有什么可以帮你的吗？',
        timestamp: DateTime.now().subtract(
          const Duration(hours: 1, minutes: 59),
        ),
      ),
      Message(
        id: '3',
        senderId: widget.chat.user.id,
        content: '我想了解一下你们的产品',
        timestamp: DateTime.now().subtract(
          const Duration(hours: 1, minutes: 58),
        ),
      ),
      Message(
        id: '4',
        senderId: '1',
        content: '好的，我可以给你详细介绍一下',
        timestamp: DateTime.now().subtract(
          const Duration(hours: 1, minutes: 57),
        ),
      ),
    ]);
  }

  void _sendMessage(String text) {
    if (text.trim().isEmpty) return;

    final message = Message(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      senderId: '1',
      content: text,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(message);
    });

    _textController.clear();

    // 滚动到底部
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    // 模拟对方回复
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _messages.add(
            Message(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              senderId: widget.chat.user.id,
              content: '收到，谢谢！',
              timestamp: DateTime.now(),
            ),
          );
        });

        Future.delayed(const Duration(milliseconds: 100), () {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            UserAvatar(user: widget.chat.user, radius: 18),
            const SizedBox(width: 10),
            Text(widget.chat.user.name),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.phone),
            onPressed: () {
              // TODO: 语音通话
            },
          ),
          IconButton(
            icon: const Icon(Icons.videocam),
            onPressed: () {
              // TODO: 视频通话
            },
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              // TODO: 更多选项
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 消息列表
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return MessageBubble(
                  message: message,
                  otherUser: widget.chat.user,
                );
              },
            ),
          ),

          // 输入框
          ChatInput(controller: _textController, onSend: _sendMessage),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
