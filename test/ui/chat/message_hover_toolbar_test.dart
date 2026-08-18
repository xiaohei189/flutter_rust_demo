import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_rust_demo/ui/chat/widgets/message_hover_toolbar.dart';

void main() {
  testWidgets('MessageReactionBar 聚合展示表情和数量', (tester) async {
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

    expect(find.text('👍 +2'), findsOneWidget);
    expect(find.text('❤️'), findsOneWidget);
  });
}
