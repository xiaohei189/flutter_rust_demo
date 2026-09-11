import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_rust_demo/ui/chat/widgets/composer/chat_input.dart';
import 'package:flutter_rust_demo/ui/chat/widgets/composer/message_composer_sheet.dart';

void main() {
  testWidgets('聚焦态点击发送时保持输入焦点并触发 onSend', (tester) async {
    final controller = TextEditingController(text: '测试消息');
    var sent = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatInput(controller: controller, onSend: (_, _) => sent++),
        ),
      ),
    );

    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    expect(find.byTooltip('发送'), findsOneWidget, reason: '聚焦后应展开完整工具栏');
    expect(find.text('Aa'), findsOneWidget, reason: 'Markdown 切换应显示 Aa 标识');
    expect(find.text('输入消息...'), findsOneWidget);

    await tester.tap(find.byTooltip('发送'));
    await tester.pump();

    expect(sent, 1, reason: '点击发送应触发发送回调');
    expect(
      tester.widget<TextField>(find.byType(TextField)).focusNode?.hasFocus,
      isTrue,
      reason: '点击发送不应让输入框提前失焦收起工具栏',
    );
  });

  testWidgets('展开更多面板时保留输入框和完整工具栏', (tester) async {
    final controller = TextEditingController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatInput(controller: controller, onSend: (_, _) {}),
        ),
      ),
    );

    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    expect(find.byTooltip('发送'), findsOneWidget);

    await tester.tap(find.byTooltip('更多'));
    await tester.pumpAndSettle();

    expect(find.text('文件'), findsOneWidget, reason: '更多面板应展开');
    expect(find.byTooltip('发送'), findsOneWidget, reason: '面板展开时工具栏不应被折叠行替换');
  });

  testWidgets('Markdown 模式左侧显示切换箭头并保留发送按钮', (tester) async {
    final controller = TextEditingController(text: '测试消息');
    var sent = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatInput(controller: controller, onSend: (_, _) => sent++),
        ),
      ),
    );

    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aa'));
    await tester.pumpAndSettle();
    expect(
      find.text('Markdown...'),
      findsNothing,
      reason: 'Markdown 模式不应改变输入框提示词',
    );
    expect(find.text('输入消息...'), findsOneWidget);

    final toggle = find.byIcon(Icons.swap_vert);
    expect(toggle, findsOneWidget, reason: 'Markdown 模式应显示上下切换箭头');
    expect(find.text('B'), findsOneWidget, reason: 'Markdown 格式按钮应保留');
    expect(find.byTooltip('发送'), findsOneWidget, reason: 'Markdown 模式右侧应保留发送按钮');
    expect(
      tester.getTopLeft(toggle).dx,
      lessThan(tester.getTopLeft(find.text('B')).dx),
      reason: '切换箭头应位于格式按钮左侧',
    );

    await tester.tap(find.byTooltip('发送'));
    await tester.pump();
    expect(sent, 1, reason: 'Markdown 模式下发送按钮仍应可发送');
  });

  testWidgets('表情面板：默认表情分区 + 底部 Tab 栏（飞书稿）', (tester) async {
    final controller = TextEditingController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatInput(controller: controller, onSend: (_, _) {}),
        ),
      ),
    );

    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('表情'));
    await tester.pumpAndSettle();

    final header = find.text('默认表情');
    final emoji = find.text('😀').first;
    expect(header, findsOneWidget, reason: '表情内容应带分区标题');
    expect(emoji, findsWidgets, reason: '表情面板应显示表情内容');
    final backspace = find.byIcon(Icons.backspace_outlined);
    expect(backspace, findsOneWidget, reason: '底部 Tab 栏右侧应有退格键');
    expect(
      find.byIcon(Icons.emoji_emotions),
      findsOneWidget,
      reason: '面板展开时表情按钮应为激活态',
    );
    expect(
      tester.getTopLeft(header).dy,
      lessThan(tester.getTopLeft(backspace).dy),
      reason: '内容应位于底部 Tab 栏上方',
    );

    // 再点一次表情按钮关闭面板（飞书稿：图标保持表情，不再切成键盘）
    // 面板展开时面板内的 Tab 也叫「表情」，取输入行里的那个（树上更靠前）
    await tester.tap(find.byTooltip('表情').first);
    await tester.pumpAndSettle();
    expect(
      find.byIcon(Icons.emoji_emotions),
      findsNothing,
      reason: '关闭面板后表情按钮应恢复未激活态',
    );
  });

  testWidgets('输入展开时保持输入框、工具栏、面板的纵向顺序', (tester) async {
    final controller = TextEditingController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatInput(controller: controller, onSend: (_, _) {}),
        ),
      ),
    );

    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    final inputY = tester.getTopLeft(find.byType(TextField)).dy;
    final toolbarY = tester.getTopLeft(find.byTooltip('发送')).dy;
    expect(inputY, lessThan(toolbarY), reason: '工具栏应在输入框下方');

    await tester.tap(find.byTooltip('更多'));
    await tester.pumpAndSettle();
    final panelY = tester.getTopLeft(find.text('文件')).dy;
    expect(toolbarY, lessThan(panelY), reason: '面板应位于工具栏下方');
  });

  testWidgets('长消息抽屉中表情面板位于工具栏下方', (tester) async {
    final controller = TextEditingController();
    final hasText = ValueNotifier<bool>(false);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageComposerSheet(
            controller: controller,
            hasText: hasText,
            onSend: (_, _) {},
          ),
        ),
      ),
    );

    expect(find.byTooltip('缩回'), findsOneWidget, reason: '长消息抽屉应保留缩回按钮');

    await tester.tap(find.byTooltip('表情'));
    await tester.pumpAndSettle();

    // 抽屉内仍是文字发送按钮（未随主输入区改版）
    final toolbarY = tester.getTopLeft(find.text('发送')).dy;
    final panelTabY = tester.getTopLeft(find.text('默认表情')).dy;
    expect(toolbarY, lessThan(panelTabY), reason: '长消息抽屉中面板应在工具栏下方');
  });

  testWidgets('长消息抽屉点击 Aa 后显示 Markdown 格式栏', (tester) async {
    final controller = TextEditingController();
    final hasText = ValueNotifier<bool>(false);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageComposerSheet(
            controller: controller,
            hasText: hasText,
            onSend: (_, _) {},
          ),
        ),
      ),
    );

    await tester.tap(find.text('Aa'));
    await tester.pumpAndSettle();

    expect(
      find.byIcon(Icons.swap_vert),
      findsOneWidget,
      reason: 'Markdown 格式栏应显示切换箭头',
    );
    expect(find.text('B'), findsOneWidget, reason: 'Markdown 格式栏应显示格式按钮');
    expect(find.text('发送'), findsOneWidget, reason: 'Markdown 格式栏应保留发送按钮');
  });
}
