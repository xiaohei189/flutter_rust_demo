import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/connection_provider.dart';
import '../../../providers/current_user_provider.dart';
import '../../../../domain/models/conversation.dart';
import '../../../../domain/models/user_profile.dart' show UserProfile;
import '../../../../router/app_router.dart';
import '../../../../ui/core/theme/app_theme.dart';
import '../../../../ui/chat/widgets/list/chat_list_header.dart';
import '../../../../ui/chat/widgets/list/chat_list_item.dart';
import '../../../../ui/chat/widgets/shared/conversation_title_bar.dart';
import '../../../../ui/chat/widgets/list/group_filter_panel.dart';
import '../../../../ui/chat/widgets/list/chat_list_skeleton.dart';
import '../../../../ui/shared/widgets/app_dropdown_menu.dart';
import '../../../../ui/profile/views/profile_drawer_screen.dart';
import '../../profile/providers/user_profile_provider.dart';
import '../../core/view_models/connection_view_model.dart';
import '../providers/chat_list_provider.dart';
import '../providers/conversation_folder_provider.dart';
import '../providers/conversation_provider.dart';
import '../view_models/chat_list_view_model.dart';
import 'conversation_folder_manage_screen.dart';
import '../widgets/list/chat_list_dialogs.dart';
import '../view_models/conversation_view_model.dart';
import '../providers/message_service_provider.dart';

