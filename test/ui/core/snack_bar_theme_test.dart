import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_rust_demo/ui/core/theme/app_theme.dart';

void main() {
  testWidgets('全局 SnackBar 使用深色胶囊样式', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('群组创建成功')));
              },
              child: const Text('显示'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('显示'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final theme = AppTheme.lightTheme.snackBarTheme;
    expect(theme.behavior, SnackBarBehavior.floating);
    expect(
      theme.backgroundColor,
      AppColors.light.textPrimary.withValues(alpha: 0.92),
    );
    final shape = theme.shape;
    expect(shape, isA<RoundedRectangleBorder>());
    expect(
      (shape as RoundedRectangleBorder).borderRadius,
      const BorderRadius.all(Radius.circular(AppTheme.radiusPill)),
    );
    expect(find.text('群组创建成功'), findsOneWidget);
  });
}
