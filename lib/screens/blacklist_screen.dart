import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user.dart';
import '../providers/providers.dart';
import '../router/app_router.dart';
import '../src/rust/model/user.dart' show UserInfo;
import '../theme/app_theme.dart';
import '../widgets/user_avatar.dart';

/// 黑名单页面：展示已拉黑用户，支持移出黑名单。
class BlacklistScreen extends ConsumerStatefulWidget {
  const BlacklistScreen({super.key});

  @override
  ConsumerState<BlacklistScreen> createState() => _BlacklistScreenState();
}

class _BlacklistScreenState extends ConsumerState<BlacklistScreen> {
  Map<String, UserInfo> _users = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    await ref.read(blackListProvider.notifier).load();
    final ids = ref.read(blackListProvider).userIds;
    final client = ref.read(messageServiceProvider.notifier).client;
    if (client != null && ids.isNotEmpty) {
      try {
        final infos = await client.getUsersInfo(userIds: ids);
        _users = {for (final u in infos) u.userId: u};
      } catch (_) {
        _users = {};
      }
    } else {
      _users = {};
    }
    if (mounted) setState(() {});
  }

  Future<void> _removeBlack(String userId, String nickname) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('移出黑名单'),
        content: Text('确定将 $nickname 移出黑名单吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('移出'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(blackListProvider.notifier).removeBlack(userId);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(blackListProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('黑名单'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => AppRouter.goBack(context),
        ),
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.userIds.isEmpty
              ? const Center(child: Text('黑名单为空'))
              : ListView.separated(
                  itemCount: state.userIds.length,
                  separatorBuilder: (_, __) => const Divider(
                    height: 1,
                    indent: 64,
                    color: AppTheme.dividerColor,
                  ),
                  itemBuilder: (_, i) {
                    final userId = state.userIds[i];
                    final info = _users[userId];
                    final nickname = info?.nickname.isNotEmpty == true
                        ? info!.nickname
                        : userId;
                    final faceUrl = info?.faceUrl ?? '';
                    return ListTile(
                      leading: UserAvatar(
                        user: User(
                          id: userId,
                          name: nickname,
                          avatar: faceUrl.isNotEmpty ? faceUrl : null,
                        ),
                        radius: 20,
                      ),
                      title: Text(nickname, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                        'ID: $userId',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: TextButton(
                        onPressed: () => _removeBlack(userId, nickname),
                        child: const Text(
                          '移出',
                          style: TextStyle(color: AppTheme.primaryColor),
                        ),
                      ),
                      onTap: () => AppRouter.goToUserProfile(
                        context,
                        userId: userId,
                        user: User(id: userId, name: nickname, avatar: faceUrl.isNotEmpty ? faceUrl : null),
                      ),
                    );
                  },
                ),
    );
  }
}
