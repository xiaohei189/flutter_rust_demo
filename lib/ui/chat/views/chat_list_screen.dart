import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../providers/connection_provider.dart';
import '../../../../router/app_router.dart';
import '../../../../ui/core/theme/app_theme.dart';
import '../../../../ui/chat/widgets/chat_list_header.dart';
import '../../../../ui/chat/widgets/chat_list_item.dart';
import '../../../../ui/chat/widgets/conversation_title_bar.dart';
import '../../../../ui/chat/widgets/group_filter_panel.dart';
import '../../../../ui/profile/views/profile_drawer_screen.dart';
import '../../profile/providers/user_profile_provider.dart';
import '../../core/view_models/connection_view_model.dart';
import '../providers/chat_list_provider.dart';
import '../providers/conversation_provider.dart';
import '../view_models/chat_list_view_model.dart';
import '../view_models/conversation_view_model.dart';

/// 会话列表页（参考飞书风格）
class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  late final ChatListViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = ref.read(chatListViewModelProvider.notifier);
  }

  void _openGroupFilterPanel() {
    final conversationState = ref.read(conversationListProvider);
    final activeFilter = ref.read(chatListViewModelProvider).activeFilter;
    final totalUnread = conversationState.totalUnreadCount;
    final totalMessages = conversationState.conversations.length;
    final groupCount = _viewModel.groupChatCount(
      conversationState.conversations,
    );

    Navigator.of(context).push(
      LeftSlideRoute(
        child: GroupFilterPanel(
          activeFilter: activeFilter,
          totalMessages: totalMessages,
          unreadCount: totalUnread,
          groupCount: groupCount,
          onSelect: (filter) {
            AppRouter.goBack(context);
            _viewModel.setFilter(filter);
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
    final listState = ref.watch(chatListViewModelProvider);
    final activeFilter = listState.activeFilter;

    final conversations = _viewModel.filteredConversations(
      conversationState.conversations,
    );
    final totalUnread = conversationState.totalUnreadCount;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: ConversationTitleBar(
        currentUserId: userProfileState.profile?.userId ?? '',
        nickname: userProfileState.profile?.nickname,
        avatarUrl: _viewModel.displayAvatarUrl,
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
        onRefresh: _viewModel.refreshConversations,
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
            activeFilter: activeFilter,
            totalUnreadCount: totalUnread,
            isQuickTab: _viewModel.isQuickTab(activeFilter),
            isSyncing: conversationState.isSyncing,
            syncProgress: conversationState.syncProgress,
            onFilterChange: _viewModel.setFilter,
            onOpenGroupFilter: _openGroupFilterPanel,
          ),
          Divider(height: 1, color: colors.divider),
          Expanded(
            child: RefreshIndicator(
              color: colors.primary,
              onRefresh: _viewModel.refreshConversations,
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
                            await _viewModel.deleteConversation(
                              conversation.conversationId,
                            );
                          },
                          onPinToggle: () async {
                            await _viewModel.toggleConversationPin(
                              conversation.conversationId,
                              !conversation.isPinned,
                            );
                          },
                          onMarkRead: () async {
                            await _viewModel.markConversationMessageAsRead(
                              conversation.conversationId,
                            );
                          },
                          onHide: () async {
                            await _viewModel.hideConversation(
                              conversation.conversationId,
                            );
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
    final activeFilter = ref.read(chatListViewModelProvider).activeFilter;
    final label = _viewModel.emptyStateLabel(activeFilter);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            activeFilter == GroupFilter.unread
                ? Icons.done_all
                : Icons.chat_bubble_outline,
            size: 64,
            color: colors.textSecondary.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            activeFilter == GroupFilter.all ? '暂无会话' : '「$label」中没有会话',
            style: TextStyle(fontSize: 16, color: colors.textSecondary),
          ),
          if (activeFilter == GroupFilter.all) ...[
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
