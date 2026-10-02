import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_rust_demo/ui/chat/widgets/composer/chat_input.dart';

void main() {
  testWidgets('首次点击输入框即建立文本输入连接（键盘可弹出）', (tester) async {
    final controller = TextEditingController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatInput(
            controller: controller,
            onSend: (_, _) {},
            keyboardInset: 0,
          ),
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
    expect(find.byTooltip('发送'), findsOneWidget, reason: '聚焦后应展开完整工具栏');
  });

  testWidgets('失焦后再点击仍能重建文本输入连接', (tester) async {
    final controller = TextEditingController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatInput(
            controller: controller,
            onSend: (_, _) {},
            keyboardInset: 0,
          ),
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

  testWidgets('面板态带出键盘时输入行只上移不下移（真机抖动回归）', (tester) async {
    // 真机（Mi 10 Pro）实测：面板态点输入框后 viewInsets 逐帧
    // 0 → 62.5 → 263.6 → 312.7 → 321.8 地升起来。
    // 若把中间的 62.5 写进「记忆键盘高度」，面板占位会先塌到面板设计高度
    // （300）再被顶回去 —— 输入行和整个消息列表就会上下抖一次。
    const settledInsets = <double>[
      62.54545454545455,
      263.6363636363636,
      312.72727272727275,
      321.8181818181818,
    ];
    final controller = TextEditingController();
    final reportedHeight = ValueNotifier<double>(0);
    addTearDown(reportedHeight.dispose);

    Widget build(double keyboardInset) => MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            const Expanded(child: SizedBox.expand()),
            ChatInput(
              controller: controller,
              onSend: (_, _) {},
              keyboardInset: keyboardInset,
              heightNotifier: reportedHeight,
            ),
          ],
        ),
      ),
    );

    // 先让输入区记住该机型的键盘高度（进页面时键盘已弹起）。
    await tester.pumpWidget(build(settledInsets.last));
    // 键盘收起，再打开表情面板：此时面板占位 = 记忆的键盘高度。
    await tester.pumpWidget(build(0));
    await tester.tap(find.byTooltip('表情'));
    await tester.pumpAndSettle();

    final inputRow = find.byKey(const ValueKey('chat_input_row_area'));
    var previousTop = tester.getTopLeft(inputRow).dy;
    var previousHeight = reportedHeight.value;

    for (final inset in settledInsets) {
      await tester.pumpWidget(build(inset));
      await tester.pump();
      await tester.pump();

      final top = tester.getTopLeft(inputRow).dy;
      expect(
        top,
        lessThanOrEqualTo(previousTop + 0.01),
        reason: '键盘升起途中输入行下移了（inset=$inset，top $previousTop → $top）',
      );
      expect(
        reportedHeight.value,
        greaterThanOrEqualTo(previousHeight - 0.01),
        reason: '上报给消息列表的占位高度在键盘升起途中回缩了（inset=$inset）',
      );
      previousTop = top;
      previousHeight = reportedHeight.value;
    }
  });
}
