import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../domain/models/friend.dart';
import '../../../../domain/models/user.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../router/app_paths.dart';
import '../../../../router/app_router.dart';
import '../../../../providers/current_user_provider.dart';
import '../../../../ui/core/theme/app_icon_colors.dart';
import '../../../../ui/core/theme/app_theme.dart';
import '../../../../ui/core/widgets/state_views.dart';
import '../../../../ui/core/widgets/user_avatar.dart';
import '../providers/friend_provider.dart';
import '../utils/contact_index.dart';
import '../view_models/friend_list_view_model.dart';
import '../widgets/contact_index_bar.dart';

/// 好友列表页面
class FriendListScreen extends ConsumerStatefulWidget {
  const FriendListScreen({super.key});

  @override
  ConsumerState<FriendListScreen> createState() => _FriendListScreenState();
}

class _FriendListScreenState extends ConsumerState<FriendListScreen> {
  final TextEditingController _searchController = TextEditingController();

  /// 分组表头锚点：点右侧索引条时用它做 ensureVisible 跳转。
  final Map<String, GlobalKey> _sectionKeys = {};

  Timer? _bubbleTimer;
  String _query = '';
  String? _activeLetter;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _bubbleTimer?.cancel();
    _searchController.removeListener(_onQueryChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    final next = _searchController.text.trim();
    if (next == _query) return;
    setState(() => _query = next);
  }

  /// 索引跳转：把该分组表头滚到顶部，并浮出字母提示。
  void _jumpToLetter(String letter) {
    final sectionContext = _sectionKeys[letter]?.currentContext;
    if (sectionContext != null) {
      Scrollable.ensureVisible(
        sectionContext,
        duration: const Duration(milliseconds: 120),
        alignment: 0,
      );
    }
    _bubbleTimer?.cancel();
    setState(() => _activeLetter = letter);
  }

