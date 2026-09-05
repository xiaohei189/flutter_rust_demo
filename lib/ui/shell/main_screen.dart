import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../chat/providers/conversation_provider.dart';
import '../core/theme/app_theme.dart';

/// 主页面 - 底部 Tab：消息、通讯录、工作台（飞书风格）
///
/// 由 [StatefulShellRoute] 提供 [navigationShell]，Tab 切换走路由，
/// 每个 Tab 拥有独立导航栈，支持 deep-link。
/// 个人中心统一在「消息」页左上角头像抽屉，不单独占 Tab。
///
/// [showBottomNav] 为 false 时隐藏自带的 BottomNavigationBar，用于
/// 自带底栏的页面，避免双底栏重叠。
class MainScreen extends StatelessWidget {
  const MainScreen({
    super.key,
    required this.navigationShell,
    this.showBottomNav = true,
  });

  final StatefulNavigationShell navigationShell;

  /// 是否显示自带的三项底部导航。预览对齐页时设为 false。
  final bool showBottomNav;

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
        label: '日历',
        icon: Icons.calendar_month_outlined,
        activeIcon: Icons.calendar_month,
      ),
      (
        label: l10n?.tabWorkbench ?? '工作台',
        icon: Icons.apps_outlined,
        activeIcon: Icons.apps,
      ),
      (
        label: '云文档',
        icon: Icons.cloud_outlined,
        activeIcon: Icons.cloud,
      ),
      (
        label: '更多',
        icon: Icons.more_horiz,
        activeIcon: Icons.more_horiz,
      ),
    ];
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: showBottomNav
          ? Consumer(
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
            )
          : null,
    );
  }
}
