import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_rust_demo/ui/core/widgets/state_views.dart';
import 'package:flutter_rust_demo/ui/chat/widgets/message_selection_bar.dart';

void main() {
  testWidgets('EmptyState 显示标题', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EmptyState(icon: Icons.person_off_outlined, title: '暂无好友'),
        ),
      ),
    );

    expect(find.text('暂无好友'), findsOneWidget);
  });

  testWidgets('MessageSelectionBar 显示数量并触发关闭', (tester) async {
    var closed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageSelectionBar(
            count: 2,
            onForwardOneByOne: () {},
            onMergeForward: () {},
            onClose: () => closed = true,
          ),
        ),
      ),
    );

    expect(find.text('已选 2 条'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close));
    expect(closed, isTrue);
  });
}
