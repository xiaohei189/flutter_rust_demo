import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../router/app_router.dart';
import '../src/rust/infra/database/models.dart' show LocalConversation;
import '../theme/app_theme.dart';
import '../widgets/chat_list_header.dart';
import '../widgets/chat_list_item.dart';
import '../widgets/conversation_title_bar.dart';
import '../widgets/group_filter_panel.dart';
import 'profile_drawer_screen.dart';

/// 会话列表页（参考飞书风格）
class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  Timer? _delayRefreshTimer;
  GroupFilter _activeFilter = GroupFilter.all;

  @override
  void initState() {
    super.initState();
    // 延迟 3 秒检查：列表仍空则主动刷新一次
    _delayRefreshTimer = Timer(const Duration(seconds: 3), () {
      final conversations = ref.read(conversationListProvider).conversations;
      if (mounted && conversations.isEmpty) {
        ref.read(conversationListProvider.notifier).refreshConversations();
      }
    });
  }

  @override
  void dispose() {
    _delayRefreshTimer?.cancel();
    super.dispose();
  }

  int get _groupChatCount {
    final conversations = ref.read(conversationListProvider).conversations;
    return conversations
        .where((c) => c.conversationType == 2 || c.conversationType == 3)
        .length;
  }

  List<LocalConversation> _getFilteredConversations(List<LocalConversation> conversations) {
    switch (_activeFilter) {
      case GroupFilter.unread:
        return conversations.where((c) => c.unreadCount > 0).toList();
      case GroupFilter.singleChat:
        return conversations.where((c) => c.conversationType == 1).toList();
      case GroupFilter.groupChat:
        return conversations
            .where((c) => c.conversationType == 2 || c.conversationType == 3)
            .toList();
      case GroupFilter.flagged:
      case GroupFilter.atMe:
      case GroupFilter.done:
        return [];
      case GroupFilter.all:
        return conversations;
    }
  }

  bool get _isQuickTab =>
      _activeFilter == GroupFilter.all ||
      _activeFilter == GroupFilter.unread ||
      _activeFilter == GroupFilter.flagged;

  void _openGroupFilterPanel() {
    final conversationState = ref.read(conversationListProvider);
    final totalUnread = conversationState.totalUnreadCount;
    final totalMessages = conversationState.conversations.length;
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
    final conversationState = ref.watch(conversationListProvider);
    final connectionState = ref.watch(connectionProvider);
    final userProfileState = ref.watch(userProfileProvider);

    final conversations = _getFilteredConversations(conversationState.conversations);
    final totalUnread = conversationState.totalUnreadCount;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: ConversationTitleBar(
        currentUserId: userProfileState.profile?.userId ?? '',
        nickname: userProfileState.profile?.nickname,
        avatarUrl: ref.read(userProfileProvider.notifier).getDisplayAvatarUrl(),
        isSyncing: conversationState.isSyncing,
        isConnected: connectionState.isConnected,
        syncProgress: conversationState.syncProgress,
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
        onRefresh: () => ref.read(conversationListProvider.notifier).refreshConversations(),
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
            isSyncing: conversationState.isSyncing,
            syncProgress: conversationState.syncProgress,
            onFilterChange: (filter) {
              setState(() => _activeFilter = filter);
            },
            onOpenGroupFilter: _openGroupFilterPanel,
          ),
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
          Expanded(
            child: RefreshIndicator(
              color: AppTheme.primaryColor,
              onRefresh: () => ref.read(conversationListProvider.notifier).refreshConversations(),
              child: conversations.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.5,
                          child: _buildEmptyState(conversationState, connectionState),
                        ),
                      ],
                    )
                  : ListView.builder(
                      key: ValueKey<int>(conversations.length),
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.zero,
                      itemCount: conversations.length,
                      itemBuilder: (context, index) {
                        final conversation = conversations[index];
                        final otherUserId = conversation.conversationType == 1 && conversation.userId.isNotEmpty
                              ? conversation.userId
                              : null;
                          final otherUserProfile = otherUserId != null && otherUserId != userProfileState.profile?.userId
                              ? ref.read(messageServiceProvider.notifier).getUserProfile(otherUserId)
                              : null;
                          return ChatListItem(
                          key: ValueKey<String>(conversation.conversationId),
                          conversation: conversation,
                          cachedUserProfile: otherUserProfile,
                          currentUserLocalAvatarPath: userProfileState.localAvatarPath,
                          itemIndex: index,
                          currentUserId: userProfileState.profile?.userId,
                          onTap: () {
                            AppRouter.goToChatDetail(context, conversation);
                          },
                          onDelete: () async {
                            await ref.read(messageServiceProvider.notifier).deleteConversation(conversation.conversationId);
                          },
                          onPinToggle: () async {
                            await ref.read(messageServiceProvider.notifier).toggleConversationPin(
                              conversation.conversationId,
                              conversation.isPinned != 1,
                            );
                          },
                          onMarkRead: () async {
                            await ref.read(messageServiceProvider.notifier).markConversationAsRead(conversation.conversationId);
                          },
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ConversationListState conversationState, AppConnectionState connectionState) {
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
              connectionState.isConnected ? '等待接收消息...' : 'WebSocket 未连接',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondaryColor.withValues(alpha: 0.7),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
