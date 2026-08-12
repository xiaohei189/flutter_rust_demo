import 'package:go_router/go_router.dart';

import '../domain/models/user.dart';
import '../ui/profile/views/account_settings_screen.dart';
import '../ui/profile/views/my_profile_screen.dart'
    show MyProfileScreen, ProfileFieldEditScreen;
import '../ui/profile/views/user_profile_screen.dart';
import '../ui/shared/views/route_error_page.dart';
import 'app_paths.dart';

/// 个人资料域路由：我的资料 / 用户资料 / 账号设置 / 资料字段编辑
List<RouteBase> buildProfileRoutes() {
  return [
    GoRoute(
      path: AppPaths.myProfile,
      builder: (context, state) => const MyProfileScreen(),
    ),
    GoRoute(
      path: AppPaths.userProfile,
      builder: (context, state) {
        final userId = state.pathParameters['id'] ?? 'unknown';
        final user =
            state.extra as User? ??
            User(id: userId, name: userId, avatar: null, status: null);
        return UserProfileScreen(user: user, isCurrentUser: false);
      },
    ),
    GoRoute(
      path: AppPaths.accountSettings,
      builder: (context, state) => const AccountSettingsScreen(),
    ),
    GoRoute(
      path: AppPaths.profileEditField,
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        if (extra == null) {
          return const RouteErrorPage(message: '参数错误');
        }
        return ProfileFieldEditScreen(
          title: extra['title'] as String? ?? '编辑',
          hint: extra['hint'] as String? ?? '',
          initialValue: extra['initialValue'] as String? ?? '',
        );
      },
    ),
  ];
}
