import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/user_profile_provider.dart';
import '../../../../router/app_router.dart';
import 'my_profile_screen.dart';
import 'qr_code_screen.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/user_avatar.dart';
import '../../../../models/user.dart';

/// 个人资料左侧抽屉（参考飞书风格）
/// 从左侧滑入，占满屏幕高度，宽度约 80%
class ProfileDrawerScreen extends ConsumerWidget {
  const ProfileDrawerScreen({super.key, this.onOpenMyProfile});

  final VoidCallback? onOpenMyProfile;

  User _buildCurrentUser(UserProfileState state, UserProfileNotifier notifier) {
    // 使用 getDisplayAvatarUrl() 获取头像，优先使用本地路径
    final avatarUrl = notifier.getDisplayAvatarUrl();
    return User(
      id: state.profile?.userId ?? '',
      name: state.nickname.isNotEmpty
          ? state.nickname
          : (state.profile?.userId.isNotEmpty == true
                ? state.profile!.userId
                : '我'),
      avatar: avatarUrl,
      status: null,
    );
  }

  String _getSignature(UserProfileState state) {
    if (state.signature.isNotEmpty) {
      return state.signature;
    }
    return '输入你的个性签名...';
  }

  void _showAbout(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('帮助与客服'),
        content: const Text(
          'OpenIM Flutter Rust 示例应用\n版本 1.0.0\n\n遇到问题请提供操作步骤与日志。',
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

  void _showDevices(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('登录设备'),
        content: const Text('当前登录设备：1 台（本机）'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final panelWidth = MediaQuery.of(context).size.width * 0.82;
    final state = ref.watch(userProfileProvider);
    final notifier = ref.read(userProfileProvider.notifier);
    final currentUser = _buildCurrentUser(state, notifier);
    final signature = _getSignature(state);

    return GestureDetector(
      onTap: () => AppRouter.goBack(context),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: GestureDetector(
          onTap: () {},
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: panelWidth,
              height: double.infinity,
              color: Colors.white,
              child: SafeArea(
                child: Column(
                  children: [
                    // 头部：头像 + 名字 + 状态按钮
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [UserAvatar(user: currentUser, radius: 32)],
                      ),
                    ),
                    // 名字 + 二维码 + 箭头（点击进入个人信息）
                    GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: () {
                        if (onOpenMyProfile != null) {
                          onOpenMyProfile!();
                          return;
                        }
                        // 用 Navigator.push 推入同一栈，抽屉保持在下方不动
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const MyProfileScreen(),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 14, 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                currentUser.name,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimaryColor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 12),
                            // QR 码独立热区
                            Material(
                              color: Colors.grey.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: () {
                                  if (currentUser.id.isNotEmpty) {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => QrCodeScreen(
                                          title: '我的二维码',
                                          data: currentUser.id,
                                          subtitle: currentUser.name,
                                        ),
                                      ),
                                    );
                                  }
                                },
                                child: const Padding(
                                  padding: EdgeInsets.all(8),
                                  child: Icon(
                                    Icons.qr_code_2,
                                    size: 22,
                                    color: AppTheme.textPrimaryColor,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.chevron_right,
                              size: 22,
                              color: AppTheme.textSecondaryColor.withValues(
                                alpha: 0.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // 签名
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          signature,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondaryColor.withValues(
                              alpha: 0.7,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    // 功能菜单
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        children: [
                          _MenuItem(
                            icon: Icons.person_outline,
                            label: '我的个人名片',
                            onTap: () {
                              if (onOpenMyProfile != null) {
                                onOpenMyProfile!();
                                return;
                              }
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const MyProfileScreen(),
                                ),
                              );
                            },
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Divider(height: 24),
                          ),
                          _MenuItem(
                            icon: Icons.headset_mic_outlined,
                            label: '帮助与客服',
                            onTap: () => _showAbout(context),
                          ),
                          _MenuItem(
                            icon: Icons.devices_outlined,
                            label: '登录设备',
                            trailing: '1',
                            onTap: () => _showDevices(context),
                          ),
                          _MenuItem(
                            icon: Icons.settings_outlined,
                            label: '设置',
                            onTap: () => AppRouter.goToAccountSettings(context),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              Icon(icon, size: 24, color: AppTheme.textPrimaryColor),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppTheme.textPrimaryColor,
                  ),
                ),
              ),
              if (trailing != null) ...[
                Text(
                  trailing!,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondaryColor,
                  ),
                ),
                const SizedBox(width: 4),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
