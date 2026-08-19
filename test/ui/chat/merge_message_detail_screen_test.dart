import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_rust_demo/generated/rust/model/message.dart'
    show MessageInfo;
import 'package:flutter_rust_demo/ui/chat/views/merge_message_detail_screen.dart';

void main() {
  MessageInfo mergeMessage(String content) => MessageInfo(
        clientMsgId: 'm1',
        serverMsgId: 's1',
        sendId: 'u1',
        recvId: 'u2',
        groupId: '',
        senderPlatformId: 0,
        senderNickname: 'test',
        senderFaceUrl: '',
        sessionType: 1,
        msgFrom: 0,
        contentType: 107,
        content: content,
        seq: 1,
        sendTime: 1700000000000,
        createTime: 1700000000000,
        status: 2,
        isRead: false,
        attachedInfo: '',
        ex: '',
      );

  testWidgets('multiMessage 缺失时用 abstractList 展示摘要', (tester) async {
    final message = mergeMessage(
      jsonEncode({
        'title': '群聊记录',
        'abstractList': ['张三: 明天开会', '李四: 收到'],
      }),
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(home: MergeMessageDetailScreen(message: message)),
      ),
    );

    expect(find.text('明天开会'), findsOneWidget);
    expect(find.text('收到'), findsOneWidget);
    expect(find.text('暂无消息内容'), findsNothing);
  });

  testWidgets('multiMessage 内容缺失时回退到摘要', (tester) async {
    final message = mergeMessage(
      jsonEncode({
        'title': '群聊记录',
        'abstractList': ['张三: 明天开会'],
        'multiMessage': [
          {'clientMsgID': 'm1'},
        ],
      }),
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(home: MergeMessageDetailScreen(message: message)),
      ),
    );

    expect(find.text('明天开会'), findsOneWidget);
    expect(find.text('暂无消息内容'), findsNothing);
  });
}