  /// 松手后 400ms 收起浮层字母（点按也算一次交互）。
  void _hideLetterBubble() {
    _bubbleTimer?.cancel();
    _bubbleTimer = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(() => _activeLetter = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final friendState = ref.watch(friendListProvider);

    return Scaffold(
      // 与「消息」「通讯录」同一套语汇：整幅白底铺行，分组靠表头底色 + 留白，不加分割线。
      backgroundColor: context.appColors.surface,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)?.friendListTitle ?? '好友列表'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => context.push(AppPaths.search),
          ),
        ],
      ),
      body: _buildBody(friendState),
    );
  }

  Widget _buildBody(FriendListState friendState) {
    if (friendState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final error = friendState.error;
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 56,
                color: context.appColors.danger,
              ),
              const SizedBox(height: 12),
              Text(
                error,
                textAlign: TextAlign.center,
                style: TextStyle(color: context.appColors.danger),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () =>
                    ref.read(friendListProvider.notifier).loadFriends(),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }

    if (friendState.friends.isEmpty) {
      return const EmptyState(icon: Icons.person_off_outlined, title: '暂无好友');
    }

    final filtered = _query.isEmpty
        ? friendState.friends
        : friendState.friends
              .where(
                (friend) => ContactIndex.matches(
                  query: _query,
                  displayName: friend.displayName,
                  nickname: friend.nickname,
                  userId: friend.userId,
                ),
              )
              .toList();

    return Column(
      children: [
        _buildSearchField(),
        Expanded(
          child: filtered.isEmpty
              ? const EmptyState(icon: Icons.search_off, title: '没有匹配的联系人')
              : _buildFriendList(filtered),
        ),
      ],
    );
  }

  /// 内嵌搜索框（对齐飞书通讯录：搜索框常驻列表顶部，不跳页）。
  Widget _buildSearchField() {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      child: TextField(
        controller: _searchController,
        textInputAction: TextInputAction.search,
        style: const TextStyle(fontSize: 15),
        decoration: InputDecoration(
          isDense: true,
          hintText: '搜索姓名 / 备注 / 拼音',
          prefixIcon: Icon(Icons.search, size: 20, color: colors.textSecondary),
          filled: true,
          fillColor: colors.background,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  /// 好友列表：搜索中平铺结果；否则按首字母分组 + 右侧索引条。
  Widget _buildFriendList(List<Friend> friends) {
    if (_query.isNotEmpty) {
      return ListView.builder(
        itemCount: friends.length,
        itemBuilder: (context, index) => _buildFriendTile(friends[index]),
      );
    }

    final groups = ContactIndex.group(friends, (friend) => friend.displayName);
    final entries = <_FriendListEntry>[];
    for (final group in groups.entries) {
      entries.add(
        _SectionEntry(
          letter: group.key,
          key: _sectionKeys.putIfAbsent(group.key, () => GlobalKey()),
        ),
      );
      entries.addAll(group.value.map(_FriendEntry.new));
    }

    return Stack(
      children: [
        ListView.builder(
          padding: const EdgeInsets.only(bottom: 16),
          itemCount: entries.length,
          itemBuilder: (context, index) => switch (entries[index]) {
            _SectionEntry(:final key, :final letter) => Container(
              key: key,
              child: _buildSectionHeader(letter),
            ),
            _FriendEntry(:final friend) => _buildFriendTile(friend),
          },
        ),
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          child: Center(
            child: ContactIndexBar(
              letters: groups.keys.toList(),
              activeLetter: _activeLetter,
              onLetterSelected: _jumpToLetter,
              onInteractionEnd: _hideLetterBubble,
            ),
          ),
        ),
        if (_activeLetter != null) ContactIndexBubble(letter: _activeLetter!),
      ],
    );
  }

  /// 分组表头：与「消息」列表的分组头同一套样式（浅底 + 小号灰字）。
  Widget _buildSectionHeader(String letter) {
    final colors = context.appColors;
    return Container(
      width: double.infinity,
      color: colors.background,
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
      child: Text(
        letter,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: colors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildFriendTile(Friend friend) {
    final displayName = friend.displayName;
    return ListTile(
      leading: UserAvatar.fromUser(user: _friendToUser(friend), radius: 22),
      title: Text(displayName, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: friend.remark.isNotEmpty
          ? Text(
              friend.nickname,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: context.appColors.textSecondary,
              ),
            )
          : null,
      onTap: () {
        context.push(
          '/profile/user/${friend.userId}',
          extra: _friendToUser(friend),
        );
      },
      onLongPress: () => _showFriendOptions(friend),
    );
  }

  void _showFriendOptions(Friend friend) {
    final displayName = friend.displayName;

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                displayName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: Icon(Icons.person, color: context.appColors.primary),
              title: const Text('查看资料'),
              onTap: () {
                Navigator.pop(context);
                context.push(
                  '/profile/user/${friend.userId}',
                  extra: _friendToUser(friend),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.message, color: AppIconColors.green),
              title: const Text('发消息'),
              onTap: () {
                Navigator.pop(context);
                final currentUserId = ref.read(currentUserIdProvider);
                final ids = [currentUserId, friend.userId]..sort();
                final conversationId = 'si_${ids[0]}_${ids[1]}';
                AppRouter.goToChatDetailById(context, conversationId);
              },
            ),
            ListTile(
              leading: Icon(
                Icons.delete_outline,
                color: context.appColors.danger,
              ),
              title: Text(
                '删除好友',
                style: TextStyle(color: context.appColors.danger),
              ),
              onTap: () {
                Navigator.pop(context);
                _confirmDeleteFriend(friend);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteFriend(Friend friend) {
    final displayName = friend.displayName;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除好友'),
        content: Text('确定要删除好友「$displayName」吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final ok = await ref
                  .read(friendListProvider.notifier)
                  .deleteFriend(friend.userId);
              if (!mounted) return;
              if (ok) {
                _onFriendDeleted();
              } else {
                _onFriendDeleteFailed();
              }
            },
            child: Text(
              '删除',
              style: TextStyle(color: context.appColors.danger),
            ),
          ),
        ],
      ),
    );
  }

  void _onFriendDeleted() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('已删除好友'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _onFriendDeleteFailed() {
    final error = ref.read(friendListProvider).error;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error ?? '删除失败'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Friend -> User 转换
  static User _friendToUser(Friend friend) {
    return User(
      id: friend.userId,
      name: friend.nickname,
      avatar: friend.faceUrl.isNotEmpty ? friend.faceUrl : null,
      avatarColorValue: 0xFF007AFF,
      avatarIconName: 'person',
    );
  }
}

/// 好友列表的一行：分组表头或好友。
sealed class _FriendListEntry {
  const _FriendListEntry();
}

class _SectionEntry extends _FriendListEntry {
  const _SectionEntry({required this.letter, required this.key});

  final String letter;
  final GlobalKey key;
}

class _FriendEntry extends _FriendListEntry {
  const _FriendEntry(this.friend);

  final Friend friend;
}
