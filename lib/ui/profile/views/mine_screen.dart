import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/user.dart';
import '../../../l10n/app_localizations.dart';
import '../../../router/app_router.dart';
import '../../../ui/core/theme/app_theme.dart';
import '../../../ui/core/widgets/user_avatar.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/user_profile_provider.dart';
import '../widgets/mine_menu.dart';

/// “我的”页面：用户信息 + 设置菜单。
class MineScreen extends ConsumerWidget {
  const MineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final profileState = ref.watch(userProfileViewProvider);
    final notifier = ref.read(userProfileProvider.notifier);

    final avatarUrl = notifier.getDisplayAvatarUrl();
    final nickname = profileState.nickname.isNotEmpty
        ? profileState.nickname
        : (profileState.profile?.userId.isNotEmpty == true
              ? profileState.profile!.userId
              : '未登录');

    final currentUser = User(
      id: profileState.profile?.userId ?? '',
      name: nickname,
      avatar: avatarUrl,
      status: null,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)?.tabMine ?? '我的'),
      ),
      body: ListView(
        children: [
          GestureDetector(
            onTap: () => AppRouter.goToMyProfile(context),
            child: Container(
              color: colors.surface,
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  UserAvatar(user: currentUser, radius: 32),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nickname,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: colors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'ID: ${profileState.profile?.userId ?? ''}',
                          style: TextStyle(
                            fontSize: 13,
                            color: colors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: colors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          MineMenuSection(
            children: [
              MineMenuItem(
                icon: Icons.person_outline,
                label: '个人信息',
                onTap: () => AppRouter.goToMyProfile(context),
              ),
              MineMenuItem(
                icon: Icons.settings_outlined,
                label: '账号设置',
                onTap: () => AppRouter.goToAccountSettings(context),
              ),
              MineMenuItem(
                icon: Icons.block_outlined,
                label: '黑名单',
                onTap: () => AppRouter.goToBlacklist(context),
              ),
              MineMenuItem(
                icon: Icons.info_outline,
                label: '关于我们',
                onTap: () => _showAboutDialog(context),
              ),
            ],
          ),
          const SizedBox(height: 12),
          MineMenuSection(
            children: [
              MineMenuItem(
                icon: Icons.logout,
                label: '退出登录',
                iconColor: colors.danger,
                labelColor: colors.danger,
                onTap: () => _showLogoutDialog(context, ref),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('关于我们'),
        content: const Text(
          'OpenIM Flutter Rust 示例应用\n版本 1.0.0\n\n基于 Rust SDK + flutter_rust_bridge 构建',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('确定要退出登录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(authViewModelProvider.notifier).logout();
              if (context.mounted) {
                AppRouter.goToLogin(context);
              }
            },
            child: Text(
              '确定',
              style: TextStyle(color: context.appColors.danger),
            ),
          ),
        ],
      ),
    );
  }
}
