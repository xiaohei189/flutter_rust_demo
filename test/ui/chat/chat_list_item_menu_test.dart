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

  testWidgets('传齐回调时展示归档/分组/清空/删除入口，删除需二次确认', (tester) async {
    var deleted = 0;
    await tester.pumpWidget(
      _host(
        Builder(
          builder: (context) => TextButton(
            onPressed: () {
              showChatListItemMenu(
                context,
                rowRect: const Rect.fromLTWH(100, 100, 300, 60),
                conversation: fakeConversation(),
                isMuted: false,
                onPinToggle: () {},
                onMarkRead: () {},
                onMarkUnread: () {},
                onMuteToggle: () {},
                onClear: () {},
                onFlagToggle: () {},
                onDoneToggle: () {},
                onArchive: () {},
                onUnarchive: () {},
                onMoveToFolder: () {},
                onDelete: () => deleted++,
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('归档'), findsOneWidget);
    expect(find.text('移动到分组'), findsOneWidget);
    expect(find.text('清空聊天记录'), findsOneWidget);
    expect(find.text('删除'), findsOneWidget);

    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    expect(find.text('确定删除该会话吗？聊天记录将一并删除。'), findsOneWidget);
    expect(deleted, 0, reason: '确认前不应触发删除');

    await tester.tap(find.widgetWithText(TextButton, '删除'));
    await tester.pumpAndSettle();
    expect(deleted, 1);
  });

  testWidgets('已归档会话展示取消归档并走 onUnarchive', (tester) async {
    var unarchived = 0;
    final archivedEx = ChatListViewModel.updateFlags(
      fakeConversation(),
      archived: true,
    );
    await tester.pumpWidget(
      _host(
        Builder(
          builder: (context) => TextButton(
            onPressed: () {
              showChatListItemMenu(
                context,
                rowRect: const Rect.fromLTWH(100, 100, 300, 60),
                conversation: fakeConversation(ex: archivedEx),
                isMuted: false,
                onArchive: () {},
                onUnarchive: () => unarchived++,
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('取消归档'), findsOneWidget);
    expect(find.text('归档'), findsNothing);

    await tester.tap(find.text('取消归档'));
    await tester.pumpAndSettle();
    expect(unarchived, 1);
  });
}
