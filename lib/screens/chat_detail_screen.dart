import 'package:flutter/material.dart';

import '../main.dart';
import '../utils/app_logger.dart';
import '../models/user.dart';
import '../src/rust/im/model/conversation.dart' as im_conv;
import '../widgets/chat_input.dart';
import '../widgets/message_bubble.dart';
import '../widgets/user_avatar.dart';

/// 聊天详情页面
class ChatDetailScreen extends StatefulWidget {
  final im_conv.LocalConversation conversation;

  const ChatDetailScreen({super.key, required this.conversation});

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingHistory = false; // 是否正在加载历史消息
  bool _hasMoreHistory = true; // 是否还有更多历史消息

  @override
  void initState() {
    super.initState();
    // 监听消息服务的变化
    messageService.addListener(_onMessageServiceChanged);
    // 监听滚动事件，实现翻页加载
    _scrollController.addListener(_onScroll);
    // 加载历史消息
    _loadMessages();
  }

  @override
  void dispose() {
    messageService.removeListener(_onMessageServiceChanged);
    _scrollController.removeListener(_onScroll);
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

  /// 加载历史消息（首次加载或翻页）
  Future<void> _loadMessages({bool isLoadMore = false}) async {
    if (_isLoadingHistory) return; // 防止重复加载
    if (!_hasMoreHistory && isLoadMore) return; // 没有更多消息时不再加载

    setState(() {
      _isLoadingHistory = true;
    });

    try {
      final conversationId = widget.conversation.conversationId;

      // 获取当前消息列表，用于确定翻页的起始消息ID
      final currentMessages = messageService.getMessages(conversationId);
      String? startClientMsgId;

      if (isLoadMore && currentMessages.isNotEmpty) {
        // 翻页加载：使用最早的消息ID作为起始消息ID（完全匹配 Go SDK）
        startClientMsgId = currentMessages.first.id;
      }

      // 加载历史消息
      final hasMore = await messageService.loadHistoryMessages(
        conversationId,
        count: 20,
        startClientMsgId: startClientMsgId,
      );

      setState(() {
        _hasMoreHistory = hasMore;
        _isLoadingHistory = false;
      });

      // 首次加载时滚动到底部
      if (!isLoadMore) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom();
        });
      }
    } catch (e) {
      appLog.e('加载历史消息失败: $e');
      setState(() {
        _isLoadingHistory = false;
      });
    }
  }

  /// 滚动事件监听，实现滚动到顶部时加载更早的消息
  void _onScroll() {
    // 当滚动到顶部附近时（距离顶部 200px 内），加载更早的消息
    if (_scrollController.hasClients &&
        _scrollController.position.pixels < 200 &&
        _hasMoreHistory &&
        !_isLoadingHistory) {
      _loadMessages(isLoadMore: true);
    }
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

      // 发送消息（传入 conversationId 以便发送后刷新消息列表）
      await messageService.sendTextMessage(
        recvId: recvId,
        text: text,
        sessionType: sessionType,
        conversationId: widget.conversation.conversationId,
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
                  itemCount: messages.length + (_isLoadingHistory ? 1 : 0),
                  itemBuilder: (context, index) {
                    // 显示加载指示器
                    if (index == 0 && _isLoadingHistory) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }

                    // 调整索引（如果有加载指示器）
                    final messageIndex = _isLoadingHistory ? index - 1 : index;
                    if (messageIndex < 0 || messageIndex >= messages.length) {
                      return const SizedBox.shrink();
                    }

                    final message = messages[messageIndex];
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