/// 会话列表页（参考飞书风格）
class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  late final ChatListViewModel _viewModel;
  late final ChatListDialogs _dialogs;

  /// 顶部「+」按钮，用于给下拉菜单定位。
  final GlobalKey _addButtonKey = GlobalKey();

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
          onManageFolders: () {
            AppRouter.goBack(context);
            _openFolderManageScreen();
          },
        ),
      ),
    );
  }

  /// 右上角「+」菜单。飞书稿里这一栏很长，本仓库先落「扫一扫」「创建群组」
  /// 两个真实入口，其余（添加成员/文档/会议等）等对应功能就绪再逐个补。
  void _openAddMenu() {
    showAppDropdownMenu(
      context: context,
      anchorKey: _addButtonKey,
      items: [
        AppMenuItem(
          key: const ValueKey('chat_add_menu_scan'),
          icon: Icons.qr_code_scanner,
          label: '扫一扫',
          onTap: _scanQrCode,
        ),
        AppMenuItem(
          key: const ValueKey('chat_add_menu_create_group'),
          icon: Icons.group_add_outlined,
          label: '创建群组',
          onTap: _openCreateGroup,
        ),
        AppMenuItem(
          key: const ValueKey('chat_add_menu_multi_select'),
          icon: Icons.checklist,
          label: '多选管理',
          onTap: _enterSelectionMode,
        ),
      ],
    );
  }

  /// 创建群组：成功后刷新会话并进入新群聊。
  ///
  /// 服务端会在创建群时生成 `sg_<groupID>` 会话，Rust 侧同时落了本地会话；
  /// 这里 reload 一次本地会话列表再跳转，避免用户回到列表看不到新群。
  Future<void> _openCreateGroup() async {
    final group = await AppRouter.goToCreateGroup(context);
    if (!mounted || group == null) return;
    await ref.read(messageServiceProvider.notifier).loadConversations();
    if (!mounted) return;
    AppRouter.goToChatDetailById(context, 'sg_${group.groupId}');
  }

  /// 扫一扫：识别结果交给 [ChatListDialogs.handleScanResult] 决定去向。
  Future<void> _scanQrCode() async {
    final raw = await AppRouter.goToScan(context);
    if (!mounted || raw == null || raw.isEmpty) return;
    _dialogs.handleScanResult(context, raw);
  }

  /// 打开分组管理页；返回后如果当前筛选的分组已被删除或改名，就退回「消息」。
  Future<void> _openFolderManageScreen() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const ConversationFolderManageScreen(),
      ),
    );
    if (!mounted) return;
    final folders = ref.read(conversationFoldersProvider);
    final activeFolder = ref.read(chatListViewModelProvider).activeFolder;
    if (activeFolder != null && !folders.containsKey(activeFolder)) {
      _viewModel.setFolder(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final conversationState = ref.watch(conversationListProvider);
    final connectionState = ref.watch(connectionProvider);
    final userProfileState = ref.watch(userProfileViewProvider);
    final cachedUserProfiles = ref.watch(conversationUserProfilesProvider);
    final folderLabels = ref.watch(conversationFolderLabelProvider);
    final currentUserId = ref.watch(currentUserIdProvider);
    final listState = ref.watch(chatListViewModelProvider);
    final activeFilter = listState.activeFilter;
    final typingByConversation = conversationState.typingByConversation;
    final failedConversationIds = conversationState.failedConversationIds;
    // 当前用户本地头像路径在整屏内是常量：提前读一次，避免下面按行重复 ref.read。
    final currentUserLocalAvatarPath = ref
        .read(userProfileViewProvider)
        .localAvatarPath;

    final conversations = _viewModel.filteredConversations(
      conversationState.conversations,
    );
    final totalUnread = conversationState.totalUnreadCount;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: ConversationTitleBar(
        currentUserId: currentUserId,
        addButtonKey: _addButtonKey,
        nickname: userProfileState.profile?.nickname,
        statusText: userProfileState.signature,
        avatarUrl: _viewModel.displayAvatarUrl,
        isSyncing: conversationState.isSyncing,
        isConnected: connectionState.isConnected,
        syncProgress: conversationState.syncProgress,
        onAvatarTap: () {
          // 必须走 root navigator：抽屉要盖住底部 Tab 栏、遮罩铺满整屏。
          // 用当前 context（tab 分支路由）推的话，抽屉只占 body 区域，
          // 底部导航栏会露在外面且不被遮罩。
          Navigator.of(context, rootNavigator: true).push(
            LeftSlideRoute(
              barrierColor: context.appColors.mediaScrim,
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
        onAddTap: _openAddMenu,
      ),
      body: Column(
        children: [
          ChatListHeader(
            activeFilter: activeFilter,
            totalUnreadCount: totalUnread,
            isQuickTab: _viewModel.isQuickTab(activeFilter),
            isSyncing: conversationState.isSyncing,
            syncProgress: conversationState.syncProgress,
            syncError: conversationState.syncError,
            onRetrySync: () =>
                ref.read(conversationListProvider.notifier).retrySync(),
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
                currentUserLocalAvatarPath: currentUserLocalAvatarPath,
                typingByConversation: typingByConversation,
                failedConversationIds: failedConversationIds,
                folderLabels: folderLabels,
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
    required String? currentUserLocalAvatarPath,
    required Map<String, String> typingByConversation,
    required Set<String> failedConversationIds,
    required Map<String, String> folderLabels,
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

    // 只把「行数据」摊平成一个轻量列表，真正的行 Widget 交给 ListView.builder 惰性构建。
    // 之前用 `ListView(children: items)` 会在每次会话列表重建时一次性构造全部会话行
    // （含头像、滑动层、菜单回调），几百个会话 + 高频打字/连接状态更新时会明显掉帧；
    // 现在无论会话多少，每帧只构建视口内的行。
    final items = _buildListItems(
      conversations: conversations,
      activeFilter: activeFilter,
    );
    final focusAtMe = activeFilter == GroupFilter.atMe;

    return ListView.builder(
      key: const PageStorageKey<String>('conversation_list'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return switch (item) {
          _SectionHeaderItem(:final title) => _buildSectionHeader(
            context,
            title,
          ),
          _ConversationRowItem(:final conversation) => _buildListItem(
            context,
            conversation: conversation,
            cachedUserProfiles: cachedUserProfiles,
            currentUserId: currentUserId,
            currentUserLocalAvatarPath: currentUserLocalAvatarPath,
            typingByConversation: typingByConversation,
            failedConversationIds: failedConversationIds,
            folderLabels: folderLabels,
            focusAtMe: focusAtMe,
            conversationState: conversationState,
          ),
        };
      },
    );
  }

  /// 摊平会话列表结构（置顶分区 + 普通分区），供 ListView.builder 惰性消费。
  List<_ConversationListItem> _buildListItems({
    required List<Conversation> conversations,
    required GroupFilter activeFilter,
  }) {
    if (activeFilter != GroupFilter.all || _selectionMode) {
      return [
        for (final conversation in conversations)
          _ConversationRowItem(conversation),
      ];
    }

    final pinned = conversations.where((c) => c.isPinned).toList();
    final unpinned = conversations.where((c) => !c.isPinned).toList();
    if (pinned.isEmpty) {
      return [
        for (final conversation in unpinned) _ConversationRowItem(conversation),
      ];
    }
    return [
      const _SectionHeaderItem('置顶聊天'),
      for (final conversation in pinned) _ConversationRowItem(conversation),
      if (unpinned.isNotEmpty) const _SectionHeaderItem('聊天'),
      for (final conversation in unpinned) _ConversationRowItem(conversation),
    ];
  }

  Widget _buildListItem(
    BuildContext context, {
    required Conversation conversation,
    required Map<String, UserProfile> cachedUserProfiles,
    required String currentUserId,
    required String? currentUserLocalAvatarPath,
    required Map<String, String> typingByConversation,
    required Set<String> failedConversationIds,
    required Map<String, String> folderLabels,
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
      currentUserLocalAvatarPath: currentUserLocalAvatarPath,
      previewText: conversationState.previews[conversation.conversationId],
      timeText: conversationState.timeTexts[conversation.conversationId],
      currentUserId: currentUserId,
      isSelectionMode: _selectionMode,
      isSelected: _selectedIds.contains(conversation.conversationId),
      typingText: typingText,
      hasSendFailure: hasSendFailure,
      folderLabel: folderLabels[conversation.conversationId],
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
                  onPressed: _openCreateGroup,
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

/// 会话列表的惰性构建条目：分区标题或一行会话。
///
/// 结构在 `build` 里摊平成 [List]（很轻），行 Widget 只在滚动到可视区域时创建。
sealed class _ConversationListItem {
  const _ConversationListItem();
}

class _SectionHeaderItem extends _ConversationListItem {
  const _SectionHeaderItem(this.title);

  final String title;
}

class _ConversationRowItem extends _ConversationListItem {
  const _ConversationRowItem(this.conversation);

  final Conversation conversation;
}
