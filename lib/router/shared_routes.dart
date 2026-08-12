import 'package:go_router/go_router.dart';

import '../ui/shared/views/qr_code_screen.dart';
import '../ui/shared/views/scan_screen.dart';
import '../ui/shared/views/search_screen.dart';
import 'app_paths.dart';

/// 共享域路由：搜索 / 扫码 / 二维码
List<RouteBase> buildSharedRoutes() {
  return [
    GoRoute(
      path: AppPaths.search,
      builder: (context, state) => const SearchScreen(),
    ),
    GoRoute(
      path: AppPaths.scan,
      builder: (context, state) => const ScanScreen(),
    ),
    GoRoute(
      path: AppPaths.qr,
      builder: (context, state) {
        final query = state.uri.queryParameters;
        return QrCodeScreen(
          title: query['title'] ?? '二维码',
          data: query['data'] ?? '',
          subtitle: query['subtitle'],
        );
      },
    ),
  ];
}
