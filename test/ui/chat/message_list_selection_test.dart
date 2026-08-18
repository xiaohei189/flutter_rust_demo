import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_rust_demo/domain/models/user.dart';
import 'package:flutter_rust_demo/ui/chat/widgets/message_action_menu.dart';
import 'package:flutter_rust_demo/ui/chat/widgets/message_list.dart';
import 'package:flutter_rust_demo/ui/previews/fake_data.dart';

void main() {
  testWidgets('多选勾选框随消息方向排列', (tester) async {
    final messages = [
      fakeTextMessage(text: '对方消息'),
      fakeTextMessage(text: '我的消息', fromMe: true),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 600,
            child: MessageList(
              messages: messages,
              otherUser: const User(id: 'user_2', name: '李四'),
              currentUserId: kPreviewMyUserId,
              scrollController: ScrollController(),
              selectMode: true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('对方消息'), findsOneWidget);
    expect(find.text('我的消息'), findsOneWidget);
    final icons = find.byIcon(Icons.radio_button_unchecked);
    expect(icons, findsNWidgets(2));

    final incomingText = tester.getCenter(find.text('对方消息'));
    final outgoingText = tester.getCenter(find.text('我的消息'));
    final iconCenters = tester
        .widgetList<Icon>(icons)
        .map((icon) => tester.getCenter(find.byWidget(icon)))
        .toList();

    expect(iconCenters.any((pos) => pos.dx < incomingText.dx), isTrue);
    expect(iconCenters.any((pos) => pos.dx > outgoingText.dx), isTrue);
  });

  testWidgets('长按消息显示工具面板', (tester) async {
    final messages = [fakeTextMessage(text: '长按消息')];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 600,
            child: MessageList(
              messages: messages,
              otherUser: const User(id: 'user_2', name: '李四'),
              currentUserId: kPreviewMyUserId,
              scrollController: ScrollController(),
              messageActionsBuilder: (message) => MessageActions(
                onCopy: (_) {},
                onRevoke: (_) {},
                onDelete: (_) {},
                onForward: (_) {},
                onQuote: (_) {},
              ),
            ),
          ),
        ),
      ),
    );

    await tester.longPress(find.text('长按消息'));
    await tester.pump();

    expect(find.byIcon(Icons.swap_horiz), findsOneWidget);
    expect(find.text('复制'), findsOneWidget);
    expect(find.text('回复'), findsOneWidget);
    expect(find.text('转发'), findsOneWidget);
    expect(find.text('删除'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.swap_horiz));
    await tester.pump();

    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    expect(find.text('快速回复'), findsOneWidget);
    expect(find.byKey(const ValueKey('quick_reply_dot_0')), findsOneWidget);
    expect(find.byKey(const ValueKey('quick_reply_dot_1')), findsOneWidget);
    expect(find.text('😀'), findsWidgets);
  });
}
