import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_rust_demo/ui/chat/widgets/settings_dialogs.dart';

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('退出群组确认弹窗返回 true', (tester) async {
    bool? confirmed;
    await tester.pumpWidget(
      _host(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              confirmed = await confirmQuitGroup(context);
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('退出群组'), findsOneWidget);
    await tester.tap(find.text('退出'));
    await tester.pumpAndSettle();
    expect(confirmed, isTrue);
  });

  testWidgets('清空聊天记录确认弹窗返回 true', (tester) async {
    bool? confirmed;
    await tester.pumpWidget(
      _host(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              confirmed = await confirmClearChatHistory(context);
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('清空聊天记录'), findsOneWidget);
    await tester.tap(find.text('清空'));
    await tester.pumpAndSettle();
    expect(confirmed, isTrue);
  });

  testWidgets('文本编辑弹窗返回输入内容', (tester) async {
    String? result;
    await tester.pumpWidget(
      _host(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showChatSettingsTextDialog(
                context,
                title: '修改群昵称',
                hint: '请输入群昵称',
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '新昵称');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(result, '新昵称');
  });
}
