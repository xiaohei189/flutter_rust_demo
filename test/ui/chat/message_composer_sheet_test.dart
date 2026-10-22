import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_rust_demo/ui/chat/widgets/composer/message_composer_sheet.dart';

void main() {
  testWidgets('点击缩回先回调 onBeforeCollapse，再关闭抽屉', (tester) async {
    final controller = TextEditingController();
    final hasText = ValueNotifier<bool>(false);
    addTearDown(controller.dispose);
    addTearDown(hasText.dispose);

    var beforeCollapseCalled = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () {
                showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => MessageComposerSheet(
                    controller: controller,
                    hasText: hasText,
                    onSend: (_, _) {},
                    onBeforeCollapse: () => beforeCollapseCalled = true,
                  ),
                );
              },
              child: const Text('展开'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('展开'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('缩回'), findsOneWidget);

    await tester.tap(find.byTooltip('缩回'));
    await tester.pump();
    expect(beforeCollapseCalled, isTrue, reason: '应在 pop 之前归还焦点');

    await tester.pumpAndSettle();
    expect(find.byType(MessageComposerSheet), findsNothing);
  });
}
