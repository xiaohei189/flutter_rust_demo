import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_rust_demo/ui/core/widgets/state_views.dart';
import 'package:flutter_rust_demo/ui/chat/widgets/menu/message_selection_bar.dart';

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

  testWidgets('MessageSelectionTopBar 显示数量并支持全选/关闭', (tester) async {
    var selectAll = false;
    var closed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageSelectionTopBar(
            count: 3,
            totalCount: 10,
            onSelectAll: () => selectAll = true,
            onClose: () => closed = true,
            onDelete: () {},
            onForwardOneByOne: () {},
            onMergeForward: () {},
          ),
        ),
      ),
    );

    expect(find.text('已选 3 项'), findsOneWidget);
    expect(find.text('全选'), findsOneWidget);
    expect(find.text('逐条转发'), findsOneWidget);
    expect(find.text('合并转发'), findsOneWidget);
    expect(find.text('删除'), findsOneWidget);
    await tester.tap(find.text('全选'));
    expect(selectAll, isTrue);
    await tester.tap(find.byIcon(Icons.close));
    expect(closed, isTrue);
  });

  testWidgets('MessageSelectionTopBar 操作按钮触发转发与删除', (tester) async {
    var deleted = false;
    var forwarded = false;
    var merged = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageSelectionTopBar(
            count: 2,
            totalCount: 5,
            onSelectAll: () {},
            onClose: () {},
            onDelete: () => deleted = true,
            onForwardOneByOne: () => forwarded = true,
            onMergeForward: () => merged = true,
          ),
        ),
      ),
    );

    await tester.tap(find.text('逐条转发'));
    expect(forwarded, isTrue);
    await tester.tap(find.text('合并转发'));
    expect(merged, isTrue);
    await tester.tap(find.text('删除'));
    expect(deleted, isTrue);
  });
}
