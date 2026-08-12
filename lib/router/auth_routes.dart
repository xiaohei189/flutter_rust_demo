import 'package:go_router/go_router.dart';

import '../ui/auth/views/login_screen.dart';
import '../ui/auth/views/register_screen.dart';
import '../ui/auth/views/splash_screen.dart';
import 'app_paths.dart';

/// 认证域路由：启动页 / 登录 / 注册
List<RouteBase> buildAuthRoutes({
  required String wsUrl,
  required String apiBaseUrl,
}) {
  return [
    GoRoute(
      path: AppPaths.splash,
      builder: (context, state) =>
          SplashScreen(wsUrl: wsUrl, apiBaseUrl: apiBaseUrl),
    ),
    GoRoute(
      path: AppPaths.login,
      builder: (context, state) =>
          LoginScreen(wsUrl: wsUrl, apiBaseUrl: apiBaseUrl),
    ),
    GoRoute(
      path: AppPaths.register,
      builder: (context, state) {
        final extra = state.extra as Map<String, String>? ?? const {};
        return RegisterScreen(
          wsUrl: extra['wsUrl'] ?? wsUrl,
          apiBaseUrl: extra['apiBaseUrl'] ?? apiBaseUrl,
        );
      },
    ),
  ];
}
