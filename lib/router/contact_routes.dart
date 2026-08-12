import 'package:go_router/go_router.dart';

import '../ui/contacts/views/add_contact_screen.dart';
import '../ui/contacts/views/blacklist_screen.dart';
import '../ui/contacts/views/contact_picker_screen.dart';
import '../ui/contacts/views/friend_list_screen.dart';
import '../ui/contacts/views/friend_requests_screen.dart';
import '../ui/contacts/views/friend_setup_screen.dart';
import 'app_paths.dart';

/// 联系人域路由：好友列表 / 好友申请 / 好友设置 / 添加联系人 / 联系人选择器 / 黑名单
List<RouteBase> buildContactRoutes() {
  return [
    GoRoute(
      path: AppPaths.friendList,
      builder: (context, state) => const FriendListScreen(),
    ),
    GoRoute(
      path: AppPaths.friendRequests,
      builder: (context, state) => const FriendRequestsScreen(),
    ),
    GoRoute(
      path: AppPaths.friendSetup,
      builder: (context, state) {
        final userId = state.pathParameters['userId'];
        return FriendSetupScreen(userId: userId ?? '');
      },
    ),
    GoRoute(
      path: AppPaths.addContact,
      builder: (context, state) => const AddContactScreen(),
    ),
    GoRoute(
      path: AppPaths.contactPicker,
      builder: (context, state) {
        final mode = state.uri.queryParameters['mode'] ?? 'forward';
        final title = state.uri.queryParameters['title'] ?? '';
        final multiSelect = mode == 'group';
        return ContactPickerScreen(
          multiSelect: multiSelect,
          title: title.isNotEmpty ? title : (multiSelect ? '选择群成员' : '选择联系人'),
        );
      },
    ),
    GoRoute(
      path: AppPaths.blacklist,
      builder: (context, state) => const BlacklistScreen(),
    ),
  ];
}
