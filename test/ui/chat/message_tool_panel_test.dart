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

  /// 面板里点表情时收到的 emoji（验证「选中即表情回复」）
  final reacted = <String>[];

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
            onReaction: (_, emoji) => reacted.add(emoji),
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

    // 对齐飞书稿：长按菜单里的表情面板只有内容（无标题栏/返回箭头/Tab 栏）
    expect(find.text('默认表情'), findsOneWidget, reason: '进入表情界面');
    expect(find.byIcon(Icons.arrow_back), findsNothing);
    expect(panelHeight(tester), closeTo(beforeSwitch, 1), reason: '切换不改高度');

    // 点表情即作为表情回复（host 注入的回调收到该 emoji），并关闭面板
    await tester.tap(find.text('😀').first);
    await tester.pumpAndSettle();
    expect(reacted, contains('😀'));
  });

  testWidgets('高屏机型：往上拖只到内容露完为止，底部不留空白', (tester) async {
    // 模拟更高的屏幕（逻辑 600x1200）：菜单内容比最大拖拽高度矮
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await openPanel(tester);
    await dragHandle(tester, -600); // 尽量往上拖

    final screen = screenHeight(tester);
    final header = tester
        .getSize(find.byKey(const ValueKey('message_tool_sheet_header')))
        .height;
    final content = tester
        .getSize(find.byKey(const ValueKey('message_tool_menu_content')))
        .height;

    // 抽屉式高度：弹层 = 头部 + 内容（没有被拉伸，也就没有空白）
    expect(panelHeight(tester), closeTo(header + content, 1));
    expect(panelHeight(tester), lessThan(screen * 0.95));
  });
}
