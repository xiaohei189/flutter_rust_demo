import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_rust_demo/ui/chat/widgets/composer/chat_input.dart';

void main() {
  testWidgets('首次点击输入框即建立文本输入连接（键盘可弹出）', (tester) async {
    final controller = TextEditingController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatInput(controller: controller, onSend: (_, _) {}),
        ),
      ),
    );

    // 初始折叠态：无输入连接
    expect(tester.testTextInput.hasAnyClients, isFalse, reason: '初始不应有文本输入连接');

    await tester.tap(find.byType(TextField));
    await tester.pump();

    // 首次点击后：连接建立（键盘可弹出）+ 焦点保持 + 工具栏展开
    expect(
      tester.testTextInput.hasAnyClients,
      isTrue,
      reason: '首次点击输入框后应建立文本输入连接（键盘可弹出）',
    );
    expect(
      tester.widget<TextField>(find.byType(TextField)).focusNode?.hasFocus,
      isTrue,
      reason: '首次点击后输入框应持有焦点',
    );
    expect(find.text('发送'), findsOneWidget, reason: '聚焦后应展开完整工具栏');
  });

  testWidgets('失焦后再点击仍能重建文本输入连接', (tester) async {
    final controller = TextEditingController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatInput(controller: controller, onSend: (_, _) {}),
        ),
      ),
    );

    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(tester.testTextInput.hasAnyClients, isTrue);

    // 点击输入区外失焦
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    expect(tester.testTextInput.hasAnyClients, isFalse, reason: '失焦后连接应关闭');

    // 再次点击：连接重建
    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(tester.testTextInput.hasAnyClients, isTrue, reason: '再次点击后连接应重建');
  });
}
