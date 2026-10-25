import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../chat/mappers/message_display.dart';
import '../../chat/utils/conversation_display.dart' show latestMessagePreview;
import '../../../domain/models/conversation.dart';
import '../../../domain/models/friend_search_result.dart';
import '../../../domain/models/group.dart';
import '../../../domain/models/user.dart';
import '../../../domain/models/chat_session_type.dart' show ChatSessionType;
import '../../../domain/models/message_search_result.dart'
    show MessageSearchResult;
import '../../../router/app_router.dart';
import '../../../ui/core/theme/app_theme.dart';
import '../../../ui/core/widgets/user_avatar.dart';
import '../../../l10n/app_localizations.dart';
import '../../chat/providers/message_service_provider.dart';
import '../../contacts/widgets/contact_pick_item.dart';
import '../providers/search_provider.dart';
import '../view_models/search_view_model.dart';
import '../widgets/category_chip.dart';

/// 全屏搜索页面：输入、分类与结果展示。
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      ref
          .read(searchViewModelProvider.notifier)
          .onQueryChanged(_controller.text);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(searchViewModelProvider);

    return Scaffold(
      backgroundColor: context.appColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // 搜索栏 + 取消
            Container(
              color: context.appColors.surface,
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _rememberQuery(),
                      decoration: InputDecoration(
                        hintText:
                            AppLocalizations.of(context)?.searchHint ?? '搜索',
                        hintStyle: TextStyle(
                          color: context.appColors.textSecondary,
                          fontSize: 16,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          size: 22,
                          color: context.appColors.textSecondary.withValues(
                            alpha: 0.8,
                          ),
                        ),
                        suffixIcon: state.query.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: _controller.clear,
                              )
                            : null,
                        filled: true,
                        fillColor: context.appColors.background,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusMd,
                          ),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => AppRouter.goBack(context),
                    child: Text(
                      AppLocalizations.of(context)?.cancel ?? '取消',
                      style: TextStyle(
                        color: context.appColors.primary,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // 分类 Tab
            Container(
              color: context.appColors.surface,
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
              child: Row(
                children: [
                  CategoryChip(
                    label: AppLocalizations.of(context)?.searchMessages ?? '消息',
                    isSelected: state.category == SearchCategory.message,
                    onTap: () => ref
                        .read(searchViewModelProvider.notifier)
                        .setCategory(SearchCategory.message),
                  ),
                  const SizedBox(width: 8),
                  CategoryChip(
                    label: '会话',
                    isSelected: state.category == SearchCategory.conversations,
                    onTap: () => ref
                        .read(searchViewModelProvider.notifier)
                        .setCategory(SearchCategory.conversations),
                  ),
                  const SizedBox(width: 8),
                  CategoryChip(
                    label:
                        AppLocalizations.of(context)?.searchContacts ?? '联系人',
                    isSelected: state.category == SearchCategory.contacts,
                    onTap: () => ref
                        .read(searchViewModelProvider.notifier)
                        .setCategory(SearchCategory.contacts),
                  ),
                  const SizedBox(width: 8),
                  CategoryChip(
                    label: AppLocalizations.of(context)?.searchGroups ?? '群组',
                    isSelected: state.category == SearchCategory.groups,
                    onTap: () => ref
                        .read(searchViewModelProvider.notifier)
                        .setCategory(SearchCategory.groups),
                  ),
                ],
              ),
            ),
            // 内容区
            Expanded(
              child: state.query.isEmpty
                  ? _buildEmptyHint()
                  : _buildResults(state),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyHint() {
    final history = ref.watch(searchViewModelProvider.select((s) => s.history));
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      children: [
        if (history.isNotEmpty) ...[
          Row(
            children: [
              const Text(
                '最近搜索',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              TextButton(
                onPressed: () =>
                    ref.read(searchViewModelProvider.notifier).clearHistory(),
                child: const Text('清空'),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final item in history)
                ActionChip(
                  label: Text(
                    item,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onPressed: () {
                    _controller.text = item;
                    _controller.selection = TextSelection.collapsed(
                      offset: item.length,
                    );
                    _focusNode.requestFocus();
                  },
                ),
            ],
          ),
          const SizedBox(height: 32),
        ],
        Icon(
          Icons.manage_search_rounded,
          size: 80,
          color: context.appColors.textSecondary.withValues(alpha: 0.3),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            '输入关键词进行查询',
            style: TextStyle(
              fontSize: 15,
              color: context.appColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNoResults(SearchState state) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 64,
            color: context.appColors.textSecondary.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            '没有找到「${state.query}」相关结果',
            style: TextStyle(
              fontSize: 15,
              color: context.appColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResults(SearchState state) {
    if (state.searching) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            state.error!,
            style: TextStyle(color: context.appColors.danger),
          ),
        ),
      );
    }

    switch (state.category) {
      case SearchCategory.message:
        if (state.messageResults.isEmpty) return _buildNoResults(state);
        return ListView.builder(
          padding: EdgeInsets.zero,
          itemCount: state.messageResults.length,
          itemBuilder: (_, i) => _buildMessageItem(state.messageResults[i]),
        );
      case SearchCategory.conversations:
        if (state.conversationResults.isEmpty) return _buildNoResults(state);
        return ListView.builder(
          padding: EdgeInsets.zero,
          itemCount: state.conversationResults.length,
          itemBuilder: (_, i) =>
              _buildConversationItem(state.conversationResults[i]),
        );
      case SearchCategory.contacts:
        if (state.friendResults.isEmpty) return _buildNoResults(state);
        return ListView.builder(
          padding: EdgeInsets.zero,
          itemCount: state.friendResults.length,
          itemBuilder: (_, i) => _buildFriendItem(state.friendResults[i]),
        );
      case SearchCategory.groups:
        if (state.groupResults.isEmpty) return _buildNoResults(state);
        return ListView.builder(
          padding: EdgeInsets.zero,
          itemCount: state.groupResults.length,
          itemBuilder: (_, i) => _buildGroupItem(state.groupResults[i]),
        );
    }
  }

  Widget _buildMessageItem(MessageSearchResult log) {
    return ListTile(
      leading: UserAvatar.fromUser(
        user: User(
          id: log.sendId,
          name: log.senderNickName,
          avatar: log.senderFaceUrl.isNotEmpty ? log.senderFaceUrl : null,
        ),
        radius: 20,
      ),
      title: Text(
        log.displayText,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        log.senderNickName.isNotEmpty ? log.senderNickName : log.sendId,
        style: const TextStyle(fontSize: 12),
      ),
      onTap: () {
        _rememberQuery();
        AppRouter.goToChatDetailById(context, log.conversationId);
      },
      onLongPress: () => _forwardMessage(log),
    );
  }

  /// 记录当前关键词到「最近搜索」（提交或点开结果时调用）。
  void _rememberQuery() {
    ref
        .read(searchViewModelProvider.notifier)
        .recordHistory(ref.read(searchViewModelProvider).query);
  }

  Widget _buildConversationItem(Conversation conversation) {
    final name = conversation.showName.isNotEmpty
        ? conversation.showName
        : conversation.conversationId;
    final preview = latestMessagePreview(conversation.latestMsg);
    return ListTile(
      key: ValueKey('search_conversation_${conversation.conversationId}'),
      leading: UserAvatar.fromUser(
        user: User(
          id: conversation.conversationId,
          name: name,
          avatar: conversation.faceUrl.isNotEmpty ? conversation.faceUrl : null,
        ),
        radius: 20,
      ),
      title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        preview.isEmpty ? '暂无消息' : preview,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12),
      ),
      onTap: () {
        _rememberQuery();
        AppRouter.goToChatDetailById(context, conversation.conversationId);
      },
    );
  }

  Future<void> _forwardMessage(MessageSearchResult log) async {
    final result = await AppRouter.goToContactPicker<List<ContactPickItem>>(
      context,
      title: '转发给',
    );
    if (result == null || result.isEmpty || !mounted) return;
    final target = result.first;
    try {
      await ref
          .read(messageServiceProvider.notifier)
          .forwardMessage(
            clientMsgId: log.clientMsgId,
            sourceId: target.id,
            sessionType: target.isGroup
                ? ChatSessionType.writeGroupChat
                : ChatSessionType.singleChat,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已转发给 ${target.name}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('转发失败: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Widget _buildFriendItem(FriendSearchResult item) {
    final name = item.nickname.isNotEmpty ? item.nickname : item.userId;
    return ListTile(
      leading: UserAvatar.fromUser(
        user: User(
          id: item.userId,
          name: name,
          avatar: item.faceUrl.isNotEmpty ? item.faceUrl : null,
        ),
        radius: 20,
      ),
      title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        item.remark.isNotEmpty ? item.remark : 'ID: ${item.userId}',
        style: const TextStyle(fontSize: 12),
      ),
      onTap: () {
        _rememberQuery();
        AppRouter.goToUserProfile(
          context,
          userId: item.userId,
          user: User(
            id: item.userId,
            name: name,
            avatar: item.faceUrl.isNotEmpty ? item.faceUrl : null,
          ),
        );
      },
    );
  }

  Widget _buildGroupItem(Group group) {
    return ListTile(
      leading: UserAvatar.fromUser(
        user: User(
          id: group.groupId,
          name: group.groupName,
          avatar: group.faceUrl.isNotEmpty ? group.faceUrl : null,
        ),
        radius: 20,
      ),
      title: Text(
        group.groupName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${group.memberCount}人',
        style: const TextStyle(fontSize: 12),
      ),
      onTap: () {
        _rememberQuery();
        AppRouter.goToGroupInfoById(context, group.groupId);
      },
    );
  }
}
