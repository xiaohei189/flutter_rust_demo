import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_rust_demo/router/app_router.dart';
import 'package:flutter_rust_demo/ui/shared/views/route_error_page.dart';

void main() {
  group('AppRouter 路由匹配', () {
    late GoRouter router;

    setUp(() {
      router = AppRouter.createRouter(
        wsUrl: 'ws://localhost:10001',
        apiBaseUrl: 'http://localhost:10002',
      );
    });

    testWidgets('/main 应重定向到默认 Tab /main/chat', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );
      // SplashScreen 有异步初始化动画，用固定帧 pump 代替 pumpAndSettle
      await tester.pump(const Duration(milliseconds: 100));

      router.go('/main');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        '/main/chat',
      );
    });

    testWidgets('未知路径应显示 404 错误页', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      router.go('/non-existent-path');
      // 等待路由过渡动画完成（MaterialPageRoute 默认 300ms）
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(RouteErrorPage), findsOneWidget);
      expect(find.text('页面不存在'), findsOneWidget);
    });

    testWidgets('deep-link /main/contacts 应匹配通讯录 Tab', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      router.go('/main/contacts');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        '/main/contacts',
      );
    });
  });
}
