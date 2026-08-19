import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_rust_demo/domain/models/chat_message.dart' show ChatMessage;
import 'package:flutter_rust_demo/ui/chat/views/merge_message_detail_screen.dart';
import 'package:flutter_rust_demo/ui/chat/widgets/message_parts/media_message_content.dart'
    show ImageMessageContent;
import 'package:flutter_rust_demo/ui/chat/widgets/message_parts/rich_message_content.dart'
    show MergeMessageContent;

void main() {
  ChatMessage mergeMessage(String content) => ChatMessage(
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

  testWidgets('multiMessage 存在时用 MessageBubble 渲染文本子消息', (tester) async {
    final message = mergeMessage(
      jsonEncode({
        'title': '群聊记录',
        'abstractList': ['张三: 明天开会'],
        'multiMessage': [
          {
            'clientMsgID': 'm1',
            'sendID': 'user_1',
            'senderNickname': '张三',
            'sessionType': 2,
            'contentType': 101,
            'content': jsonEncode({'content': '明天开会'}),
            'sendTime': 1700000000000,
          },
        ],
      }),
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(home: MergeMessageDetailScreen(message: message)),
      ),
    );
    await tester.pump();

    expect(find.text('明天开会'), findsOneWidget);
    expect(find.text('张三'), findsOneWidget);
    expect(find.text('暂无消息内容'), findsNothing);
  });

  testWidgets('multiMessage 图片子消息渲染真实图片组件', (tester) async {
    final message = mergeMessage(
      jsonEncode({
        'title': '群聊记录',
        'multiMessage': [
          {
            'clientMsgID': 'img1',
            'sendID': 'user_1',
            'senderNickname': '张三',
            'sessionType': 2,
            'contentType': 102,
            'content': jsonEncode({
              'sourcePicture': {'url': 'http://example.com/a.png'},
            }),
            'sendTime': 1700000000000,
          },
        ],
      }),
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(home: MergeMessageDetailScreen(message: message)),
      ),
    );
    await tester.pump();

    expect(find.byType(ImageMessageContent), findsOneWidget);
    expect(find.text('[图片]'), findsNothing);
  });

  testWidgets('multiMessage 嵌套合并子消息渲染合并卡片', (tester) async {
    final message = mergeMessage(
      jsonEncode({
        'title': '群聊记录',
        'multiMessage': [
          {
            'clientMsgID': 'm2',
            'sendID': 'user_1',
            'senderNickname': '张三',
            'sessionType': 2,
            'contentType': 107,
            'content': jsonEncode({
              'title': '内层聊天记录',
              'abstractList': ['李四: 收到'],
            }),
            'sendTime': 1700000000000,
          },
        ],
      }),
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(home: MergeMessageDetailScreen(message: message)),
      ),
    );
    await tester.pump();

    expect(find.byType(MergeMessageContent), findsOneWidget);
    expect(find.text('内层聊天记录'), findsOneWidget);
  });

  testWidgets('Go SDK 子消息（content 为空 + pictureElem）图片正常渲染', (tester) async {
    final message = mergeMessage(
      jsonEncode({
        'title': '群聊记录',
        'multiMessage': [
          {
            'clientMsgID': 'go-img',
            'sendID': 'user_1',
            'senderNickname': '张三',
            'sessionType': 2,
            'contentType': 102,
            'content': '',
            'pictureElem': {
              'sourcePicture': {
                'url': 'http://example.com/go.png',
                'width': 640,
                'height': 640,
              },
            },
          },
        ],
      }),
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(home: MergeMessageDetailScreen(message: message)),
      ),
    );
    await tester.pump();

    expect(find.byType(ImageMessageContent), findsOneWidget);
    expect(find.text('[图片]'), findsNothing);
    expect(find.text('暂无消息内容'), findsNothing);
  });

  testWidgets('AppBar：标题在左侧、无返回按钮、无转发按钮、右侧有关闭按钮', (tester) async {
    final message = mergeMessage(
      jsonEncode({
        'title': '群聊记录',
        'abstractList': ['张三: 明天开会'],
      }),
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(home: MergeMessageDetailScreen(message: message)),
      ),
    );
    await tester.pump();

    expect(find.text('群聊记录'), findsOneWidget);
    expect(find.byIcon(Icons.forward_rounded), findsNothing);
    expect(find.byType(BackButton), findsNothing);
    expect(find.byIcon(Icons.close), findsOneWidget);

    // 标题位于弹窗左侧，关闭按钮位于右侧
    final titleRect = tester.getRect(find.text('群聊记录'));
    final closeRect = tester.getRect(find.byIcon(Icons.close));
    expect(titleRect.center.dx, lessThan(closeRect.center.dx));
  });

}
