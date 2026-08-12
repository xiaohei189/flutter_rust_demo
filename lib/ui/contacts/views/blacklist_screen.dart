import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/models/user.dart';
import '../../../../router/app_router.dart';
import '../../../../ui/core/theme/app_theme.dart';
import '../../../../ui/core/widgets/user_avatar.dart';
import '../../../../ui/core/widgets/state_views.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/friend_provider.dart';

/// 黑名单页面：展示已拉黑用户，支持移出黑名单。
class BlacklistScreen extends ConsumerStatefulWidget {
  const BlacklistScreen({super.key});

  @override
  ConsumerState<BlacklistScreen> createState() => _BlacklistScreenState();
}

class _BlacklistScreenState extends ConsumerState<BlacklistScreen> {
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

    final ok = await ref.read(blackListProvider.notifier).remove(userId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? '已移出黑名单' : '移出黑名单失败'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(blackListProvider);

    return Scaffold(
      backgroundColor: context.appColors.background,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)?.blacklistTitle ?? '黑名单'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => AppRouter.goBack(context),
        ),
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.users.isEmpty
          ? const EmptyState(icon: Icons.block_outlined, title: '黑名单为空')
          : ListView.separated(
              itemCount: state.users.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                indent: 64,
                color: context.appColors.divider,
              ),
              itemBuilder: (_, i) {
                final user = state.users[i];
                return ListTile(
                  leading: UserAvatar(
                    user: User(
                      id: user.userId,
                      name: user.nickname,
                      avatar: user.faceUrl.isNotEmpty ? user.faceUrl : null,
                    ),
                    radius: 20,
                  ),
                  title: Text(
                    user.nickname,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    'ID: ${user.userId}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: TextButton(
                    onPressed: () => _removeBlack(user.userId, user.nickname),
                    child: Text(
                      '移出',
                      style: TextStyle(color: context.appColors.primary),
                    ),
                  ),
                  onTap: () => AppRouter.goToUserProfile(
                    context,
                    userId: user.userId,
                    user: User(
                      id: user.userId,
                      name: user.nickname,
                      avatar: user.faceUrl.isNotEmpty ? user.faceUrl : null,
                    ),
                  ),
                );
              },
            ),
    );
  }
}
