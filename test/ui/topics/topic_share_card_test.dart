import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_rust_demo/domain/models/chat_message.dart';
import 'package:flutter_rust_demo/domain/models/topic.dart';
import 'package:flutter_rust_demo/ui/chat/widgets/bubble/parts/rich_message_content.dart';
import 'package:flutter_rust_demo/ui/core/theme/app_theme.dart';

void main() {
  testWidgets('转发的群话题卡片可以展开回复快照', (tester) async {
    const card = TopicShareCard(
      groupId: 'g1',
      topicId: 't1',
      groupName: '项目群',
      title: '发布计划',
      creatorName: '张三',
      replyCount: 3,
      link: 'flutterrustdemo:///topic/t1?groupID=g1',
      replies: [
        TopicShareReply(
          seq: 2,
          senderName: '李四',
          content: '已确认排期',
          sendTime: 2,
        ),
        TopicShareReply(seq: 3, senderName: '王五', content: '今晚提测', sendTime: 3),
        TopicShareReply(seq: 4, senderName: '赵六', content: '明早发布', sendTime: 4),
      ],
    );
    final message = ChatMessage(
      clientMsgId: 'm1',
      serverMsgId: 's1',
      sendId: 'u1',
      recvId: 'u2',
      groupId: '',
      senderPlatformId: 1,
      senderNickname: '张三',
      senderFaceUrl: '',
      sessionType: 1,
      msgFrom: 100,
      contentType: 110,
      content: jsonEncode({
        'data': jsonEncode(card.toJson()),
        'extension': 'openim_topic',
        'description': '项目群: 发布计划',
      }),
      seq: 1,
      sendTime: 1,
      createTime: 1,
      status: 2,
      isRead: true,
      attachedInfo: '',
      ex: '',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: CustomMessageContent(message: message, isFromMe: false),
        ),
      ),
    );

    expect(find.text('查看全部 3 条转发回复'), findsOneWidget);
    await tester.tap(find.text('查看全部 3 条转发回复'));
    await tester.pumpAndSettle();

    expect(find.text('已确认排期'), findsOneWidget);
    expect(find.text('今晚提测'), findsOneWidget);
    expect(find.text('明早发布'), findsOneWidget);
  });
}
