import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_rust_demo/domain/models/conversation.dart';
import 'package:flutter_rust_demo/ui/chat/widgets/list/chat_list_item_content.dart';
import 'package:flutter_rust_demo/ui/core/theme/app_theme.dart';

Conversation _conversation({required int unreadCount, int recvMsgOpt = 0}) =>
    Conversation(
      conversationId: 'si_user_a_user_b',
      conversationType: 1,
      userId: 'user_b',
      groupId: '',
      showName: '对方',
      faceUrl: '',
      latestMsg: '',
      latestMsgSendTime: 0,
      unreadCount: unreadCount,
      recvMsgOpt: recvMsgOpt,
      isPinned: false,
      isPrivateChat: false,
      burnDuration: 0,
      groupAtType: 0,
      isNotInGroup: false,
      updateUnreadCountTime: 0,
      attachedInfo: '',
      ex: '',
      draftText: '',
      draftTextTime: 0,
      maxSeq: 0,
      minSeq: 0,
      isMsgDestruct: false,
      msgDestructTime: 0,
    );

Future<void> _pump(
  WidgetTester tester, {
  required int unreadCount,
  int recvMsgOpt = 0,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: ChatListItemContent(
          conversation: _conversation(
            unreadCount: unreadCount,
            recvMsgOpt: recvMsgOpt,
          ),
          isSelected: false,
          onTap: () {},
          onLongPress: (_) {},
          timeText: '12:30',
          previewText: '最新一条消息',
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('未读会话显示蓝色数字角标，标记已读后消失', (tester) async {
    await _pump(tester, unreadCount: 5);
    expect(find.text('5'), findsOneWidget, reason: '未读数应出现在列表行');

    await _pump(tester, unreadCount: 0);
    expect(find.text('5'), findsNothing, reason: '标记已读后角标应消失');
  });

  testWidgets('未读超过 99 显示 99+', (tester) async {
    await _pump(tester, unreadCount: 120);
    expect(find.text('99+'), findsOneWidget);
    expect(find.text('120'), findsNothing);
  });

  testWidgets('免打扰会话只显示灰点，不显示具体数字', (tester) async {
    await _pump(tester, unreadCount: 7, recvMsgOpt: 1);
    expect(find.text('7'), findsNothing, reason: '免打扰不应暴露未读数字');
  });

  testWidgets('有未读时时间使用主色蓝，无未读为灰色', (tester) async {
    final primary = AppTheme.lightTheme.colorScheme.primary;

    await _pump(tester, unreadCount: 3);
    expect(tester.widget<Text>(find.text('12:30')).style?.color, primary);

    await _pump(tester, unreadCount: 0);
    expect(tester.widget<Text>(find.text('12:30')).style?.color, isNot(primary));
  });
}
