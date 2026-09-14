import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_rust_demo/ui/chat/widgets/menu/message_hover_toolbar.dart';

void main() {
  testWidgets('MessageReactionBar 按人展开：表情 + 昵称（对齐飞书稿）', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MessageReactionBar(
            groups: [
              MessageReactionGroup(
                emoji: '👍',
                count: 3,
                names: ['张三', '李四', '我'],
              ),
              MessageReactionGroup(emoji: '❤️', count: 1, names: ['我']),
            ],
          ),
        ),
      ),
    );

    // 同一种表情每人一个胶囊
    expect(find.text('👍'), findsNWidgets(3));
    expect(find.text('张三'), findsOneWidget);
    expect(find.text('李四'), findsOneWidget);
    expect(find.text('❤️'), findsOneWidget);
    expect(find.text('我'), findsNWidgets(2));
  });

  testWidgets('没有昵称时退化为「表情 + 数量」', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MessageReactionBar(
            groups: [MessageReactionGroup(emoji: '👍', count: 3)],
          ),
        ),
      ),
    );

    expect(find.text('👍'), findsOneWidget);
    expect(find.text('+3'), findsOneWidget);
  });
}
