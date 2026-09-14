import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_rust_demo/domain/models/chat_message.dart'
    show ChatMessage;
import 'package:flutter_rust_demo/domain/models/user.dart';
import 'package:flutter_rust_demo/ui/chat/widgets/list/message_list.dart';
import 'package:flutter_rust_demo/ui/chat/widgets/menu/message_action_menu.dart'
    show MessageActions;
import 'package:flutter_rust_demo/ui/chat/widgets/menu/message_tool_panel.dart'
    show MessageToolPanel;
import 'package:flutter_rust_demo/ui/previews/fake_data.dart';

/// 长按消息弹出的工具面板：弹层高度只由「拖把手」改变，
/// 切换工具面板 ⇄ 完整表情界面时高度保持不变（对齐飞书稿）。
void main() {
  ChatMessage message() => ChatMessage(
    clientMsgId: 'm1',
    serverMsgId: 's1',
    sendId: 'other',
    recvId: 'me',
    groupId: '',
    senderPlatformId: 0,
    senderNickname: '张三',
    senderFaceUrl: '',
    sessionType: 1,
    msgFrom: 0,
    contentType: 101,
    content: '{"content":"长按我"}',
    seq: 1,
    sendTime: DateTime.now().millisecondsSinceEpoch,
    createTime: DateTime.now().millisecondsSinceEpoch,
    status: 2,
    isRead: true,
    attachedInfo: '',
    ex: '',
  );

  Widget host() => MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 400,
        height: 800,
        child: MessageList(
          messages: [message()],
          otherUser: const User(id: 'other', name: '对方'),
          currentUserId: kPreviewMyUserId,
          scrollController: ScrollController(),
          messageActionsBuilder: (_) => MessageActions(
            onCopy: (_) {},
            onRevoke: (_) {},
            onDelete: (_) {},
            onForward: (_) {},
            onQuote: (_) {},
            onReaction: (_, _) {},
          ),
        ),
      ),
    ),
  );

  double panelHeight(WidgetTester tester) =>
      tester.getSize(find.byType(MessageToolPanel)).height;

  /// 测试窗口高度（面板高度按它按比例计算）
  double screenHeight(WidgetTester tester) =>
      tester.getSize(find.byType(Scaffold)).height;

  Future<void> openPanel(WidgetTester tester) async {
    await tester.pumpWidget(host());
    await tester.longPress(find.text('长按我'));
    await tester.pumpAndSettle();
  }

  /// 从面板顶部把手往下/上拖
  Future<void> dragHandle(WidgetTester tester, double dy) async {
    final top = tester.getTopLeft(find.byType(MessageToolPanel));
    await tester.dragFrom(
      Offset(top.dx + 120, top.dy + 10),
      Offset(0, dy),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('首次弹出约占屏幕一半，拖把手往上才能加高', (tester) async {
    await openPanel(tester);

    final initial = panelHeight(tester);
    expect(initial, closeTo(screenHeight(tester) * 0.5, 1));

    // 往上拖 → 接近全屏（0.95）
    await dragHandle(tester, -400);
    final expanded = panelHeight(tester);
    expect(expanded, greaterThan(initial));
    expect(expanded, closeTo(screenHeight(tester) * 0.95, 1));

    // 往下拖一点 → 吸附回首屏一半
    await dragHandle(tester, 250);
    expect(panelHeight(tester), closeTo(screenHeight(tester) * 0.5, 1));

    // 一直往下拖 → 落到最小档（小窗）
    await dragHandle(tester, 400);
    expect(panelHeight(tester), closeTo(screenHeight(tester) * 0.3, 1));
  });

  testWidgets('「⋯」切到完整表情界面，弹层高度保持原样', (tester) async {
    await openPanel(tester);
    await dragHandle(tester, -200); // 先拖到中间档位
    final beforeSwitch = panelHeight(tester);

    await tester.tap(find.byIcon(Icons.more_horiz));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.arrow_back), findsOneWidget, reason: '进入表情界面');
    expect(find.text('表情'), findsWidgets);
    expect(panelHeight(tester), closeTo(beforeSwitch, 1), reason: '切换不改高度');

    // 返回工具面板同样不改高度
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.more_horiz), findsOneWidget);
    expect(panelHeight(tester), closeTo(beforeSwitch, 1));
  });
}
