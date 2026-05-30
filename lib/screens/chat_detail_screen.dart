import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../router/app_router.dart';
import '../theme/app_theme.dart';
import '../utils/app_logger.dart';
import '../models/user.dart';
import '../src/rust/infra/database/models.dart' show LocalConversation;
import '../widgets/chat_input.dart';
import '../widgets/message_list.dart';
import '../widgets/user_avatar.dart';

/// 聊天详情页：顶栏（返回+未读、昵称+在线/成员数、更多）、消息区、底部输入区
class ChatDetailScreen extends ConsumerStatefulWidget {
  final String conversationId;
  final bool preLoaded;

  const ChatDetailScreen({
    super.key,
    required this.conversationId,
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
  bool _bodyReady = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // 设置当前选中的会话
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(selectedConversationIdProvider.notifier).state = widget.conversationId;
      if (!widget.preLoaded) _loadMessages();
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

  /// 获取会话信息
  LocalConversation? get _conversation {
    // 先尝试从新的 ConversationService 获取
    final newService = ref.read(conversationServiceProvider);
    var conversation = newService.getConversation(widget.conversationId);
    if (conversation != null) return conversation;
    
    // 如果新服务没有，尝试从旧的 conversationListProvider 获取
    final oldState = ref.read(conversationListProvider);
    conversation = oldState.conversations
        .where((c) => c.conversationId == widget.conversationId)
        .firstOrNull;
    return conversation;
  }

  User _getUser(UserProfileState userProfileState) {
    final conversation = _conversation;
    if (conversation == null) {
      return User(
        id: widget.conversationId,
        name: '未知会话',
        avatar: null,
        status: null,
      );
    }

    final userId = conversation.userId.isNotEmpty
        ? conversation.userId
        : conversation.groupId;
    final userName = conversation.showName.isNotEmpty
        ? conversation.showName
        : conversation.conversationId;

    // 从 notifier 获取用户资料缓存
    final cached = conversation.userId.isNotEmpty
        ? ref.read(userProfileProvider.notifier).getUserProfile(conversation.userId)
        : null;

    return User(
      id: userId,
      name: (cached?.nickname ?? '').isNotEmpty ? cached!.nickname : userName,
      avatar: (cached?.faceUrl ?? '').isNotEmpty
          ? cached!.faceUrl
          : conversation.faceUrl.isNotEmpty
              ? conversation.faceUrl
              : null,
      status: null,
    );
  }

  bool get _isGroup {
    final conversation = _conversation;
    if (conversation == null) return false;
    return conversation.conversationType == 2 ||
        conversation.conversationType == 3;
  }

  Future<void> _loadMessages({bool isLoadMore = false}) async {
    if (_loadingNotifier.value) return;
    if (!_hasMoreHistory && isLoadMore) return;

    _loadingNotifier.value = true;

    try {
      final messageState = ref.read(messageListProvider(widget.conversationId));
      final currentMessages = messageState.messages;
      int startSeq = 0;

      if (isLoadMore && currentMessages.isNotEmpty) {
        // 使用最早消息的发送时间作为 startSeq
        final earliestMsg = currentMessages.first;
        startSeq = earliestMsg.timestamp.millisecondsSinceEpoch ~/ 1000;
      }

      final hasMore = await ref
          .read(messageListProvider(widget.conversationId).notifier)
          .loadHistoryMessages(
            count: 20,
            startSeq: startSeq,
          );

      _hasMoreHistory = hasMore;
      _loadingNotifier.value = false;

      if (!isLoadMore) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _scrollToBottom();
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

    final conversation = _conversation;
    if (conversation == null) {
      appLog.e('发送消息失败: 会话不存在');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('会话不存在'),
            backgroundColor: AppTheme.unreadRed,
          ),
        );
      }
      return;
    }

    try {
      final type = conversation.conversationType;
      final cid = conversation.conversationId;
      final userProfileState = ref.read(userProfileProvider);
      String recvId;
      switch (type) {
        case 1:
          recvId = conversation.userId;
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
              : conversation.groupId;
          break;
        case 3:
          recvId = cid.startsWith('sg_')
              ? cid.substring(3)
              : conversation.groupId;
          break;
        default:
          recvId = '';
      }
      final sessionType = type;

      if (recvId.isEmpty) {
        appLog.e(
            '发送消息失败: recvId 为空，conversationId=${conversation.conversationId}');
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
          ? (conversation.groupId.isNotEmpty
              ? conversation.groupId
              : cid.startsWith('sg_')
                  ? cid.substring(3)
                  : cid.startsWith('g_')
                      ? cid.substring(2)
                      : '')
          : '';

      await ref
          .read(messageListProvider(conversation.conversationId).notifier)
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
    final conversation = _conversation;
    final unread = conversation?.unreadCount ?? 0;
    final currentUserId = userProfileState.profile?.userId ?? '';

    if (conversation == null) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 22),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text('会话不存在'),
        ),
        body: const Center(
          child: Text('会话信息不存在或已被删除'),
        ),
      );
    }

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
              AppRouter.goToChatSettings(context, conversation);
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
                        messageListProvider(widget.conversationId),
                      );
                      final messages = messageState.messages;
                      final isLoading = _loadingNotifier.value;

                      return MessageList(
                        messages: messages,
                        otherUser: user,
                        currentUserId: currentUserId.isNotEmpty ? currentUserId : null,
                        scrollController: _scrollController,
                        isLoading: isLoading,
                        cachedCurrentUserProfile: ref.watch(userProfileProvider).profile,
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
