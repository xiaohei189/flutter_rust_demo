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
          keyboardInset: 0,
        ),
      ),
    ),
  );

  // 面板外层依次套了 _MeasureSize（量自然高度）与 Offstage（收起时移出布局）。
  // skipOffstage: false —— 收起时 Offstage 把面板移出布局，默认 finder 会跳过它，
  // 而本测试正是要验证「收起后仍在树中（保状态）」。
  final panelInTree = find.byType(EmojiPanel, skipOffstage: false);

  /// 包住表情面板的 Offstage：收起时为 true（面板仍在树中保状态）。
  ///
  /// 不用子面板的渲染盒高度判断：Offstage 折叠的是自身尺寸，子项仍保持自然高度。
  bool panelCollapsed(WidgetTester tester) => tester
      .widget<Offstage>(
        find.ancestor(of: panelInTree, matching: find.byType(Offstage)).first,
      )
      .offstage;

  testWidgets('表情面板可打开、父级重建后保持打开、可关闭', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(host(controller));
    await tester.pump();
    // 按需构建：从未打开过时面板根本不在树里（进入页面不付构建/布局成本）
    expect(panelInTree, findsNothing, reason: '未打开过时不应构建面板');

    // 折叠态只有输入行里的表情按钮（tooltip 表情）
    await tester.tap(find.byTooltip('表情'));
    await tester.pumpAndSettle();
    expect(panelInTree, findsOneWidget, reason: '首次打开应构建面板');
    expect(panelCollapsed(tester), isFalse, reason: '点击表情按钮后面板应展开');
    final openedTop = tester.getTopLeft(panelInTree).dy;

    // 父级重建（新 ChatInput 实例）：缓存面板实例不应导致收起或重新布局
    await tester.pumpWidget(host(controller));
    await tester.pumpAndSettle();
    expect(panelCollapsed(tester), isFalse, reason: '父级重建后应保持展开');
    expect(
      tester.getTopLeft(panelInTree).dy,
      openedTop,
      reason: '父级重建后不应重新布局（面板顶边不变）',
    );

    // 再点一次表情按钮收起面板（面板内 Tab 也叫「表情」，取输入行那个）
    await tester.tap(find.byTooltip('表情').first);
    await tester.pumpAndSettle();
    expect(panelInTree, findsOneWidget, reason: '收起后仍常驻树中保留状态');
    expect(panelCollapsed(tester), isTrue, reason: '再点一次应收起');
  });
}
