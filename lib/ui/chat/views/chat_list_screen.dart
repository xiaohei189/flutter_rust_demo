import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/connection_provider.dart';
import '../../../providers/current_user_provider.dart';
import '../../../providers/online_status_provider.dart';
import '../../../../domain/models/conversation.dart';
import '../../../../domain/models/user_profile.dart' show UserProfile;
import '../../../../router/app_router.dart';
import '../../../../ui/core/theme/app_theme.dart';
import '../../../../ui/chat/widgets/list/chat_list_header.dart';
import '../../../../ui/chat/widgets/list/chat_list_item.dart';
import '../../../../ui/chat/widgets/shared/conversation_title_bar.dart';
import '../../../../ui/chat/widgets/list/group_filter_panel.dart';
import '../../../../ui/chat/widgets/list/chat_list_skeleton.dart';
import '../../../../ui/profile/views/profile_drawer_screen.dart';
import '../../profile/providers/user_profile_provider.dart';
import '../../core/view_models/connection_view_model.dart';
import '../providers/chat_list_provider.dart';
import '../providers/conversation_folder_provider.dart';
import '../providers/conversation_provider.dart';
import '../view_models/chat_list_view_model.dart';
import '../widgets/list/chat_list_dialogs.dart';
import '../view_models/conversation_view_model.dart';

