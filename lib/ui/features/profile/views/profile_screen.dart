import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../models/user.dart';
import '../../../../providers/user_profile_provider.dart';
import '../../../../router/app_router.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/list_row.dart';
import '../../../../widgets/user_avatar.dart';
import 'qr_code_screen.dart';

/// 个人中心页面
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(userProfileProvider);
    final notifier = ref.read(userProfileProvider.notifier);
    final avatarUrl = notifier.getDisplayAvatarUrl();

    // 使用用户资料中的信息
    final userName = state.nickname.isNotEmpty
        ? state.nickname
        : (state.profile?.userId.isNotEmpty == true
              ? state.profile!.userId
              : '我');
    final userId = state.profile?.userId ?? '';

    final displayUser = User(
      id: userId,
      name: userName,
      avatar: avatarUrl,
      status: '在线',
    );

    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: ListView(
        children: [
          // 用户信息卡片
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                UserAvatar(user: displayUser, radius: 40),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayUser.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'ID: ${displayUser.id}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // QR 码按钮
                Material(
                  color: Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      if (userId.isNotEmpty) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => QrCodeScreen(
                              title: '我的二维码',
                              data: userId,
                              subtitle: userName,
                            ),
                          ),
                        );
                      }
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(10),
                      child: Icon(
                        Icons.qr_code,
                        size: 28,
                        color: AppTheme.textPrimaryColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // 功能列表
          _buildMenuItem(
            Icons.settings,
            '设置',
            () => AppRouter.goToAccountSettings(context),
          ),
          _buildMenuItem(
            Icons.notifications,
            '通知',
            () => AppRouter.goToAccountSettings(context),
          ),
          _buildMenuItem(
            Icons.privacy_tip,
            '隐私',
            () => AppRouter.goToBlacklist(context),
          ),
          _buildMenuItem(Icons.help, '帮助与反馈', () => _showHelp(context)),
          _buildMenuItem(Icons.info, '关于', () => _showAbout(context)),
        ],
      ),
    );
  }

  void _showHelp(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('帮助与反馈'),
        content: const Text('遇到问题请提供操作步骤与日志。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  void _showAbout(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('关于我们'),
        content: const Text('OpenIM Flutter Rust 示例应用\n版本 1.0.0'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String title, VoidCallback onTap) {
    return ListRow(
      leading: Icon(icon, size: 24, color: AppTheme.textPrimaryColor),
      label: title,
      showArrow: true,
      onTap: onTap,
    );
  }
}
