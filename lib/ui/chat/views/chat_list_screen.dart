import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../domain/models/conversation.dart';
import '../../../../providers/providers.dart';
import '../../../../router/app_router.dart';
import '../../../../ui/core/theme/app_theme.dart';
import '../../../../ui/chat/widgets/chat_list_header.dart';
import '../../../../ui/chat/widgets/chat_list_item.dart';
import '../../../../ui/chat/widgets/conversation_title_bar.dart';
import '../../../../ui/chat/widgets/group_filter_panel.dart';
import '../../../../ui/profile/views/profile_drawer_screen.dart';
import '../../core/view_models/connection_view_model.dart';
import '../view_models/conversation_view_model.dart';

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

  List<Conversation> _getFilteredConversations(
    List<Conversation> conversations,
  ) {
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

    Navigator.of(context).push(
      LeftSlideRoute(
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final conversationState = ref.watch(conversationListProvider);
    final connectionState = ref.watch(connectionProvider);
    final userProfileState = ref.watch(userProfileProvider);
    final cachedUserProfiles = ref.watch(conversationUserProfilesProvider);

    final conversations = _getFilteredConversations(
      conversationState.conversations,
    );
    final totalUnread = conversationState.totalUnreadCount;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: ConversationTitleBar(
        currentUserId: userProfileState.profile?.userId ?? '',
        nickname: userProfileState.profile?.nickname,
        avatarUrl: ref.read(userProfileProvider.notifier).getDisplayAvatarUrl(),
        isSyncing: conversationState.isSyncing,
        isConnected: connectionState.isConnected,
        syncProgress: conversationState.syncProgress,
        onAvatarTap: () {
          Navigator.of(context).push(
            LeftSlideRoute(
              child: ProfileDrawerScreen(
                onOpenMyProfile: () {
                  AppRouter.goToMyProfile(context);
                },
              ),
            ),
          );
        },
        onSearchTap: () {
          AppRouter.goToSearch(context);
        },
        onRefresh: () =>
            ref.read(conversationListProvider.notifier).refreshConversations(),
        onAddFriend: () => AppRouter.goToAddContact(context),
        onAddGroup: () => AppRouter.goToSearch(context),
        onCreateGroup: () => AppRouter.goToCreateGroup(context),
        onScan: () async {
          final raw = await context.push<String>('/scan');
          if (raw == null || !mounted) return;
          _handleScanResult(raw);
        },
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
          Divider(height: 1, color: colors.divider),
          Expanded(
            child: RefreshIndicator(
              color: colors.primary,
              onRefresh: () => ref
                  .read(conversationListProvider.notifier)
                  .refreshConversations(),
              child: conversations.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.5,
                          child: _buildEmptyState(
                            conversationState,
                            connectionState,
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      key: const PageStorageKey<String>('conversation_list'),
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.zero,
                      itemCount: conversations.length,
                      itemBuilder: (context, index) {
                        final conversation = conversations[index];
                        final otherUserId =
                            conversation.conversationType == 1 &&
                                conversation.userId.isNotEmpty
                            ? conversation.userId
                            : null;
                        final otherUserProfile =
                            otherUserId != null &&
                                otherUserId != userProfileState.profile?.userId
                            ? cachedUserProfiles[otherUserId]
                            : null;
                        return ChatListItem(
                          key: ValueKey<String>(conversation.conversationId),
                          conversation: conversation,
                          cachedUserProfile: otherUserProfile,
                          currentUserLocalAvatarPath:
                              userProfileState.localAvatarPath,
                          previewText: conversationState
                              .previews[conversation.conversationId],
                          timeText: conversationState
                              .timeTexts[conversation.conversationId],
                          itemIndex: index,
                          currentUserId: userProfileState.profile?.userId,
                          onTap: () {
                            AppRouter.goToChatDetail(context, conversation);
                          },
                          onDelete: () async {
                            await ref
                                .read(messageServiceProvider.notifier)
                                .deleteConversation(
                                  conversation.conversationId,
                                );
                          },
                          onPinToggle: () async {
                            await ref
                                .read(messageServiceProvider.notifier)
                                .toggleConversationPin(
                                  conversation.conversationId,
                                  !conversation.isPinned,
                                );
                          },
                          onMarkRead: () async {
                            await ref
                                .read(messageServiceProvider.notifier)
                                .markConversationMessageAsRead(
                                  conversation.conversationId,
                                );
                          },
                          onHide: () async {
                            await ref
                                .read(messageServiceProvider.notifier)
                                .hideConversation(conversation.conversationId);
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

  Widget _buildEmptyState(
    ConversationListState conversationState,
    AppConnectionState connectionState,
  ) {
    final colors = context.appColors;
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
            color: colors.textSecondary.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            _activeFilter == GroupFilter.all ? '暂无会话' : '「$label」中没有会话',
            style: TextStyle(fontSize: 16, color: colors.textSecondary),
          ),
          if (_activeFilter == GroupFilter.all) ...[
            const SizedBox(height: 8),
            Text(
              connectionState.isConnected ? '等待接收消息...' : 'WebSocket 未连接',
              style: TextStyle(
                fontSize: 12,
                color: colors.textSecondary.withValues(alpha: 0.7),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _handleScanResult(String raw) {
    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      _showUnsupportedUrlDialog(raw);
      return;
    }
    if (raw.startsWith('g_') || raw.startsWith('sg_')) {
      AppRouter.goToGroupInfoById(context, raw);
    } else {
      AppRouter.goToUserProfile(context, userId: raw);
    }
  }

  void _showUnsupportedUrlDialog(String url) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('扫描到链接'),
        content: SelectableText(url),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: url));
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('已复制链接'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('复制链接'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
}