/// 会话列表页（参考飞书风格）
class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  late final ChatListViewModel _viewModel;
  late final ChatListDialogs _dialogs;

  bool _selectionMode = false;
  final Set<String> _selectedIds = <String>{};

  @override
  void initState() {
    super.initState();
    _viewModel = ref.read(chatListViewModelProvider.notifier);
    _dialogs = ChatListDialogs(ref: ref, viewModel: _viewModel);
  }

  void _enterSelectionMode() {
    setState(() {
      _selectionMode = true;
      _selectedIds.clear();
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  void _toggleSelect(String conversationId) {
    setState(() {
      if (!_selectedIds.add(conversationId)) {
        _selectedIds.remove(conversationId);
      }
    });
  }

  Future<void> _runBatch(Future<void> Function(Iterable<String>) action) async {
    final ids = List<String>.from(_selectedIds);
    if (ids.isEmpty) return;
    await action(ids);
    if (mounted) _exitSelectionMode();
  }


  void _openGroupFilterPanel() {
    final conversationState = ref.read(conversationListProvider);
    final activeFilter = ref.read(chatListViewModelProvider).activeFilter;
    final totalUnread = conversationState.totalUnreadCount;
    final totalMessages = conversationState.conversations.length;
    final groupCount = _viewModel.groupChatCount(
      conversationState.conversations,
    );
    final atMeCount = _viewModel.atMeCount(conversationState.conversations);
    final flaggedCount = _viewModel.flaggedCount(
      conversationState.conversations,
    );
    final doneCount = _viewModel.doneCount(conversationState.conversations);
    final archivedCount = _viewModel.archivedCount(
      conversationState.conversations,
    );
    final folders = ref.read(conversationFoldersProvider);
    final activeFolder = ref.read(chatListViewModelProvider).activeFolder;

    Navigator.of(context).push(
      LeftSlideRoute(
        child: GroupFilterPanel(
          activeFilter: activeFilter,
          totalMessages: totalMessages,
          unreadCount: totalUnread,
          groupCount: groupCount,
          atMeCount: atMeCount,
          flaggedCount: flaggedCount,
          doneCount: doneCount,
          archivedCount: archivedCount,
          folders: folders,
          activeFolder: activeFolder,
          onSelect: (filter) {
            AppRouter.goBack(context);
            _viewModel.setFilter(filter);
          },
          onSelectFolder: (name) {
            AppRouter.goBack(context);
            _viewModel.setFolder(name);
          },
          onCreateFolder: () {
            AppRouter.goBack(context);
            _dialogs.showCreateFolderDialog(context);
          },
          onDeleteFolder: (name) {
            AppRouter.goBack(context);
            _dialogs.showDeleteFolderDialog(context, name);
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
    final userProfileState = ref.watch(userProfileViewProvider);
    final cachedUserProfiles = ref.watch(conversationUserProfilesProvider);
    final currentUserId = ref.watch(currentUserIdProvider);
    final listState = ref.watch(chatListViewModelProvider);
    final activeFilter = listState.activeFilter;
    final typingByConversation = conversationState.typingByConversation;
    final failedConversationIds = conversationState.failedConversationIds;

    final conversations = _viewModel.filteredConversations(
      conversationState.conversations,
    );
    final totalUnread = conversationState.totalUnreadCount;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: ConversationTitleBar(
        currentUserId: currentUserId,
        nickname: userProfileState.profile?.nickname,
        statusText: userProfileState.signature,
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
        onManage: _enterSelectionMode,
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
            onSearchTap: () => AppRouter.goToSearch(context),
            activeFolderLabel: listState.activeFolder,
          ),
          if (!connectionState.isConnected) _buildOfflineBanner(context),
          Expanded(
            child: RefreshIndicator(
              color: colors.primary,
              onRefresh: _viewModel.refreshConversations,
              child: _buildConversationList(
                context,
                conversations: conversations,
                conversationState: conversationState,
                connectionState: connectionState,
                activeFilter: activeFilter,
                cachedUserProfiles: cachedUserProfiles,
                currentUserId: currentUserId,
                typingByConversation: typingByConversation,
                failedConversationIds: failedConversationIds,
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _selectionMode ? _buildSelectionBar(context) : null,
    );
  }

  Widget _buildConversationList(
    BuildContext context, {
    required List<Conversation> conversations,
    required ConversationListState conversationState,
    required AppConnectionState connectionState,
    required GroupFilter activeFilter,
    required Map<String, UserProfile> cachedUserProfiles,
    required String currentUserId,
    required Map<String, String> typingByConversation,
    required Set<String> failedConversationIds,
  }) {
    if (conversationState.isLoading && conversations.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [ChatListSkeleton()],
      );
    }
    if (conversations.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.5,
            child: _buildEmptyState(
              conversationState,
              connectionState,
              activeFilter,
            ),
          ),
        ],
      );
    }

    final items = <Widget>[];
    if (activeFilter == GroupFilter.all && !_selectionMode) {
      final pinned = conversations.where((c) => c.isPinned).toList();
      final unpinned = conversations.where((c) => !c.isPinned).toList();
      if (pinned.isNotEmpty) {
        items.add(_buildSectionHeader(context, '置顶聊天'));
        items.addAll(
          pinned.map(
            (c) => _buildListItem(
              context,
              conversation: c,
              cachedUserProfiles: cachedUserProfiles,
              currentUserId: currentUserId,
              typingByConversation: typingByConversation,
              failedConversationIds: failedConversationIds,
              focusAtMe: activeFilter == GroupFilter.atMe,
              conversationState: conversationState,
            ),
          ),
        );
      }
      if (unpinned.isNotEmpty) {
        if (pinned.isNotEmpty) {
          items.add(_buildSectionHeader(context, '聊天'));
        }
        items.addAll(
          unpinned.map(
            (c) => _buildListItem(
              context,
              conversation: c,
              cachedUserProfiles: cachedUserProfiles,
              currentUserId: currentUserId,
              typingByConversation: typingByConversation,
              failedConversationIds: failedConversationIds,
              focusAtMe: activeFilter == GroupFilter.atMe,
              conversationState: conversationState,
            ),
          ),
        );
      }
    } else {
      items.addAll(
        conversations.map(
          (c) => _buildListItem(
            context,
            conversation: c,
            cachedUserProfiles: cachedUserProfiles,
            currentUserId: currentUserId,
            typingByConversation: typingByConversation,
            failedConversationIds: failedConversationIds,
            focusAtMe: activeFilter == GroupFilter.atMe,
            conversationState: conversationState,
          ),
        ),
      );
    }
    return ListView(
      key: const PageStorageKey<String>('conversation_list'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      children: items,
    );
  }

  Widget _buildListItem(
    BuildContext context, {
    required Conversation conversation,
    required Map<String, UserProfile> cachedUserProfiles,
    required String currentUserId,
    required Map<String, String> typingByConversation,
    required Set<String> failedConversationIds,
    required bool focusAtMe,
    required ConversationListState conversationState,
  }) {
    final otherUserId =
        conversation.conversationType == 1 && conversation.userId.isNotEmpty
        ? conversation.userId
        : null;
    final otherUserProfile = otherUserId != null && otherUserId != currentUserId
        ? cachedUserProfiles[otherUserId]
        : null;
    final isOnline = otherUserId != null && otherUserId != currentUserId
        ? ref.watch(userOnlineStatusProvider(otherUserId))
        : null;
    final typingUserId = typingByConversation[conversation.conversationId];
    final String? typingText;
    if (typingUserId != null) {
      typingText = conversation.conversationType == 1 ? '对方正在输入…' : '群成员正在输入…';
    } else {
      typingText = null;
    }
    final hasSendFailure = failedConversationIds.contains(
      conversation.conversationId,
    );

    return ChatListItem(
      key: ValueKey<String>(conversation.conversationId),
      conversation: conversation,
      cachedUserProfile: otherUserProfile,
      currentUserLocalAvatarPath: ref
          .read(userProfileViewProvider)
          .localAvatarPath,
      previewText: conversationState.previews[conversation.conversationId],
      timeText: conversationState.timeTexts[conversation.conversationId],
      currentUserId: currentUserId,
      isSelectionMode: _selectionMode,
      isSelected: _selectedIds.contains(conversation.conversationId),
      isOnline: isOnline,
      typingText: typingText,
      hasSendFailure: hasSendFailure,
      onRetrySend: () =>
          _viewModel.retryFailedSend(conversation.conversationId),
      onTap: () {
        if (_selectionMode) {
          _toggleSelect(conversation.conversationId);
          return;
        }
        if (conversation.isNotInGroup) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('已不在该群，无法进入会话'),
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }
        AppRouter.goToChatDetail(context, conversation, focusAtMe: focusAtMe);
      },
      onDelete: () =>
          _viewModel.deleteConversation(conversation.conversationId),
      onPinToggle: () => _viewModel.toggleConversationPin(
        conversation.conversationId,
        !conversation.isPinned,
      ),
      onMarkRead: () =>
          _viewModel.markConversationAsRead(conversation.conversationId),
      onMarkUnread: () =>
          _viewModel.markConversationAsUnread(conversation.conversationId),
      onMuteToggle: () => _viewModel.toggleConversationMute(
        conversation.conversationId,
        conversation.recvMsgOpt == 1,
      ),
      onClear: () => _viewModel.clearConversation(conversation.conversationId),
      onFlagToggle: () => _viewModel.toggleConversationFlagged(
        conversation.conversationId,
        !ChatListViewModel.isFlagged(conversation),
      ),
      onDoneToggle: () => _viewModel.toggleConversationDone(
        conversation.conversationId,
        !ChatListViewModel.isDone(conversation),
      ),
      onArchive: () =>
          _viewModel.archiveConversation(conversation.conversationId),
      onUnarchive: () =>
          _viewModel.unarchiveConversation(conversation.conversationId),
      onMoveToFolder: () async {
        final folder = await _dialogs.pickFolder(context);
        if (folder == null) return;
        await ref
            .read(conversationFoldersProvider.notifier)
            .addToFolder(folder, conversation.conversationId);
      },
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    final colors = context.appColors;
    return Container(
      width: double.infinity,
      color: colors.background,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: colors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildOfflineBanner(BuildContext context) {
    final colors = context.appColors;
    return Container(
      width: double.infinity,
      color: colors.warning.withValues(alpha: 0.15),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          Icon(Icons.wifi_off, size: 16, color: colors.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '当前网络不可用，消息可能无法同步',
              style: TextStyle(fontSize: 12, color: colors.textPrimary),
            ),
          ),
          TextButton(
            onPressed: _viewModel.refreshConversations,
            child: Text(
              '重试',
              style: TextStyle(fontSize: 12, color: colors.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionBar(BuildContext context) {
    final colors = context.appColors;
    return Container(
      color: colors.surface,
      child: SafeArea(
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  '已选 ${_selectedIds.length} 项',
                  style: TextStyle(fontSize: 13, color: colors.textPrimary),
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _selectionAction(
                        context,
                        icon: Icons.push_pin_outlined,
                        label: '置顶',
                        onTap: () => _runBatch(
                          (ids) => _viewModel.batchTogglePin(ids, true),
                        ),
                      ),
                      _selectionAction(
                        context,
                        icon: Icons.done_all,
                        label: '已读',
                        onTap: () => _runBatch(_viewModel.batchMarkRead),
                      ),
                      _selectionAction(
                        context,
                        icon: Icons.inventory_2_outlined,
                        label: '归档',
                        onTap: () => _runBatch(_viewModel.batchArchive),
                      ),
                      _selectionAction(
                        context,
                        icon: Icons.folder_outlined,
                        label: '分组',
                        onTap: () async {
                          final folder = await _dialogs.pickFolder(context);
                          if (folder == null) return;
                          await _runBatch((ids) async {
                            final notifier = ref.read(
                              conversationFoldersProvider.notifier,
                            );
                            for (final id in ids) {
                              await notifier.addToFolder(folder, id);
                            }
                          });
                        },
                      ),
                      _selectionAction(
                        context,
                        icon: Icons.delete_outline,
                        label: '删除',
                        color: colors.danger,
                        onTap: () => _runBatch(_viewModel.batchDelete),
                      ),
                    ],
                  ),
                ),
              ),
              TextButton(
                onPressed: _exitSelectionMode,
                child: const Text('取消'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _selectionAction(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    final colors = context.appColors;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: color ?? colors.textPrimary),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: color ?? colors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(
    ConversationListState conversationState,
    AppConnectionState connectionState,
    GroupFilter activeFilter,
  ) {
    final colors = context.appColors;
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
            const SizedBox(height: 24),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton.icon(
                  onPressed: () => AppRouter.goToCreateGroup(context),
                  icon: const Icon(Icons.group_add_outlined, size: 18),
                  label: const Text('发起群聊'),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: () => AppRouter.goToAddContact(context),
                  icon: const Icon(Icons.person_add_alt_1, size: 18),
                  label: const Text('添加好友'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
