import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_rust_demo/ui/chat/widgets/composer/chat_input.dart';
import 'package:flutter_rust_demo/ui/chat/widgets/composer/chat_input_field.dart';
import 'package:flutter_rust_demo/ui/chat/widgets/composer/emoji_panel.dart';

/// 键盘与表情面板的覆盖关系（对齐飞书实机录屏测得的过渡行为）：
///
/// - 键盘弹出时**不改变内容区尺寸**，只是从下往上盖住底部；
/// - 表情面板锚定屏幕底部、**原地不动**，被键盘覆盖；
/// - 只有输入行上浮到键盘之上，保证始终可输入。
///
/// 这里用固定屏幕尺寸 + 注入 viewInsets 的方式验证几何关系，
/// 断言只依赖「键盘高度」与「面板高度」的相对关系，因此对机型无关。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  const screenWidth = 400.0;
  const screenHeight = 800.0;

  /// 固定视图尺寸（逻辑 400x800），避免默认测试视图尺寸不同导致几何断言失真。
  void useFixedView(WidgetTester tester) {
    tester.view.physicalSize = const Size(screenWidth * 2, screenHeight * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
  }

  Widget host(TextEditingController controller, double keyboardHeight) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(screenWidth, screenHeight),
          viewInsets: EdgeInsets.only(bottom: keyboardHeight),
        ),
        child: Scaffold(
          // 与真实会话页同构：body 不随键盘缩放，键盘高度由输入区自己处理。
          resizeToAvoidBottomInset: false,
          body: Column(
            children: [
              const Expanded(child: SizedBox.expand()),
              ChatInput(
                controller: controller,
                onSend: (_, _) {},
                onAtMention: () {},
                keyboardInset: keyboardHeight,
              ),
            ],
          ),
        ),
      ),
    );
  }

  testWidgets('键盘弹出时输入行上浮到键盘之上，面板留在底部被覆盖', (tester) async {
    const keyboardHeight = 300.0;
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    useFixedView(tester);

    await tester.pumpWidget(host(controller, keyboardHeight));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('表情'));
    await tester.pumpAndSettle();

    final keyboardTop = screenHeight - keyboardHeight;
    final panelRect = tester.getRect(find.byType(EmojiPanel));
    final inputRowRect = tester.getRect(find.byType(ChatInputField));

    // 输入行整体在键盘上沿之上，保证键盘弹出时仍可输入。
    expect(
      inputRowRect.bottom,
      lessThanOrEqualTo(keyboardTop + 1),
      reason: '输入行应浮在键盘之上（输入行底边 ${inputRowRect.bottom}，键盘上沿 $keyboardTop）',
    );

    // 面板底边贴屏幕底边：说明面板没有被顶起，仍在原位。
    expect(panelRect.bottom, closeTo(screenHeight, 1), reason: '面板应锚定屏幕底部原位不动');

    // 面板上沿不低于键盘上沿 → 面板完全落在键盘覆盖范围内（被盖住而不是把输入行顶走）。
    expect(
      panelRect.top,
      greaterThanOrEqualTo(keyboardTop - 1),
      reason: '面板应位于键盘下方被覆盖（面板上沿 ${panelRect.top}，键盘上沿 $keyboardTop）',
    );
  });

  testWidgets('键盘收起时面板完整可见、输入行落在面板上沿', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    useFixedView(tester);

    await tester.pumpWidget(host(controller, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('表情'));
    await tester.pumpAndSettle();

    final panelRect = tester.getRect(find.byType(EmojiPanel));
    final inputRowRect = tester.getRect(find.byType(ChatInputField));

    expect(panelRect.bottom, closeTo(screenHeight, 1), reason: '键盘收起时面板仍贴屏幕底部');
    expect(
      inputRowRect.bottom,
      lessThanOrEqualTo(panelRect.top + 1),
      reason: '输入行应落在面板上沿之上（不遮挡面板）',
    );
  });

  // 覆盖多种键盘高度：比面板矮 / 与面板等高 / 比面板高。
  // 断言的是「输入行永远在键盘之上」「面板永远贴屏幕底部」这两条不变量，
  // 不依赖任何具体机型或键盘高度值 —— 实现侧也只使用注入的实测值。
  for (final keyboardHeight in <double>[0, 200, 300, 380]) {
    testWidgets('键盘高度 ${keyboardHeight.toInt()} 时不变量成立（多机型通用）', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      useFixedView(tester);

      await tester.pumpWidget(host(controller, keyboardHeight));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('表情'));
      await tester.pumpAndSettle();

      final keyboardTop = screenHeight - keyboardHeight;
      final panelRect = tester.getRect(find.byType(EmojiPanel));
      final inputRowRect = tester.getRect(find.byType(ChatInputField));

      expect(
        inputRowRect.bottom,
        lessThanOrEqualTo(keyboardTop + 1),
        reason: '输入行必须始终在键盘之上（kbd=$keyboardHeight）',
      );
      expect(
        panelRect.bottom,
        closeTo(screenHeight, 1),
        reason: '面板必须始终锚定屏幕底部（kbd=$keyboardHeight）',
      );
      // 键盘不高于面板时，面板全部落在键盘上沿以下（被键盘覆盖）。
      if (keyboardHeight >= 300) {
        expect(
          panelRect.top,
          greaterThanOrEqualTo(keyboardTop - 1),
          reason: '键盘不低于面板时，面板应完全落在覆盖区内（kbd=$keyboardHeight）',
        );
      }
    });
  }
}
