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
  /// 是否已在进入前预加载了最后一屏消息（列表页点击时先 load 再 push）
  final bool preLoaded;

  const ChatDetailScreen({
    super.key,
    required this.conversation,
    this.preLoaded = false,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingHistory = false; // 是否正在加载历史消息
  bool _hasMoreHistory = true; // 是否还有更多历史消息
  bool _initialScrollDone = false; // 是否已完成首次滚到底部（避免进入时可见的滚动动画）

  @override
  void initState() {
    super.initState();
    messageService.addListener(_onMessageServiceChanged);
    _scrollController.addListener(_onScroll);
    // 仅未预加载时才在进入时请求历史（预加载时列表页已拉取最后一屏）
    if (!widget.preLoaded) _loadMessages();
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
      // reverse 列表下新消息在 index 0，无需滚动；非 reverse 时再滚到底部
      if (!widget.preLoaded && _initialScrollDone) _scrollToBottom();
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

      // 首次加载后直接跳到底部，无动画，避免进入时出现向下滚动抖动
      if (!isLoadMore) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _jumpToBottomOnce();
        });
      }
    } catch (e) {
      appLog.e('加载历史消息失败: $e');
      setState(() {
        _isLoadingHistory = false;
      });
    }
  }

  /// 滚动事件监听。reverse 列表下「往上滑」= 看更早消息，pixels 增大，接近 maxScrollExtent 时加载更多
  void _onScroll() {
    if (!_scrollController.hasClients || !_hasMoreHistory || _isLoadingHistory) return;
    final pos = _scrollController.position;
    if (widget.preLoaded) {
      if (pos.pixels >= pos.maxScrollExtent - 200) _loadMessages(isLoadMore: true);
    } else {
      if (pos.pixels < 200) _loadMessages(isLoadMore: true);
    }
  }

  /// 非预加载时首次进入瞬间跳到底部
  void _jumpToBottomOnce() {
    if (widget.preLoaded || !mounted || _initialScrollDone) return;
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.maxScrollExtent > 0) {
      _scrollController.jumpTo(pos.maxScrollExtent);
      _initialScrollDone = true;
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _initialScrollDone || !_scrollController.hasClients) return;
      final p = _scrollController.position;
      if (p.maxScrollExtent > 0) _scrollController.jumpTo(p.maxScrollExtent);
      _initialScrollDone = true;
    });
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final pos = _scrollController.position;
      if (pos.maxScrollExtent > pos.pixels) {
        _scrollController.animateTo(
          pos.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
      _initialScrollDone = true;
    });
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    if (!messageService.isConnected) {
      appLog.e('发送消息失败: WebSocket 未连接');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('WebSocket 未连接，无法发送消息'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    try {
      // 按会话类型确定接收者 ID：1=单聊用 userId，2/3=群聊从 conversationId 去前缀得群 ID
      final type = widget.conversation.conversationType;
      final cid = widget.conversation.conversationId;
      final recvId = switch (type) {
        1 => widget.conversation.userId,
        2 => cid.startsWith('g_') ? cid.substring(2) : widget.conversation.groupId,
        3 => cid.startsWith('sg_') ? cid.substring(3) : widget.conversation.groupId,
        _ => '',
      };
      final sessionType = type;

      if (recvId.isEmpty) {
        appLog.e('发送消息失败: recvId 为空，conversationId=${widget.conversation.conversationId} userId=${widget.conversation.userId} groupId=${widget.conversation.groupId}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('无法发送：会话缺少对方 ID，请返回会话列表重试'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // 先创建消息并加入列表，再发送，成功后更新发送状态
      final groupId = sessionType == 3 || sessionType == 2
          ? (widget.conversation.groupId.isNotEmpty
              ? widget.conversation.groupId
              : cid.startsWith('sg_')
                  ? cid.substring(3)
                  : cid.startsWith('g_')
                      ? cid.substring(2)
                      : '')
          : '';
      await messageService.sendTextMessage(
        recvId: recvId,
        text: text,
        sessionType: sessionType,
        conversationId: widget.conversation.conversationId,
        groupId: groupId,
      );

      _textController.clear();
      // reverse 列表下新消息已在 index 0（底部），无需滚动；非 reverse 时才滚到底部
      if (!widget.preLoaded) _scrollToBottom();
    } catch (e, st) {
      appLog.e('发送消息失败: $e', e, st);
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

                // 预加载时用 reverse 列表：index 0 在底部=最新一条，进入即最后一屏无滚动
                final useReverse = widget.preLoaded;
                final itemCount = messages.length + (_isLoadingHistory ? 1 : 0);

                return ListView.builder(
                  controller: _scrollController,
                  reverse: useReverse,
                  padding: const EdgeInsets.all(16),
                  itemCount: itemCount,
                  itemBuilder: (context, index) {
                    // 加载更多指示器：正序在顶部 index 0，反序在「列表末尾」= 顶部
                    if (_isLoadingHistory) {
                      if (!useReverse && index == 0) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }
                      if (useReverse && index == messages.length) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }
                    }

                    final messageIndex = useReverse
                        ? messages.length - 1 - index
                        : (_isLoadingHistory ? index - 1 : index);
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
