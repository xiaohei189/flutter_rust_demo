import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../router/app_router.dart';
import '../theme/app_theme.dart';
import '../widgets/user_avatar.dart';
import '../models/user.dart';
import 'chat_list_screen.dart';
import 'contacts_screen.dart';
import 'discover_screen.dart';

/// 主页面 - 底部 Tab：消息、通讯录、发现、我的
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  static const _tabs = [
    (widget: ChatListScreen(), label: '消息', icon: Icons.chat_bubble_outline, activeIcon: Icons.chat_bubble),
    (widget: ContactsScreen(), label: '通讯录', icon: Icons.people_outline, activeIcon: Icons.people),
    (widget: DiscoverScreen(), label: '发现', icon: Icons.explore_outlined, activeIcon: Icons.explore),
    (widget: _MineScreen(), label: '我的', icon: Icons.person_outline, activeIcon: Icons.person),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _tabs.map((e) => e.widget).toList(),
      ),
      bottomNavigationBar: Consumer(
        builder: (context, ref, child) {
          final totalUnread = ref.watch(totalUnreadCountProvider);
          return BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            type: BottomNavigationBarType.fixed,
            items: [
              for (var i = 0; i < _tabs.length; i++)
                BottomNavigationBarItem(
                  icon: i == 0 && totalUnread > 0
                      ? Badge(
                          label: Text(
                            totalUnread > 99 ? '99+' : '$totalUnread',
                            style: const TextStyle(fontSize: 10, color: Colors.white),
                          ),
                          child: Icon(_tabs[i].icon),
                        )
                      : Icon(_tabs[i].icon),
                  activeIcon: i == 0 && totalUnread > 0
                      ? Badge(
                          label: Text(
                            totalUnread > 99 ? '99+' : '$totalUnread',
                            style: const TextStyle(fontSize: 10, color: Colors.white),
                          ),
                          child: Icon(_tabs[i].activeIcon),
                        )
                      : Icon(_tabs[i].activeIcon),
                  label: _tabs[i].label,
                ),
            ],
          );
        },
      ),
    );
  }
}

/// "我的"页面 - 用户信息 + 设置菜单
class _MineScreen extends ConsumerWidget {
  const _MineScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileState = ref.watch(userProfileProvider);
    final notifier = ref.read(userProfileProvider.notifier);

    // 构建 User 对象用于 UserAvatar
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
      appBar: AppBar(title: const Text('我的')),
      body: ListView(
        children: [
          // 用户信息卡片
          GestureDetector(
            onTap: () => AppRouter.goToMyProfile(context),
            child: Container(
              color: Colors.white,
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
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimaryColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'ID: ${profileState.profile?.userId ?? ''}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondaryColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: AppTheme.textSecondaryColor,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // 菜单列表
          _MenuSection(
            children: [
              _MenuItem(
                icon: Icons.person_outline,
                label: '个人信息',
                onTap: () => AppRouter.goToMyProfile(context),
              ),
              _MenuItem(
                icon: Icons.settings_outlined,
                label: '账号设置',
                onTap: () => AppRouter.goToAccountSettings(context),
              ),
              _MenuItem(
                icon: Icons.block_outlined,
                label: '黑名单',
                onTap: () => AppRouter.goToBlacklist(context),
              ),
              _MenuItem(
                icon: Icons.info_outline,
                label: '关于我们',
                onTap: () => _showAboutDialog(context),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 退出登录按钮
          _MenuSection(
            children: [
              _MenuItem(
                icon: Icons.logout,
                label: '退出登录',
                iconColor: AppTheme.unreadRed,
                labelColor: AppTheme.unreadRed,
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
              try {
                final client =
                    ref.read(messageServiceProvider.notifier).client;
                await client?.logout();
              } catch (_) {}
              if (context.mounted) {
                AppRouter.goToLogin(context);
              }
            },
            child: const Text(
              '确定',
              style: TextStyle(color: AppTheme.unreadRed),
            ),
          ),
        ],
      ),
    );
  }
}

/// 菜单分区
class _MenuSection extends StatelessWidget {
  const _MenuSection({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(children: children),
    );
  }
}

/// 菜单项
class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
    this.labelColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? labelColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Icon(icon, size: 22, color: iconColor ?? AppTheme.textPrimaryColor),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    color: labelColor ?? AppTheme.textPrimaryColor,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 12,
                color: AppTheme.textSecondaryColor.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
