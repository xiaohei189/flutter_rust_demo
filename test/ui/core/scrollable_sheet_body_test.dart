import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_rust_demo/ui/core/theme/app_theme.dart';
import 'package:flutter_rust_demo/ui/core/widgets/scrollable_sheet_body.dart';
import 'package:flutter_rust_demo/ui/groups/widgets/group_dialogs.dart';

Widget _host(Widget child) => MaterialApp(
  theme: AppTheme.lightTheme,
  home: Scaffold(body: child),
);

/// 模拟横屏/小窗口：可用高度仅 300dp，弹窗高度上限约屏高 9/16。
void _useShortWindow(WidgetTester tester) {
  tester.view.physicalSize = const Size(640, 300);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('小窗口下内容超高时弹窗可滚动且不溢出', (tester) async {
    _useShortWindow(tester);
    String? tapped;
    await tester.pumpWidget(
      _host(
        ScrollableSheetBody(
          children: [
            for (var i = 0; i < 6; i++)
              ListTile(title: Text('item-$i'), onTap: () => tapped = 'item-$i'),
          ],
        ),
      ),
    );

    expect(
      tester.takeException(),
      isNull,
      reason: '内容超高时不应 RenderFlex overflow',
    );
    expect(find.text('item-5'), findsOneWidget);

    await tester.ensureVisible(find.text('item-5'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('item-5'));
    await tester.pump();

    expect(tapped, 'item-5', reason: '滚动到最后一项后应可点击');
    expect(tester.takeException(), isNull);
  });

  testWidgets('群管理弹窗在 640x300 窗口可滚到「解散群组」', (tester) async {
    _useShortWindow(tester);
    String? action;
    await tester.pumpWidget(
      _host(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              action = await showGroupManageSheet(context);
            },
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: '群管理弹窗在横屏高度下不应溢出');
    expect(find.text('全员禁言'), findsOneWidget);

    await tester.ensureVisible(find.text('解散群组'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('解散群组'));
    await tester.pumpAndSettle();

    expect(action, 'dismiss');
    expect(tester.takeException(), isNull);
  });
}
