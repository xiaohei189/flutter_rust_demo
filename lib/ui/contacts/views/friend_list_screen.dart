import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../domain/models/friend.dart';
import '../../../../domain/models/user.dart';
import '../../../../providers/providers.dart';
import '../../../../router/app_router.dart';
import '../../../../ui/core/widgets/user_avatar.dart';
import '../../../../ui/core/widgets/state_views.dart';
import '../../../../l10n/app_localizations.dart';
import '../view_models/friend_list_view_model.dart';

/// 好友列表页面
class FriendListScreen extends ConsumerStatefulWidget {
  const FriendListScreen({super.key});

  @override
  ConsumerState<FriendListScreen> createState() => _FriendListScreenState();
}

class _FriendListScreenState extends ConsumerState<FriendListScreen> {
  @override
  Widget build(BuildContext context) {
    final friendState = ref.watch(friendListProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)?.friendListTitle ?? '好友列表'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => context.push('/search'),
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

    if (friendState.friends.isEmpty) {
      return const EmptyState(icon: Icons.person_off_outlined, title: '暂无好友');
    }

    return ListView.builder(
      itemCount: friendState.friends.length,
      itemBuilder: (context, index) {
        final friend = friendState.friends[index];
        final displayName = friend.displayName;

        return ListTile(
          leading: UserAvatar(user: _friendToUser(friend), radius: 22),
          title: Text(
            displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: friend.remark.isNotEmpty
              ? Text(
                  friend.nickname,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF8E8E93),
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
      },
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
              leading: const Icon(Icons.person, color: Color(0xFF007AFF)),
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
              leading: const Icon(Icons.message, color: Color(0xFF07C160)),
              title: const Text('发消息'),
              onTap: () {
                Navigator.pop(context);
                final currentUserId =
                    ref.read(userProfileProvider).profile?.userId ?? '';
                final ids = [currentUserId, friend.userId]..sort();
                final conversationId = 'si_${ids[0]}_${ids[1]}';
                AppRouter.goToChatDetailById(context, conversationId);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('删除好友', style: TextStyle(color: Colors.red)),
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
            child: const Text('删除', style: TextStyle(color: Colors.red)),
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
