import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_rust_demo/ui/core/theme/app_theme.dart';
import 'package:flutter_rust_demo/ui/core/widgets/segmented_toggle.dart';

void main() {
  Future<List<Color?>> pumpAndCollectTrack(WidgetTester tester, ThemeData theme) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: SegmentedToggle(
            segments: const ['消息', '未读', '标记'],
            selectedIndex: 0,
            onChanged: (_) {},
          ),
        ),
      ),
    );
    return tester
        .widgetList<Container>(find.byType(Container))
        .map((c) => (c.decoration as BoxDecoration?)?.color)
        .toList();
  }

  testWidgets('浅色下分段控件轨道取 AppColors.light.segmentTrack', (tester) async {
    expect(
      await pumpAndCollectTrack(tester, AppTheme.lightTheme),
      contains(AppColors.light.segmentTrack),
    );
  });

  testWidgets('暗色下分段控件轨道取 AppColors.dark.segmentTrack（历史 bug：写死浅色）', (
    tester,
  ) async {
    final colors = await pumpAndCollectTrack(tester, AppTheme.darkTheme);
    expect(colors, contains(AppColors.dark.segmentTrack));
    // 浅色 token 的取值本身就是 #F0F1F4，所以这里断言「暗色下不再用它」
    expect(colors, isNot(contains(const Color(0xFFF0F1F4))));
  });
}
