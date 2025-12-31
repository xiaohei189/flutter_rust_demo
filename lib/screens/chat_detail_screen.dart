import 'package:flutter/material.dart';

import '../main.dart';
import '../models/user.dart';
import '../src/rust/im/types.dart';
import '../widgets/chat_input.dart';
import '../widgets/message_bubble.dart';
import '../widgets/user_avatar.dart';

/// 聊天详情页面
class ChatDetailScreen extends StatefulWidget {
  final LocalConversation conversation;

  const ChatDetailScreen({super.key, required this.conversation});

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // 监听消息服务的变化
    messageService.addListener(_onMessageServiceChanged);
    // 加载历史消息
    _loadMessages();
  }

  @override
  void dispose() {
    messageService.removeListener(_onMessageServiceChanged);
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onMessageServiceChanged() {
    if (mounted) {
      setState(() {});
      // 自动滚动到底部
      _scrollToBottom();
    }
  }

  User _getUser() {
    final userId = widget.conversation.userId.isNotEmpty
        ? widget.conversation.userId
        : widget.conversation.groupId;
    final userName = widget.conversation.showName.isNotEmpty
        ? widget.conversation.showName
        : widget.conversation.conversationId;

    return User(
      id: userId,
      name: userName,
      avatar: widget.conversation.faceUrl.isNotEmpty
          ? widget.conversation.faceUrl
          : null,
      status: null,
    );
  }

  void _loadMessages() {
    // 从消息服务获取该会话的消息
    final messages = messageService.getMessages(
      widget.conversation.conversationId,
    );
    if (messages.isEmpty) {
      // 如果没有消息，加载一些模拟数据（可选）
      // _loadMockMessages();
    }
    // 延迟滚动到底部，确保列表已渲染
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
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
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    if (!messageService.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('WebSocket 未连接，无法发送消息'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // 确定接收者ID和会话类型
      final recvId = widget.conversation.userId.isNotEmpty
          ? widget.conversation.userId
          : widget.conversation.groupId;
      final sessionType = widget.conversation.conversationType;

      // 发送消息
      await messageService.sendTextMessage(
        recvId: recvId,
        text: text,
        sessionType: sessionType,
      );

      _textController.clear();
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('发送消息失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            UserAvatar(user: _getUser(), radius: 18),
            const SizedBox(width: 10),
            Text(_getUser().name),
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
            child: Builder(
              builder: (context) {
                final messages = messageService.getMessages(
                  widget.conversation.conversationId,
                );

                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '暂无消息',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    return MessageBubble(
                      message: message,
                      otherUser: _getUser(),
                    );
                  },
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
}
