import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/user.dart';
import '../providers/providers.dart';
import '../src/rust/model/friend.dart';
import '../widgets/user_avatar.dart';

/// 好友列表页面
class FriendListScreen extends ConsumerStatefulWidget {
  const FriendListScreen({super.key});

  @override
  ConsumerState<FriendListScreen> createState() => _FriendListScreenState();
}

class _FriendListScreenState extends ConsumerState<FriendListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(friendListProvider.notifier).loadFriends();
    });
  }

  @override
  Widget build(BuildContext context) {
    final friendState = ref.watch(friendListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('好友列表'),
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
      return const Center(
        child: Text(
          '暂无好友',
          style: TextStyle(fontSize: 16, color: Color(0xFF8E8E93)),
        ),
      );
    }

    return ListView.builder(
      itemCount: friendState.friends.length,
      itemBuilder: (context, index) {
        final friend = friendState.friends[index];
        final displayName =
            friend.remark.isNotEmpty ? friend.remark : friend.nickname;

        return ListTile(
          leading: UserAvatar(
            user: _friendToUser(friend),
            radius: 22,
          ),
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
                  style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E93)),
                )
              : null,
          onTap: () {
            context.push('/profile/user/${friend.userId}',
                extra: _friendToUser(friend));
          },
          onLongPress: () => _showFriendOptions(friend),
        );
      },
    );
  }

  void _showFriendOptions(FriendInfo friend) {
    final displayName =
        friend.remark.isNotEmpty ? friend.remark : friend.nickname;

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
                context.push('/profile/user/${friend.userId}',
                    extra: _friendToUser(friend));
              },
            ),
            ListTile(
              leading: const Icon(Icons.message, color: Color(0xFF07C160)),
              title: const Text('发消息'),
              onTap: () {
                Navigator.pop(context);
                // TODO: 跳转到与该好友的聊天页面
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

  void _confirmDeleteFriend(FriendInfo friend) {
    final displayName =
        friend.remark.isNotEmpty ? friend.remark : friend.nickname;

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
              try {
                final client = ref
                    .read(messageServiceProvider.notifier)
                    .client;
                if (client != null) {
                  await client.deleteFriend(userId: friend.userId);
                  if (mounted) {
                    _onFriendDeleted();
                  }
                }
              } catch (e) {
                if (mounted) {
                  _onFriendDeleteFailed(e);
                }
              }
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _onFriendDeleted() {
    ref.read(friendListProvider.notifier).loadFriends();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('已删除好友'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _onFriendDeleteFailed(Object e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('删除失败: $e'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// FriendInfo -> User 转换
  static User _friendToUser(FriendInfo friend) {
    return User(
      id: friend.userId,
      name: friend.nickname,
      avatar: friend.faceUrl.isNotEmpty ? friend.faceUrl : null,
      avatarColorValue: 0xFF007AFF,
      avatarIconName: 'person',
    );
  }
}
