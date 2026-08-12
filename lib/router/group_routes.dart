import 'package:go_router/go_router.dart';

import '../ui/groups/views/create_group_screen.dart';
import '../ui/groups/views/group_applications_screen.dart';
import '../ui/groups/views/group_info_screen.dart';
import '../ui/groups/views/group_list_screen.dart';
import '../ui/shared/views/route_error_page.dart';
import 'app_paths.dart';

/// 群组域路由：群信息 / 群列表 / 创建群 / 群申请
List<RouteBase> buildGroupRoutes() {
  return [
    GoRoute(
      path: AppPaths.groupInfo,
      builder: (context, state) {
        final conversationId = state.pathParameters['id'];
        if (conversationId == null || conversationId.isEmpty) {
          return const RouteErrorPage(message: '会话ID不存在');
        }
        return GroupInfoScreen(conversationId: conversationId);
      },
    ),
    GoRoute(
      path: AppPaths.groupList,
      builder: (context, state) => const GroupListScreen(),
    ),
    GoRoute(
      path: AppPaths.createGroup,
      builder: (context, state) => const CreateGroupScreen(),
    ),
    GoRoute(
      path: AppPaths.groupApplications,
      builder: (context, state) => const GroupApplicationsScreen(),
    ),
  ];
}
