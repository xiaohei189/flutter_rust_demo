import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_rust_demo/domain/models/user.dart';
import 'package:flutter_rust_demo/domain/models/chat_message.dart' show ChatMessage;
import 'package:flutter_rust_demo/ui/chat/widgets/message_list.dart';
import 'package:flutter_rust_demo/ui/previews/fake_data.dart';

/// 校验各类消息（含转发/合并转发）在消息列表中的展示组件与内容。
void main() {
  Future<void> pumpMessage(WidgetTester tester, ChatMessage message) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 600,
            child: MessageList(
              messages: [message],
              otherUser: const User(id: 'user_2', name: '李四'),
              currentUserId: kPreviewMyUserId,
              scrollController: ScrollController(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('合并转发消息（107）展示标题、摘要与条数', (tester) async {
    await pumpMessage(tester, fakeMergeMessage());

    expect(find.text('群聊记录'), findsOneWidget);
    expect(find.textContaining('明天开会'), findsOneWidget);
    expect(find.textContaining('4条消息'), findsOneWidget);
  });

  testWidgets('语音消息（103）渲染语音组件并展示时长', (tester) async {
    await pumpMessage(tester, fakeAudioMessage(duration: 8));

    expect(find.byIcon(Icons.play_circle_outline), findsOneWidget);
    expect(find.text('0:08'), findsOneWidget);
    expect(find.byIcon(Icons.play_circle_fill), findsNothing);
  });

  testWidgets('视频消息（104）渲染视频组件并展示播放图标', (tester) async {
    await pumpMessage(tester, fakeVideoMessage());

    expect(find.byIcon(Icons.play_circle_fill), findsOneWidget);
    expect(find.byIcon(Icons.play_circle_outline), findsNothing);
  });

  testWidgets('@消息（106）渲染文本内容', (tester) async {
    await pumpMessage(tester, fakeAtMessage());

    expect(find.text('@张三 晚上一起吃饭吗？'), findsOneWidget);
  });

  testWidgets('位置消息（109）展示位置名称与描述', (tester) async {
    await pumpMessage(tester, fakeLocationMessage());

    expect(find.text('杭州西溪湿地'), findsOneWidget);
    expect(find.textContaining('天目山路'), findsOneWidget);
  });
}