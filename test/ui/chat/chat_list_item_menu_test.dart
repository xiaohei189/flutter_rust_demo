import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_rust_demo/ui/chat/view_models/chat_list_view_model.dart';
import 'package:flutter_rust_demo/ui/chat/widgets/list/chat_list_item_menu.dart';
import 'package:flutter_rust_demo/ui/previews/fake_data.dart';

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('长按菜单展示会话操作项', (tester) async {
    await tester.pumpWidget(
      _host(
        Builder(
          builder: (context) => TextButton(
            onPressed: () {
              showChatListItemMenu(
                context,
                rowRect: const Rect.fromLTWH(100, 100, 300, 60),
                conversation: fakeConversation(unreadCount: 1),
                isMuted: false,
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('置顶'), findsOneWidget);
    expect(find.text('标为已读'), findsOneWidget);
    expect(find.text('消息免打扰'), findsOneWidget);
    expect(find.text('完成'), findsOneWidget);
  });

  testWidgets('无未读会话显示标为未读与取消归档', (tester) async {
    await tester.pumpWidget(
      _host(
        Builder(
          builder: (context) => TextButton(
            onPressed: () {
              showChatListItemMenu(
                context,
                rowRect: const Rect.fromLTWH(100, 100, 300, 60),
                conversation: fakeConversation(
                  ex: ChatListViewModel.flagsEx(flagged: false, done: false),
                ),
                isMuted: false,
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('标为未读'), findsOneWidget);
    expect(find.text('消息免打扰'), findsOneWidget);
  });
}
