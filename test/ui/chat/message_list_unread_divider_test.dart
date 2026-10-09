import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_rust_demo/domain/models/chat_message.dart'
    show ChatMessage;
import 'package:flutter_rust_demo/domain/models/user.dart';
import 'package:flutter_rust_demo/ui/chat/widgets/list/message_list.dart';

/// 未读分割线：「以下为新消息」在进入会话的那一刻定位一次，
/// 之后即使已读回执把 isRead 翻成 true 也不能消失。
void main() {
  ChatMessage message(
    int seq, {
    required String sendId,
    bool isRead = true,
  }) {
    final ms = DateTime.now().millisecondsSinceEpoch;
    return ChatMessage(
      clientMsgId: 'm$seq',
      serverMsgId: 's$seq',
      sendId: sendId,
      recvId: 'me',
      groupId: '',
      senderPlatformId: 0,
      senderNickname: '张三',
      senderFaceUrl: '',
      sessionType: 1,
      msgFrom: 0,
      contentType: 101,
      content: '{"content":"第 $seq 条"}',
      seq: seq,
      sendTime: ms,
      createTime: ms,
      status: 2,
      isRead: isRead,
      attachedInfo: '',
      ex: '',
    );
  }

  Widget host(
    List<ChatMessage> messages,
    ScrollController controller, {
    int unreadCountAtOpen = 0,
  }) {
    // 气泡内部订阅上传进度（messageServiceProvider），需要 ProviderScope
    return ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 800,
            child: MessageList(
              messages: messages,
              otherUser: const User(id: 'other', name: '对方'),
              currentUserId: 'me',
              scrollController: controller,
              unreadCountAtOpen: unreadCountAtOpen,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('有未读时在首条未读消息上方展示分割线', (tester) async {
    final messages = [
      message(1, sendId: 'other'),
      message(2, sendId: 'other', isRead: false),
      message(3, sendId: 'other', isRead: false),
    ];
    await tester.pumpWidget(host(messages, ScrollController()));
    await tester.pump();

    expect(find.text('以下为新消息'), findsOneWidget);
  });

  testWidgets('全部已读时不展示分割线', (tester) async {
    final messages = [
      message(1, sendId: 'other'),
      message(2, sendId: 'me'),
    ];
    await tester.pumpWidget(host(messages, ScrollController()));
    await tester.pump();

    expect(find.text('以下为新消息'), findsNothing);
  });

  testWidgets('自己发的未读不算边界', (tester) async {
    final messages = [
      message(1, sendId: 'me', isRead: false),
      message(2, sendId: 'me', isRead: false),
    ];
    await tester.pumpWidget(host(messages, ScrollController()));
    await tester.pump();

    expect(find.text('以下为新消息'), findsNothing);
  });

  testWidgets('已读回执把 isRead 翻过来后分割线仍在（快照语义）', (tester) async {
    final controller = ScrollController();
    final unread = [
      message(1, sendId: 'other'),
      message(2, sendId: 'other', isRead: false),
    ];
    await tester.pumpWidget(host(unread, controller));
    await tester.pump();
    expect(find.text('以下为新消息'), findsOneWidget);

    // 进入会话后已读回执照常把消息标为已读：分割线保持不动。
    final readAll = [
      message(1, sendId: 'other'),
      message(2, sendId: 'other'),
    ];
    await tester.pumpWidget(host(readAll, controller));
    await tester.pump();

    expect(find.text('以下为新消息'), findsOneWidget);
  });

  testWidgets('消息都已读但会话未读数 >0 时按未读数兜底定位', (tester) async {
    final messages = [
      message(1, sendId: 'other'),
      message(2, sendId: 'other'),
      message(3, sendId: 'other'),
    ];
    await tester.pumpWidget(
      host(messages, ScrollController(), unreadCountAtOpen: 2),
    );
    await tester.pump();

    // 未读 2 条 → 分割线落在倒数第二条对方消息上。
    expect(find.text('以下为新消息'), findsOneWidget);
  });

  testWidgets('会话未读数为 0 且消息全已读时不展示分割线', (tester) async {
    final messages = [message(1, sendId: 'other'), message(2, sendId: 'other')];
    await tester.pumpWidget(host(messages, ScrollController()));
    await tester.pump();

    expect(find.text('以下为新消息'), findsNothing);
  });

  testWidgets('离开底部显示「N 条新消息」胶囊，点击回到底部', (tester) async {
    final controller = ScrollController();
    final messages = [
      for (var i = 1; i <= 40; i++)
        message(i, sendId: i == 40 ? 'other' : 'me', isRead: i != 40),
    ];
    await tester.pumpWidget(
      host(messages, controller, unreadCountAtOpen: 1),
    );
    await tester.pump();
    expect(find.text('以下为新消息'), findsOneWidget);
    // 还停在底部：不出现回到底部胶囊
    expect(find.text('1 条新消息'), findsNothing);

    controller.jumpTo(600);
    await tester.pump();
    expect(find.text('1 条新消息'), findsOneWidget);

    await tester.tap(find.text('1 条新消息'));
    await tester.pumpAndSettle();
    expect(find.text('1 条新消息'), findsNothing);
  });
}
