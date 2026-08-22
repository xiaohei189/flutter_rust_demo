import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_rust_demo/ui/chat/view_models/chat_list_view_model.dart';
import 'package:flutter_rust_demo/ui/chat/widgets/list/chat_list_item.dart';
import 'package:flutter_rust_demo/ui/previews/fake_data.dart';

void main() {
  test('@我判断覆盖仅@我和@所有人且@我', () {
    final atMe = fakeConversation(groupAtType: 1);
    final atAllAtMe = fakeConversation(groupAtType: 3);
    final atAll = fakeConversation(groupAtType: 2);

    expect(ChatListViewModel.isAtMeConversation(atMe), isTrue);
    expect(ChatListViewModel.isAtMeConversation(atAllAtMe), isTrue);
    expect(ChatListViewModel.isAtMeConversation(atAll), isFalse);
  });

  test('标记/已完成判断从会话 ex 解析', () {
    final flagged = fakeConversation(
      ex: ChatListViewModel.flagsEx(flagged: true, done: false),
    );
    final done = fakeConversation(
      ex: ChatListViewModel.flagsEx(flagged: false, done: true),
    );

    expect(ChatListViewModel.isFlagged(flagged), isTrue);
    expect(ChatListViewModel.isDone(flagged), isFalse);
    expect(ChatListViewModel.isDone(done), isTrue);
    expect(ChatListViewModel.isFlagged(done), isFalse);
  });

  testWidgets('会话列表项显示 @我 标记', (tester) async {
    final conversation = fakeConversation(
      conversationId: 'sg_group_1',
      conversationType: 2,
      groupId: 'group_1',
      showName: '产品讨论群',
      groupAtType: 3,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatListItem(conversation: conversation, onTap: () {}),
        ),
      ),
    );

    expect(find.text('@我'), findsOneWidget);
  });

  testWidgets('会话列表项标签收敛：只显示关键标记', (tester) async {
    final conversation = fakeConversation(
      conversationId: 'sg_group_1',
      conversationType: 2,
      groupId: 'group_1',
      showName: '产品讨论群',
      isPrivateChat: true,
      isMsgDestruct: true,
      burnDuration: 60,
      isNotInGroup: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatListItem(conversation: conversation, onTap: () {}),
        ),
      ),
    );

    // 标签收敛：不在群内 优先展示；群聊/私聊/阅后即焚 均不在列表展示。
    expect(find.text('不在群内'), findsOneWidget);
    expect(find.text('群聊'), findsNothing);
    expect(find.text('私聊'), findsNothing);
    expect(find.text('阅后即焚'), findsNothing);
  });
}
