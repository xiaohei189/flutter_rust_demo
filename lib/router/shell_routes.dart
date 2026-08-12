import 'package:go_router/go_router.dart';

import '../ui/chat/views/chat_list_screen.dart';
import '../ui/contacts/views/contacts_screen.dart';
import '../ui/discover/views/discover_screen.dart';
import '../ui/profile/views/mine_screen.dart';
import '../ui/shell/main_screen.dart';
import 'app_paths.dart';

/// 主框架路由 - StatefulShellRoute 底部导航
///
/// 四个 Tab（消息/通讯录/发现/我的）各占一个 branch，
/// 拥有独立导航栈，支持 deep-link（如 /main/contacts）与系统返回键逐层回退。
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
        // Tab3: 发现
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppPaths.tabDiscover,
              builder: (context, state) => const DiscoverScreen(),
            ),
          ],
        ),
        // Tab4: 我的
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppPaths.tabMine,
              builder: (context, state) => const MineScreen(),
            ),
          ],
        ),
      ],
    ),
  ];
}
