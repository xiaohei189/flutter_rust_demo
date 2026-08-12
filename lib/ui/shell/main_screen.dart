import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../chat/providers/conversation_provider.dart';
import '../core/theme/app_theme.dart';

/// 主页面 - 底部 Tab：消息、通讯录、发现、我的
///
/// 由 [StatefulShellRoute] 提供 [navigationShell]，Tab 切换走路由，
/// 每个 Tab 拥有独立导航栈，支持 deep-link。
class MainScreen extends StatelessWidget {
  const MainScreen({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tabs = [
      (
        label: l10n?.tabMessages ?? '消息',
        icon: Icons.chat_bubble_outline,
        activeIcon: Icons.chat_bubble,
      ),
      (
        label: l10n?.tabContacts ?? '通讯录',
        icon: Icons.people_outline,
        activeIcon: Icons.people,
      ),
      (
        label: l10n?.tabDiscover ?? '发现',
        icon: Icons.explore_outlined,
        activeIcon: Icons.explore,
      ),
      (
        label: l10n?.tabMine ?? '我的',
        icon: Icons.person_outline,
        activeIcon: Icons.person,
      ),
    ];
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Consumer(
        builder: (context, ref, child) {
          final totalUnread = ref.watch(totalUnreadCountProvider);
          final currentIndex = navigationShell.currentIndex;
          return BottomNavigationBar(
            currentIndex: currentIndex,
            onTap: (index) => navigationShell.goBranch(
              index,
              // 已在该 Tab 时保持当前栈，避免重复 push 根页面
              initialLocation: index == navigationShell.currentIndex,
            ),
            type: BottomNavigationBarType.fixed,
            items: [
              for (var i = 0; i < tabs.length; i++)
                BottomNavigationBarItem(
                  icon: i == 0 && totalUnread > 0
                      ? Badge(
                          label: Text(
                            totalUnread > 99 ? '99+' : '$totalUnread',
                            style: TextStyle(
                              fontSize: 10,
                              color: context.appColors.onPrimary,
                            ),
                          ),
                          child: Icon(tabs[i].icon),
                        )
                      : Icon(tabs[i].icon),
                  activeIcon: i == 0 && totalUnread > 0
                      ? Badge(
                          label: Text(
                            totalUnread > 99 ? '99+' : '$totalUnread',
                            style: TextStyle(
                              fontSize: 10,
                              color: context.appColors.onPrimary,
                            ),
                          ),
                          child: Icon(tabs[i].activeIcon),
                        )
                      : Icon(tabs[i].activeIcon),
                  label: tabs[i].label,
                ),
            ],
          );
        },
      ),
    );
  }
}

/// "我的"页面 - 用户信息 + 设置菜单
