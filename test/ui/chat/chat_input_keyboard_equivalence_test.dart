import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_rust_demo/ui/chat/widgets/composer/chat_input.dart';

/// 等价性验证：自研键盘让位 vs Flutter 框架标准行为。
///
/// 本方案没有用 `resizeToAvoidBottomInset: true`（因为要避开「键盘改变 body 尺寸 →
/// 消息列表重排」），而是自己按 `viewInsets` 把输入行抬起来。这带来一个必须回答的问题：
/// **自己算的位置，是否与框架标准算法一致？**
///
/// 这里把两种实现放在同一屏幕（400×800）+ 同一键盘高度下渲染，断言输入行区域的
/// 矩形**完全相同**。位置一致意味着：不论设备/输入法把 `viewInsets` 报成多少，
/// 输入行都会落在框架本来会放的位置 —— 这是「多机型通用」的强证据。
const _screenWidth = 400.0;
const _screenHeight = 800.0;

void useFixedView(WidgetTester tester) {
  tester.view.physicalSize = const Size(_screenWidth * 2, _screenHeight * 2);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
}

Widget host({
  required TextEditingController controller,
  required double keyboardHeight,
  required bool frameworkHandlesInset,
}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(
        size: const Size(_screenWidth, _screenHeight),
        viewInsets: EdgeInsets.only(bottom: keyboardHeight),
      ),
      child: Scaffold(
        // 框架方案：由 Scaffold 缩小 body 让出键盘空间，ChatInput 不需要自己算。
        // 自研方案：body 不缩，键盘高度交给 ChatInput 自己处理。
        resizeToAvoidBottomInset: frameworkHandlesInset,
        body: Column(
          children: [
            const Expanded(child: SizedBox.expand()),
            ConstrainedBox(
              constraints: const BoxConstraints(
                maxHeight: _screenHeight - kToolbarHeight,
              ),
              child: ChatInput(
                controller: controller,
                onSend: (_, _) {},
                onAtMention: () {},
                keyboardInset: frameworkHandlesInset ? 0 : keyboardHeight,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // 覆盖多种键盘高度：不同机型/不同输入法的高度差异都在这里被等价性覆盖。
  for (final keyboardHeight in <double>[200, 300, 380, 450]) {
    testWidgets('键盘高度 ${keyboardHeight.toInt()}：自研让位与框架标准行为位置一致', (
      tester,
    ) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      useFixedView(tester);

      await tester.pumpWidget(
        host(
          controller: controller,
          keyboardHeight: keyboardHeight,
          frameworkHandlesInset: true,
        ),
      );
      await tester.pumpAndSettle();
      final frameworkRowArea = tester.getRect(
        find.byKey(const ValueKey('chat_input_row_area')),
      );

      await tester.pumpWidget(
        host(
          controller: controller,
          keyboardHeight: keyboardHeight,
          frameworkHandlesInset: false,
        ),
      );
      await tester.pumpAndSettle();
      final customRowArea = tester.getRect(
        find.byKey(const ValueKey('chat_input_row_area')),
      );

      expect(
        customRowArea,
        frameworkRowArea,
        reason:
            '自研键盘让位应把输入行放在与框架标准行为完全相同的位置'
            '（kbd=$keyboardHeight）',
      );
    });
  }
}
