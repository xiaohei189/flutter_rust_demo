import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_rust_demo/ui/chat/widgets/composer/chat_input.dart';
import 'package:flutter_rust_demo/ui/chat/widgets/composer/emoji_panel.dart';

/// 常驻面板（Offstage 保状态）必须：能打开、父级重建后保持打开与状态、能关闭。
///
/// 面板 widget 实例做了缓存（父级重建时 Flutter 复用 Element 不重建子树），
/// 这里守住"缓存不影响开合与状态"这条底线。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Widget host(TextEditingController controller) => MaterialApp(
    home: Scaffold(
      body: Align(
        alignment: Alignment.bottomCenter,
        child: ChatInput(
          controller: controller,
          onSend: (_, _) {},
          onAtMention: () {},
        ),
      ),
    ),
  );

  /// 直接包住表情面板的 Offstage 实际尺寸：隐藏时被折叠为 0
  double panelHeight(WidgetTester tester) {
    final element = tester.element(
      find.byWidgetPredicate((w) => w is Offstage && w.child is EmojiPanel),
    );
    return (element.renderObject! as RenderBox).size.height;
  }

  testWidgets('表情面板可打开、父级重建后保持打开、可关闭', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(host(controller));
    await tester.pump();
    expect(panelHeight(tester), 0, reason: '初始应收起');

    // 折叠态只有输入行里的表情按钮（tooltip 表情）
    await tester.tap(find.byTooltip('表情'));
    await tester.pumpAndSettle();
    final opened = panelHeight(tester);
    expect(opened, greaterThan(0), reason: '点击表情按钮后面板应展开');

    // 父级重建（新 ChatInput 实例）：缓存面板实例不应导致收起或重新布局
    await tester.pumpWidget(host(controller));
    await tester.pumpAndSettle();
    expect(panelHeight(tester), opened, reason: '父级重建后应保持展开');

    // 展开态工具栏上的按钮变成「键盘」，点它收起面板
    await tester.tap(find.byTooltip('键盘'));
    await tester.pumpAndSettle();
    expect(panelHeight(tester), 0, reason: '再点一次应收起');
  });
}
