import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_rust_demo/domain/models/chat_message.dart'
    show ChatMessage;
import 'package:flutter_rust_demo/domain/models/user.dart';
import 'package:flutter_rust_demo/ui/chat/widgets/list/message_list.dart';

/// 消息列表的日期分隔标签：增量计算（尾部追加 / 头部前插）必须与整表重算结果一致。
void main() {
  final now = DateTime.now();

  ChatMessage messageAt(int daysAgo, int seq) {
    final ms = now.subtract(Duration(days: daysAgo)).millisecondsSinceEpoch;
    return ChatMessage(
      clientMsgId: 'm$seq',
      serverMsgId: 's$seq',
      sendId: seq.isEven ? 'me' : 'other',
      recvId: 'other',
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
      isRead: true,
      attachedInfo: '',
      ex: '',
    );
  }

  Widget host(List<ChatMessage> messages, ScrollController controller) {
    return MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 400,
          // 视口足够高，保证所有日期分隔符都被渲染出来
          height: 3000,
          child: MessageList(
            messages: messages,
            otherUser: const User(id: 'other', name: '对方'),
            currentUserId: 'me',
            scrollController: controller,
          ),
        ),
      ),
    );
  }

  /// 只取日期分隔符（气泡时间文案带空格，如「周三 02:06」，据此区分）
  final separatorPattern = RegExp(r'^周[一二三四五六日]$');
  List<String> dateSeparators(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data ?? '')
      .where(
        (s) =>
            s == '今天' ||
            s == '昨天' ||
            separatorPattern.hasMatch(s) ||
            (!s.contains(' ') && s.contains('月') && s.contains('日')),
      )
      .toList();

  testWidgets('前插更早一页后日期分隔与整表重算一致', (tester) async {
    final newer = [for (var i = 0; i < 6; i++) messageAt(i ~/ 2, 100 + i)];
    final older = [for (var i = 0; i < 4; i++) messageAt(2 + i ~/ 2, i)];

    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(host(newer, controller));
    await tester.pump();
    final before = dateSeparators(tester);

    // 模拟 loadMore：头部前插更早消息 → 走增量分支
    await tester.pumpWidget(host([...older, ...newer], controller));
    await tester.pump();
    final incremental = dateSeparators(tester);

    // 同一份数据一次性构建 → 整表重算
    final freshController = ScrollController();
    addTearDown(freshController.dispose);
    await tester.pumpWidget(host([...older, ...newer], freshController));
    await tester.pump();
    final fresh = dateSeparators(tester);

    expect(incremental, fresh);
    expect(before, isNotEmpty);
  });

  testWidgets('尾部追加新消息后日期分隔与整表重算一致', (tester) async {
    final older = [for (var i = 0; i < 4; i++) messageAt(2 + i ~/ 2, i)];
    final today = [for (var i = 0; i < 3; i++) messageAt(0, 200 + i)];

    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(host(older, controller));
    await tester.pump();

    // 模拟收到新消息：尾部追加 → 走增量分支
    await tester.pumpWidget(host([...older, ...today], controller));
    await tester.pump();
    final incremental = dateSeparators(tester);

    final freshController = ScrollController();
    addTearDown(freshController.dispose);
    await tester.pumpWidget(host([...older, ...today], freshController));
    await tester.pump();
    final fresh = dateSeparators(tester);

    expect(incremental, fresh);
    expect(incremental, contains('今天'));
  });
}
