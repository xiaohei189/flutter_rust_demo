import 'dart:async';

import 'package:flutter/material.dart';

import '../main.dart';
import '../router/app_router.dart';
import '../theme/app_theme.dart';
import '../src/rust/im/model/conversation.dart' as im_conv;
import '../widgets/chat_list_header.dart';
import '../widgets/chat_list_item.dart';
import '../widgets/conversation_title_bar.dart';
import '../widgets/group_filter_panel.dart';
import 'profile_drawer_screen.dart';

/// 会话列表页（参考飞书风格）
class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  Timer? _delayRefreshTimer;
  GroupFilter _activeFilter = GroupFilter.all;

  @override
  void initState() {
    super.initState();
    messageService.addListener(_onMessageServiceChanged);
    _delayRefreshTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && messageService.conversations.isEmpty) {
        messageService.refreshConversations();
      }
    });
  }

  @override
  void dispose() {
    _delayRefreshTimer?.cancel();
    messageService.removeListener(_onMessageServiceChanged);
    super.dispose();
  }

  void _onMessageServiceChanged() {
    if (mounted) setState(() {});
  }

  int get _totalUnreadCount {
    int sum = 0;
    for (final c in messageService.conversations) {
      sum += c.unreadCount;
    }
    return sum;
  }

  int get _groupChatCount {
    return messageService.conversations
        .where((c) => c.conversationType == 2 || c.conversationType == 3)
        .length;
  }

  List<im_conv.LocalConversation> get _filteredConversations {
    var list = messageService.conversations;

    switch (_activeFilter) {
      case GroupFilter.unread:
        list = list.where((c) => c.unreadCount > 0).toList();
        break;
      case GroupFilter.singleChat:
        list = list.where((c) => c.conversationType == 1).toList();
        break;
      case GroupFilter.groupChat:
        list = list
            .where((c) =>
                c.conversationType == 2 || c.conversationType == 3)
            .toList();
        break;
      case GroupFilter.flagged:
      case GroupFilter.atMe:
      case GroupFilter.done:
        list = [];
        break;
      case GroupFilter.all:
        break;
    }

    return list;
  }

  bool get _isQuickTab =>
      _activeFilter == GroupFilter.all ||
      _activeFilter == GroupFilter.unread ||
      _activeFilter == GroupFilter.flagged;

  void _openGroupFilterPanel() {
    final totalUnread = _totalUnreadCount;
    final totalMessages = messageService.conversations.length;
    final groupCount = _groupChatCount;

    Navigator.of(context).push(LeftSlideRoute(
      child: GroupFilterPanel(
        activeFilter: _activeFilter,
        totalMessages: totalMessages,
        unreadCount: totalUnread,
        groupCount: groupCount,
        onSelect: (filter) {
          AppRouter.goBack(context);
          setState(() => _activeFilter = filter);
        },
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final conversations = _filteredConversations;
    final totalUnread = _totalUnreadCount;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: ConversationTitleBar(
        currentUserId: messageService.currentUserId,
        nickname: messageService.loginUserProfile?.nickname,
        avatarUrl: messageService.loginUserProfile?.faceUrl,
        isSyncing: messageService.isSyncingConversations,
        isConnected: messageService.isConnected,
        syncProgress: messageService.syncProgress,
        onAvatarTap: () {
          Navigator.of(context).push(LeftSlideRoute(
            child: ProfileDrawerScreen(
              onOpenMyProfile: () {
                Navigator.of(context).pop();
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  AppRouter.goToMyProfile(context);
                });
              },
            ),
          ));
        },
        onSearchTap: () {
          AppRouter.goToSearch(context);
        },
        onRefresh: () => messageService.refreshConversations(),
        onAddFriend: () {},
        onAddGroup: () {},
        onCreateGroup: () {},
        onScan: () {},
      ),
      body: Column(
        children: [
          ChatListHeader(
            activeFilter: _activeFilter,
            totalUnreadCount: totalUnread,
            isQuickTab: _isQuickTab,
            isSyncing: messageService.isSyncingConversations,
            syncProgress: messageService.syncProgress,
            onFilterChange: (filter) {
              setState(() => _activeFilter = filter);
            },
            onOpenGroupFilter: _openGroupFilterPanel,
          ),
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
          Expanded(
            child: conversations.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    key: ValueKey<int>(conversations.length),
                    padding: EdgeInsets.zero,
                    itemCount: conversations.length,
                    itemBuilder: (context, index) {
                      final conversation = conversations[index];
                      return ChatListItem(
                        key: ValueKey<String>(conversation.conversationId),
                        conversation: conversation,
                        cachedUserProfile: conversation.userId.isNotEmpty
                            ? messageService.getUserProfile(conversation.userId)
                            : null,
                        itemIndex: index,
                        currentUserId:
                            messageService.currentUserId.isNotEmpty
                                ? messageService.currentUserId
                                : null,
                        onTap: () {
                          AppRouter.goToChatDetail(context, conversation);
                        },
                        onDelete: () {
                          messageService.removeConversation(
                            conversation.conversationId,
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('已删除会话'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        onPinToggle: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('置顶功能开发中'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        onMarkRead: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('标为已读功能开发中'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final label = _activeFilter == GroupFilter.all
        ? '消息'
        : _activeFilter == GroupFilter.unread
            ? '未读'
            : _activeFilter == GroupFilter.flagged
                ? '标记'
                : _activeFilter == GroupFilter.atMe
                    ? '@我'
                    : _activeFilter == GroupFilter.singleChat
                        ? '单聊'
                        : _activeFilter == GroupFilter.groupChat
                            ? '群组'
                            : '已完成';
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (messageService.isSyncingConversations) ...[
            const CircularProgressIndicator(color: AppTheme.primaryColor),
            const SizedBox(height: 16),
            Text(
              '正在同步会话... ${messageService.syncProgress}%',
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondaryColor,
              ),
            ),
          ] else ...[
            Icon(
              _activeFilter == GroupFilter.unread
                  ? Icons.done_all
                  : Icons.chat_bubble_outline,
              size: 64,
              color: AppTheme.textSecondaryColor.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              _activeFilter == GroupFilter.all
                  ? '暂无会话'
                  : '「$label」中没有会话',
              style: const TextStyle(
                fontSize: 16,
                color: AppTheme.textSecondaryColor,
              ),
            ),
            if (_activeFilter == GroupFilter.all) ...[
              const SizedBox(height: 8),
              Text(
                messageService.isConnected ? '等待接收消息...' : 'WebSocket 未连接',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondaryColor.withValues(alpha: 0.7),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
