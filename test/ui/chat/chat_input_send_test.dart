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
    expect(find.text('发送'), findsOneWidget, reason: '聚焦后应展开完整工具栏');
    expect(find.text('Aa'), findsOneWidget, reason: 'Markdown 切换应显示 Aa 标识');
    expect(find.text('输入消息...'), findsOneWidget);

    await tester.tap(find.text('发送'));
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
    expect(find.text('发送'), findsOneWidget);

    await tester.tap(find.byTooltip('更多'));
    await tester.pumpAndSettle();

    expect(find.text('相册'), findsOneWidget, reason: '更多面板应展开');
    expect(find.text('发送'), findsOneWidget, reason: '面板展开时工具栏不应被折叠行替换');
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
    expect(find.text('发送'), findsOneWidget, reason: 'Markdown 模式右侧应保留发送按钮');
    expect(
      tester.getTopLeft(toggle).dx,
      lessThan(tester.getTopLeft(find.text('B')).dx),
      reason: '切换箭头应位于格式按钮左侧',
    );

    await tester.tap(find.text('发送'));
    await tester.pump();
    expect(sent, 1, reason: 'Markdown 模式下发送按钮仍应可发送');
  });

  testWidgets('表情面板 Tab 栏位于内容上方', (tester) async {
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

    final tab = find.byIcon(Icons.history);
    final emoji = find.text('😀').first;
    expect(tab, findsOneWidget, reason: '表情面板应显示 Tab 栏');
    expect(emoji, findsWidgets, reason: '表情面板应显示表情内容');
    expect(
      find.byIcon(Icons.keyboard),
      findsOneWidget,
      reason: '键盘按钮应只出现在输入工具栏',
    );
    expect(
      tester.getTopLeft(tab).dy,
      lessThan(tester.getTopLeft(emoji).dy),
      reason: 'Tab 栏应位于表情内容上方',
    );

    await tester.tap(find.byIcon(Icons.keyboard));
    await tester.pumpAndSettle();
    expect(
      find.byIcon(Icons.keyboard),
      findsNothing,
      reason: '点击工具栏键盘按钮应关闭表情面板并恢复表情图标',
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
    final toolbarY = tester.getTopLeft(find.text('发送')).dy;
    expect(inputY, lessThan(toolbarY), reason: '工具栏应在输入框下方');

    await tester.tap(find.byTooltip('更多'));
    await tester.pumpAndSettle();
    final panelY = tester.getTopLeft(find.text('相册')).dy;
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

    final toolbarY = tester.getTopLeft(find.text('发送')).dy;
    final panelTabY = tester.getTopLeft(find.byIcon(Icons.history)).dy;
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
