import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_rust_demo/ui/chat/widgets/composer/attachment_panel.dart';
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

  Widget host(
    TextEditingController controller,
    double keyboardHeight, {
    Size size = const Size(screenWidth, screenHeight),
    TextScaler textScaler = TextScaler.noScaling,
  }) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          viewInsets: EdgeInsets.only(bottom: keyboardHeight),
          textScaler: textScaler,
        ),
        child: Scaffold(
          // 与真实会话页同构：body 不随键盘缩放，键盘高度由输入区自己处理。
          resizeToAvoidBottomInset: false,
          body: Column(
            children: [
              const Expanded(child: SizedBox.expand()),
              // 与真实页面一致的高度上限兜底：屏幕矮时由这里限制输入区，
              // 面板在内部按可用空间收缩（否则脚手架自身就会溢出）。
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: size.height - kToolbarHeight,
                ),
                child: ChatInput(
                  controller: controller,
                  onSend: (_, _) {},
                  onAtMention: () {},
                  keyboardInset: keyboardHeight,
                ),
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

  // 小屏 + 高键盘的边界：输入区总高会超过可用高度，此时面板应自行收缩，
  // 既不能溢出（RenderFlex overflowed），也必须保持「输入行在键盘之上」。
  // 这条覆盖小屏手机 / 大字体 / 巨屏输入法等机型差异。
  testWidgets('小屏 + 高键盘：面板收缩且不溢出，输入行仍在键盘之上', (tester) async {
    const smallWidth = 320.0;
    const smallHeight = 480.0;
    const keyboardHeight = 320.0;
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    tester.view.physicalSize = const Size(smallWidth * 2, smallHeight * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(smallWidth, smallHeight),
            viewInsets: EdgeInsets.only(bottom: keyboardHeight),
          ),
          child: Scaffold(
            resizeToAvoidBottomInset: false,
            body: Column(
              children: [
                const Expanded(child: SizedBox.expand()),
                // 与真实会话页一致的高度上限兜底。
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxHeight: smallHeight - kToolbarHeight,
                  ),
                  child: ChatInput(
                    controller: controller,
                    onSend: (_, _) {},
                    onAtMention: () {},
                    keyboardInset: keyboardHeight,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('表情'));
    await tester.pumpAndSettle();

    // 无异常即代表没有 RenderFlex overflow（Flutter 会把它报成测试失败）。
    final keyboardTop = smallHeight - keyboardHeight;
    final inputRowRect = tester.getRect(find.byType(ChatInputField));

    // 这个尺寸下「输入行区 + 键盘」已超过可用高度，物理上放不下整块，
    // 因此只要求最关键的一点：**输入框胶囊本身完整可见**（在键盘之上，能正常打字）。
    expect(
      inputRowRect.bottom,
      lessThanOrEqualTo(keyboardTop + 1),
      reason: '小屏高键盘时输入框必须完整可见（在键盘之上）',
    );
    expect(inputRowRect.top, greaterThanOrEqualTo(0), reason: '输入行不能被挤出屏幕顶部');
    expect(
      inputRowRect.bottom,
      lessThanOrEqualTo(smallHeight),
      reason: '输入行不能超出屏幕底部',
    );
  });

  // 横屏：聊天页可用高度骤减（屏高约 392），键盘占掉一半以上。
  // 面板会按剩余空间收缩，但输入框必须仍然完整可见。
  testWidgets('横屏 + 键盘：面板收缩、输入框仍完整可见', (tester) async {
    const landscapeWidth = 851.0;
    const landscapeHeight = 392.0;
    const keyboardHeight = 200.0;
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    tester.view.physicalSize = const Size(
      landscapeWidth * 2,
      landscapeHeight * 2,
    );
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      host(
        controller,
        keyboardHeight,
        size: const Size(landscapeWidth, landscapeHeight),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('表情'));
    await tester.pumpAndSettle();

    final keyboardTop = landscapeHeight - keyboardHeight;
    final inputRowRect = tester.getRect(find.byType(ChatInputField));
    expect(
      inputRowRect.bottom,
      lessThanOrEqualTo(keyboardTop + 1),
      reason: '横屏下输入框必须完整可见（在键盘之上）',
    );
    expect(
      inputRowRect.top,
      greaterThanOrEqualTo(0),
      reason: '横屏下输入框不能被挤出屏幕顶部',
    );
  });

  // 无障碍大字体（1.8x）：输入行变高，输入区更容易超出可用高度。
  testWidgets('大字体（1.8x）+ 键盘：不溢出且输入框完整可见', (tester) async {
    const keyboardHeight = 300.0;
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    useFixedView(tester);

    await tester.pumpWidget(
      host(
        controller,
        keyboardHeight,
        textScaler: const TextScaler.linear(1.8),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('表情'));
    await tester.pumpAndSettle();

    final keyboardTop = screenHeight - keyboardHeight;
    final inputRowRect = tester.getRect(find.byType(ChatInputField));
    expect(
      inputRowRect.bottom,
      lessThanOrEqualTo(keyboardTop + 1),
      reason: '大字体下输入框必须完整可见（在键盘之上）',
    );
    expect(inputRowRect.top, greaterThanOrEqualTo(0), reason: '输入框不能被挤出屏幕顶部');
  });

  // 附件面板（「+」）的上限高度与表情面板不同（320 vs 300），
  // 若没有单独测量，键盘差额会按兜底值算错，输入行落不到键盘上沿。
  for (final keyboardHeight in <double>[0, 300, 400]) {
    testWidgets('附件面板：键盘高度 ${keyboardHeight.toInt()} 时不变量成立', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      useFixedView(tester);

      await tester.pumpWidget(host(controller, keyboardHeight));
      await tester.pumpAndSettle();
      // 「更多」按钮展开附件面板
      await tester.tap(find.byTooltip('更多'));
      await tester.pumpAndSettle();

      final keyboardTop = screenHeight - keyboardHeight;
      final inputRowRect = tester.getRect(find.byType(ChatInputField));
      final attachmentRect = tester.getRect(find.byType(AttachmentPanel));

      expect(
        inputRowRect.bottom,
        lessThanOrEqualTo(keyboardTop + 1),
        reason: '附件面板态下输入行仍必须在键盘之上（kbd=$keyboardHeight）',
      );
      expect(
        attachmentRect.bottom,
        closeTo(screenHeight, 1),
        reason: '附件面板必须锚定屏幕底部（kbd=$keyboardHeight）',
      );
      // 键盘不低于面板时，输入行下沿应**正好贴住键盘上沿**：
      // 这条能抓住「面板高度用错（兜底值 ≠ 实测值）导致差额算错」的问题，
      // 只断言「在键盘之上」是抓不住的（错 20px 也仍在之上）。
      if (keyboardHeight >= 320) {
        final rowArea = tester.getRect(
          find.byKey(const ValueKey('chat_input_row_area')),
        );
        expect(
          rowArea.bottom,
          closeTo(keyboardTop, 2),
          reason: '输入行下沿应贴住键盘上沿（kbd=$keyboardHeight）',
        );
      }
    });
  }

  // 键盘弹出状态下在「表情 ↔ 附件」面板之间切换：
  // 两个面板高度不同（300 vs 320），差额必须实时跟上，输入行不能跳走或落到键盘之下。
  testWidgets('键盘弹出时切换面板：输入行始终贴住键盘上沿', (tester) async {
    const keyboardHeight = 400.0;
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    useFixedView(tester);

    await tester.pumpWidget(host(controller, keyboardHeight));
    await tester.pumpAndSettle();
    final keyboardTop = screenHeight - keyboardHeight;

    // 表情面板 → 附件面板
    await tester.tap(find.byTooltip('表情'));
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.byKey(const ValueKey('chat_input_row_area'))).bottom,
      closeTo(keyboardTop, 2),
      reason: '表情面板态下输入行应贴住键盘上沿',
    );

    await tester.tap(find.byTooltip('更多'));
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.byKey(const ValueKey('chat_input_row_area'))).bottom,
      closeTo(keyboardTop, 2),
      reason: '切到附件面板后输入行仍应贴住键盘上沿（高度不同需重算差额）',
    );
    expect(
      tester.getRect(find.byType(AttachmentPanel)).bottom,
      closeTo(screenHeight, 1),
      reason: '附件面板应锚定屏幕底部',
    );
  });
}
