import 'package:flutter/material.dart';

import '../main.dart';
import '../theme/app_theme.dart';
import '../utils/app_logger.dart';
import '../models/user.dart';
import '../src/rust/im/model/conversation.dart' as im_conv;
import '../widgets/chat_input.dart';
import '../widgets/message_bubble.dart';
import '../widgets/user_avatar.dart';
import 'chat_settings_screen.dart';

/// 聊天详情页：顶栏（返回+未读、昵称+在线/成员数、更多）、消息区、底部输入区
class ChatDetailScreen extends StatefulWidget {
  final im_conv.LocalConversation conversation;
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
  bool _isLoadingHistory = false;
  bool _hasMoreHistory = true;
  bool _initialScrollDone = false;

  @override
  void initState() {
    super.initState();
    messageService.addListener(_onMessageServiceChanged);
    _scrollController.addListener(_onScroll);
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

  bool get _isGroup =>
      widget.conversation.conversationType == 2 ||
      widget.conversation.conversationType == 3;

  Future<void> _loadMessages({bool isLoadMore = false}) async {
    if (_isLoadingHistory) return;
    if (!_hasMoreHistory && isLoadMore) return;

    setState(() => _isLoadingHistory = true);

    try {
      final conversationId = widget.conversation.conversationId;
      final currentMessages =
          messageService.getMessages(conversationId);
      String? startClientMsgId;

      if (isLoadMore && currentMessages.isNotEmpty) {
        startClientMsgId = currentMessages.first.id;
      }

      final hasMore = await messageService.loadHistoryMessages(
        conversationId,
        count: 20,
        startClientMsgId: startClientMsgId,
      );

      setState(() {
        _hasMoreHistory = hasMore;
        _isLoadingHistory = false;
      });

      if (!isLoadMore) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _jumpToBottomOnce();
        });
      }
    } catch (e) {
      appLog.e('加载历史消息失败: $e');
      setState(() => _isLoadingHistory = false);
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients ||
        !_hasMoreHistory ||
        _isLoadingHistory) return;
    final pos = _scrollController.position;
    if (widget.preLoaded) {
      if (pos.pixels >= pos.maxScrollExtent - 200) {
        _loadMessages(isLoadMore: true);
      }
    } else {
      if (pos.pixels < 200) _loadMessages(isLoadMore: true);
    }
  }

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
            backgroundColor: AppTheme.unreadRed,
          ),
        );
      }
      return;
    }

    try {
      final type = widget.conversation.conversationType;
      final cid = widget.conversation.conversationId;
      String recvId;
      switch (type) {
        case 1:
          recvId = widget.conversation.userId;
          if (recvId.isEmpty && cid.startsWith('si_')) {
            final parts = cid.split('_');
            if (parts.length >= 3) {
              final id1 = parts[1];
              final id2 = parts[2];
              final my = messageService.currentUserId;
              recvId = id1 == my ? id2 : id1;
            }
          }
          break;
        case 2:
          recvId = cid.startsWith('g_')
              ? cid.substring(2)
              : widget.conversation.groupId;
          break;
        case 3:
          recvId = cid.startsWith('sg_')
              ? cid.substring(3)
              : widget.conversation.groupId;
          break;
        default:
          recvId = '';
      }
      final sessionType = type;

      if (recvId.isEmpty) {
        appLog.e(
            '发送消息失败: recvId 为空，conversationId=${widget.conversation.conversationId}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('无法发送：会话缺少对方 ID，请返回会话列表重试'),
              backgroundColor: AppTheme.unreadRed,
            ),
          );
        }
        return;
      }

      _textController.clear();

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

      if (!widget.preLoaded) _scrollToBottom();
    } catch (e, st) {
      appLog.e('发送消息失败: $e', e, st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('发送消息失败: $e'),
            backgroundColor: AppTheme.unreadRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _getUser();
    final unread = widget.conversation.unreadCount;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.arrow_back_ios_new, size: 22),
              if (unread > 0)
                Positioned(
                  right: -8,
                  top: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    decoration: const BoxDecoration(
                      color: AppTheme.unreadRed,
                      borderRadius: BorderRadius.all(Radius.circular(10)),
                    ),
                    child: Text(
                      unread > 99 ? '99+' : '$unread',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: LayoutBuilder(
          builder: (context, constraints) {
            return InkWell(
              onTap: () {
                // 可进入聊天设置/查找聊天记录
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  UserAvatar(user: user, radius: 18),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: constraints.maxWidth.isFinite && constraints.maxWidth > 56
                        ? constraints.maxWidth - 56
                        : 200,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimaryColor,
                          ),
                        ),
                        if (_isGroup)
                          Text(
                            '群聊',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondaryColor.withValues(
                                alpha: 0.9,
                              ),
                            ),
                          )
                        else
                          Text(
                            '在线',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondaryColor.withValues(
                                alpha: 0.9,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_horiz),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatSettingsScreen(
                    conversation: widget.conversation,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
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
                          color: AppTheme.textSecondaryColor.withValues(
                            alpha: 0.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          '暂无消息',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppTheme.textSecondaryColor,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final useReverse = widget.preLoaded;
                final itemCount =
                    messages.length + (_isLoadingHistory ? 1 : 0);

                return ListView.builder(
                  controller: _scrollController,
                  reverse: useReverse,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: itemCount,
                  itemBuilder: (context, index) {
                    if (_isLoadingHistory) {
                      if (!useReverse && index == 0) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: CircularProgressIndicator(
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        );
                      }
                      if (useReverse && index == messages.length) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: CircularProgressIndicator(
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        );
                      }
                    }

                    final messageIndex = useReverse
                        ? messages.length - 1 - index
                        : (_isLoadingHistory ? index - 1 : index);
                    if (messageIndex < 0 ||
                        messageIndex >= messages.length) {
                      return const SizedBox.shrink();
                    }

                    final message = messages[messageIndex];
                    return MessageBubble(
                      message: message,
                      otherUser: user,
                      currentUserId: messageService.currentUserId,
                    );
                  },
                );
              },
            ),
          ),
          ChatInput(
            controller: _textController,
            onSend: _sendMessage,
          ),
        ],
      ),
    );
  }
}
