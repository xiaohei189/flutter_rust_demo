import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_rust_demo/ui/profile/providers/user_profile_provider.dart';
import 'package:flutter_rust_demo/ui/profile/view_models/user_profile_view_model.dart';
import 'package:flutter_rust_demo/ui/workbench/views/workbench_screen.dart';

void main() {
  testWidgets('工作台开关区不触发 ListTile ink 断言', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userProfileProvider.overrideWith(() => UserProfileNotifier()),
        ],
        child: const MaterialApp(home: WorkbenchScreen()),
      ),
    );
    await tester.pump();

    // ListTile 的背景与点击波纹画在最近的 Material 上；如果它和 Material 之间
    // 夹了一层带背景色的 Container，框架会报
    // "ListTile background color or ink splashes may be invisible"。
    expect(
      tester.takeException(),
      isNull,
      reason: '开关区必须用 Material 承载，不能夹带色 Container',
    );
    expect(find.text('全局免打扰'), findsOneWidget);
  });
}
