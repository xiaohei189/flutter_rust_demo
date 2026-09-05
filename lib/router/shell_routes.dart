import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../ui/chat/views/chat_list_screen.dart';
import '../ui/contacts/views/contacts_screen.dart';
import '../ui/shell/placeholder_tab_screen.dart';
import '../ui/workbench/views/workbench_screen.dart';
import '../ui/shell/main_screen.dart';
import 'app_paths.dart';

/// 主框架路由 - StatefulShellRoute 底部导航
///
/// 六个 Tab（消息/通讯录/日历/工作台/云文档/更多）各占一个 branch，
/// 拥有独立导航栈，支持 deep-link（如 /main/contacts）与系统返回键逐层回退。
/// 日历/云文档/更多暂为占位页，保持与设计稿一致的 Tab 布局。
List<RouteBase> buildShellRoutes() {
  return [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          MainScreen(navigationShell: navigationShell),
      branches: [
        // Tab1: 消息
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppPaths.tabChat,
              builder: (context, state) => const ChatListScreen(),
            ),
          ],
        ),
        // Tab2: 通讯录
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppPaths.tabContacts,
              builder: (context, state) => const ContactsScreen(),
            ),
          ],
        ),
        // Tab3: 日历（占位）
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppPaths.tabCalendar,
              builder: (context, state) =>
                  const PlaceholderTabScreen(title: '日历', icon: Icons.calendar_month_outlined),
            ),
          ],
        ),
        // Tab4: 工作台
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppPaths.tabWorkbench,
              builder: (context, state) => const WorkbenchScreen(),
            ),
          ],
        ),
        // Tab5: 云文档（占位）
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppPaths.tabCloud,
              builder: (context, state) =>
                  const PlaceholderTabScreen(title: '云文档', icon: Icons.cloud_outlined),
            ),
          ],
        ),
        // Tab6: 更多（占位）
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppPaths.tabMore,
              builder: (context, state) =>
                  const PlaceholderTabScreen(title: '更多', icon: Icons.more_horiz),
            ),
          ],
        ),
      ],
    ),
  ];
}
