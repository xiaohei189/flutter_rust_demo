import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/user_profile_provider.dart';
import '../router/app_router.dart';
import '../screens/my_profile_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/user_avatar.dart';
import '../models/user.dart';

/// 个人资料左侧抽屉（参考飞书风格）
/// 从左侧滑入，占满屏幕高度，宽度约 80%
class ProfileDrawerScreen extends ConsumerWidget {
  const ProfileDrawerScreen({
    super.key,
    this.onOpenMyProfile,
  });

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
                        children: [
                          UserAvatar(user: currentUser, radius: 32),
                          const Spacer(),
                          // +状态 按钮
                          OutlinedButton.icon(
                            onPressed: () {},
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('状态'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.primaryColor,
                              side: BorderSide(
                                color: AppTheme.primaryColor.withValues(alpha: 0.4),
                              ),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              textStyle: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
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
                                  // TODO: 打开我的二维码页面
                                },
                                child: const Padding(
                                  padding: EdgeInsets.all(8),
                                  child: Icon(Icons.qr_code_2, size: 22,
                                      color: AppTheme.textPrimaryColor),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.chevron_right, size: 22,
                                color: AppTheme.textSecondaryColor.withValues(alpha: 0.4)),
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
                            color: AppTheme.textSecondaryColor.withValues(alpha: 0.7),
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
                            onTap: () {},
                          ),
                          _MenuItem(
                            icon: Icons.account_balance_wallet_outlined,
                            label: '钱包',
                            iconColor: const Color(0xFFFF9500),
                            onTap: () {},
                          ),
                          _MenuItem(
                            icon: Icons.star_outline,
                            label: '收藏',
                            iconColor: const Color(0xFFFFCC00),
                            onTap: () {},
                          ),
                          _MenuItem(
                            icon: Icons.people_outline,
                            label: '登录更多账号',
                            onTap: () {},
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Divider(height: 24),
                          ),
                          _MenuItem(
                            icon: Icons.headset_mic_outlined,
                            label: '帮助与客服',
                            onTap: () {},
                          ),
                          _MenuItem(
                            icon: Icons.devices_outlined,
                            label: '登录设备',
                            trailing: '1',
                            onTap: () {},
                          ),
                          _MenuItem(
                            icon: Icons.settings_outlined,
                            label: '设置',
                            onTap: () {},
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
    this.iconColor,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;
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
              Icon(icon, size: 24, color: iconColor ?? AppTheme.textPrimaryColor),
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
