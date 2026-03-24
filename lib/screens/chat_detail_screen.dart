import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../router/app_router.dart';
import '../theme/app_theme.dart';
import '../utils/app_logger.dart';
import '../models/user.dart';
import '../src/rust/im/model/conversation.dart' as im_conv;
import '../widgets/chat_input.dart';
import '../widgets/message_list.dart';
import '../widgets/user_avatar.dart';

/// 聊天详情页：顶栏（返回+未读、昵称+在线/成员数、更多）、消息区、底部输入区
class ChatDetailScreen extends ConsumerStatefulWidget {
  final im_conv.LocalConversation conversation;
  final bool preLoaded;

  const ChatDetailScreen({
    super.key,
    required this.conversation,
    this.preLoaded = false,
  });

  @override
  ConsumerState<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends ConsumerState<ChatDetailScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<bool> _loadingNotifier = ValueNotifier<bool>(false);
  bool _hasMoreHistory = true;
  bool _initialScrollDone = false;
  bool _bodyReady = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    if (!widget.preLoaded) _loadMessages();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _bodyReady = true);
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _loadingNotifier.dispose();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  User _getUser(UserProfileState userProfileState) {
    final userId = widget.conversation.userId.isNotEmpty
        ? widget.conversation.userId
        : widget.conversation.groupId;
    final userName = widget.conversation.showName.isNotEmpty
        ? widget.conversation.showName
        : widget.conversation.conversationId;

    // 从 notifier 获取用户资料缓存
    final cached = widget.conversation.userId.isNotEmpty
        ? ref.read(userProfileProvider.notifier).getUserProfile(widget.conversation.userId)
        : null;

    return User(
      id: userId,
      name: (cached?.nickname ?? '').isNotEmpty ? cached!.nickname : userName,
      avatar: (cached?.faceUrl ?? '').isNotEmpty
          ? cached!.faceUrl
          : widget.conversation.faceUrl.isNotEmpty
              ? widget.conversation.faceUrl
              : null,
      status: null,
    );
  }

  bool get _isGroup =>
      widget.conversation.conversationType == 2 ||
      widget.conversation.conversationType == 3;

  Future<void> _loadMessages({bool isLoadMore = false}) async {
    if (_loadingNotifier.value) return;
    if (!_hasMoreHistory && isLoadMore) return;

    _loadingNotifier.value = true;

    try {
      final conversationId = widget.conversation.conversationId;
      final messageState = ref.read(messageListProvider(conversationId));
      final currentMessages = messageState.messages;
      String? startClientMsgId;

      if (isLoadMore && currentMessages.isNotEmpty) {
        startClientMsgId = currentMessages.first.id;
      }

      final hasMore = await ref
          .read(messageListProvider(conversationId).notifier)
          .loadHistoryMessages(
            count: 20,
            startClientMsgId: startClientMsgId,
          );

      _hasMoreHistory = hasMore;
      _loadingNotifier.value = false;

      if (!isLoadMore) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _initialScrollDone = true;
        });
      }
    } catch (e) {
      appLog.e('加载历史消息失败: $e');
      _loadingNotifier.value = false;
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients ||
        !_hasMoreHistory ||
        _loadingNotifier.value) {
      return;
    }
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 200) {
      _loadMessages(isLoadMore: true);
    }
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final pos = _scrollController.position;
      const target = 0.0;
      if (pos.pixels != target) {
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
      _initialScrollDone = true;
    });
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    final connectionState = ref.read(connectionProvider);
    if (!connectionState.isConnected) {
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
      final userProfileState = ref.read(userProfileProvider);
      String recvId;
      switch (type) {
        case 1:
          recvId = widget.conversation.userId;
          if (recvId.isEmpty && cid.startsWith('si_')) {
            final parts = cid.split('_');
            if (parts.length >= 3) {
              final id1 = parts[1];
              final id2 = parts[2];
              final my = userProfileState.profile?.userId ?? '';
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

      await ref
          .read(messageListProvider(widget.conversation.conversationId).notifier)
          .sendTextMessage(
            recvId: recvId,
            text: text,
            sessionType: sessionType,
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
    final userProfileState = ref.watch(userProfileProvider);
    final user = _getUser(userProfileState);
    final unread = widget.conversation.unreadCount;
    final currentUserId = userProfileState.profile?.userId ?? '';

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
              AppRouter.goToChatSettings(context, widget.conversation);
            },
          ),
        ],
      ),
      body: _bodyReady
          ? Column(
              children: [
                Expanded(
                  child: Consumer(
                    builder: (context, ref, child) {
                      final messageState = ref.watch(
                        messageListProvider(widget.conversation.conversationId),
                      );
                      final messages = messageState.messages;
                      final isLoading = _loadingNotifier.value;

                      return MessageList(
                        messages: messages,
                        otherUser: user,
                        currentUserId: currentUserId.isNotEmpty ? currentUserId : null,
                        scrollController: _scrollController,
                        isLoading: isLoading,
                      );
                    },
                  ),
                ),
                ChatInput(
                  controller: _textController,
                  onSend: _sendMessage,
                ),
              ],
            )
          : const ColoredBox(
              color: AppTheme.backgroundColor,
              child: SizedBox.expand(),
            ),
    );
  }
}
