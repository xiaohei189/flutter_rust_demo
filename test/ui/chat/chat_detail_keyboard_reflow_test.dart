import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'package:flutter_rust_demo/application/chat/message_service_notifier.dart';
import 'package:flutter_rust_demo/domain/models/conversation.dart';
import 'package:flutter_rust_demo/domain/models/chat_message.dart'
    show ChatMessage;
import 'package:flutter_rust_demo/ui/chat/providers/message_service_provider.dart';
import 'package:flutter_rust_demo/ui/chat/views/chat_detail_screen.dart';
import 'package:flutter_rust_demo/ui/chat/widgets/list/chat_message_list_section.dart';
import 'package:flutter_rust_demo/ui/chat/widgets/shared/chat_detail_app_bar.dart';
import 'package:flutter_rust_demo/ui/profile/providers/user_profile_provider.dart';
import 'package:flutter_rust_demo/ui/profile/view_models/user_profile_view_model.dart';

/// 底部占位模型（业界推荐）：列表留白 = 输入行 + max(面板, 键盘)。
///
/// - 顶栏与消息列表**顶部**位置必须完全不变（body 不随键盘重排）；
/// - 键盘/面板占多少，列表就让多少，最新消息始终露在输入行上方；
/// - 面板与键盘等高时（面板按记忆的键盘高度对齐占位）互相切换零位移。
/// 断言的都是相对位置，与具体机型/键盘高度无关。
const _convId = 'si_user_a_user_b';

Conversation _conversation() => const Conversation(
  conversationId: _convId,
  conversationType: 1,
  userId: 'user_b',
  groupId: '',
  showName: '张三',
  faceUrl: '',
  latestMsg: '',
  latestMsgSendTime: 0,
  unreadCount: 0,
  recvMsgOpt: 0,
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

ChatMessage _message(String id, String text) => ChatMessage(
  clientMsgId: id,
  serverMsgId: '',
  sendId: 'user_b',
  recvId: 'user_a',
  groupId: '',
  senderPlatformId: 0,
  senderNickname: '对方',
  senderFaceUrl: '',
  sessionType: 1,
  msgFrom: 0,
  contentType: 101,
  content: '{"content":"$text"}',
  seq: 1,
  sendTime: 1000,
  createTime: 1000,
  status: 2,
  isRead: true,
  attachedInfo: '',
  ex: '',
);

class _TestService extends MessageServiceNotifier {
  _TestService(this._initial);

  final MessageServiceState _initial;

  @override
  MessageServiceState build() => _initial;
}

/// 屏幕逻辑尺寸 400x800，viewInsets 由用例注入（测试环境的假键盘不写 viewInsets）。
const _screenWidth = 400.0;
const _screenHeight = 800.0;

void useFixedView(WidgetTester tester) {
  tester.view.physicalSize = const Size(_screenWidth * 2, _screenHeight * 2);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
}

Widget host(
  MessageServiceNotifier service,
  double keyboardHeight, {
  EdgeInsets padding = EdgeInsets.zero,
}) {
  return ProviderScope(
    overrides: [
      messageServiceProvider.overrideWith(() => service),
      userProfileProvider.overrideWith(() => UserProfileNotifier()),
    ],
    child: MaterialApp(
      home: const ChatDetailScreen(conversationId: _convId),
      // 注入键盘高度：必须放在 MaterialApp 的 builder 里，否则会被上层 MediaQuery 覆盖。
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          viewInsets: EdgeInsets.only(bottom: keyboardHeight),
          padding: padding,
        ),
        child: child!,
      ),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // visibility_detector 在 widget 测试里会调度 500ms timer，设为立即更新避免 pending timer。
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  MessageServiceNotifier serviceWithMessages() => _TestService(
    MessageServiceState(
      currentUserId: 'user_a',
      conversations: [_conversation()],
      messages: {
        _convId: [_message('m1', '第一条'), _message('m2', '第二条')],
      },
    ),
  );

  testWidgets('键盘弹出只影响底部：顶栏与消息列表顶部位置不变', (tester) async {
    useFixedView(tester);
    const keyboardHeight = 300.0;

    await tester.pumpWidget(host(serviceWithMessages(), 0));
    await tester.pump();
    await tester.pump();

    final appBarTopBefore = tester.getTopLeft(find.byType(ChatDetailAppBar)).dy;
    final listTopBefore = tester
        .getTopLeft(find.byType(ChatMessageListSection))
        .dy;

    await tester.pumpWidget(host(serviceWithMessages(), keyboardHeight));
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.byType(ChatDetailAppBar)).dy,
      appBarTopBefore,
      reason: '键盘弹出不应移动顶栏',
    );
    expect(
      tester.getTopLeft(find.byType(ChatMessageListSection)).dy,
      listTopBefore,
      reason: '键盘弹出不应移动消息列表顶部（body 不随键盘重排）',
    );

    // 屏幕级集成断言：会话页必须把键盘高度**真正传给** ChatInput，
    // 否则输入行不会浮到键盘之上（曾在真机上出现：漏传 keyboardInset → 输入行被键盘挡住）。
    // 只测 ChatInput 自身是抓不到这个问题的，必须在这一层验证。
    final keyboardTop = _screenHeight - keyboardHeight;
    final rowArea = tester.getRect(
      find.byKey(const ValueKey('chat_input_row_area')),
    );
    expect(
      rowArea.bottom,
      closeTo(keyboardTop, 2),
      reason: '会话页应把键盘高度传给 ChatInput，使输入行下沿贴住键盘上沿',
    );
  });

  // 业界模型：键盘弹起时列表让位（内容上移），最新消息必须露在输入行上方。
  // 如果失败，说明列表没让位，最新消息会被键盘盖住。
  testWidgets('键盘弹出时列表让位：最新消息露在输入行上方', (tester) async {
    useFixedView(tester);
    const keyboardHeight = 300.0;

    await tester.pumpWidget(host(serviceWithMessages(), 0));
    // 等输入区实测高度回填（异步 post-frame）稳定后再取样，避免把回填过程当成位移。
    await tester.pumpAndSettle();
    final before = tester.getRect(find.text('第一条'));

    await tester.pumpWidget(host(serviceWithMessages(), keyboardHeight));
    await tester.pumpAndSettle();

    final after = tester.getRect(find.text('第一条'));
    expect(
      after.top,
      lessThan(before.top),
      reason: '键盘弹出时列表应让位（内容上移），而不是被键盘盖住',
    );

    // 让位量 = 键盘高度 - 输入区原本占用的空间（对齐框架 resizeToAvoidBottomInset 的语义）
    final rowArea = tester.getRect(
      find.byKey(const ValueKey('chat_input_row_area')),
    );
    final lastMessageBottom = tester.getRect(find.text('第二条')).bottom;
    expect(
      lastMessageBottom,
      lessThanOrEqualTo(rowArea.top + 2),
      reason: '最新一条消息必须完全露在输入行上方（不被输入区/键盘遮挡）',
    );
    expect(
      rowArea.bottom,
      closeTo(_screenHeight - keyboardHeight, 2),
      reason: '输入行下沿仍应贴住键盘上沿',
    );
  });

  testWidgets('展开表情面板只影响底部：顶栏与消息列表顶部位置不变', (tester) async {
    useFixedView(tester);

    await tester.pumpWidget(host(serviceWithMessages(), 0));
    await tester.pump();
    await tester.pump();

    final appBarTopBefore = tester.getTopLeft(find.byType(ChatDetailAppBar)).dy;
    final listTopBefore = tester
        .getTopLeft(find.byType(ChatMessageListSection))
        .dy;
    final listBottomBefore = tester
        .getBottomLeft(find.byType(ChatMessageListSection))
        .dy;

    await tester.tap(find.byTooltip('表情'));
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.byType(ChatDetailAppBar)).dy,
      appBarTopBefore,
      reason: '展开面板不应移动顶栏',
    );
    expect(
      tester.getTopLeft(find.byType(ChatMessageListSection)).dy,
      listTopBefore,
      reason: '展开面板不应移动消息列表顶部',
    );
    // 面板占据底部空间 → 列表底部应当上移（为面板让位），这是预期行为。
    expect(
      tester.getBottomLeft(find.byType(ChatMessageListSection)).dy,
      lessThan(listBottomBefore),
      reason: '面板展开应占用底部空间，列表底部随之让位',
    );
  });

  // 业界模型的最后一块拼图：面板高度未必等于键盘高度，且键盘收起时手势条会回来，
  // 因此面板必须按「记忆的键盘高度 − 手势条」占位，否则面板态与键盘态之间
  // 输入行（连同消息内容）会整体下沉/上浮十几到二十几像素，看起来就是抖一下。
  testWidgets('面板态与键盘态输入行位置一致（含手势条安全区）', (tester) async {
    useFixedView(tester);
    const keyboardHeight = 322.0;
    const gestureBar = 24.0;

    // 面板展开态（键盘收起，手势条占位）
    await tester.pumpWidget(
      host(
        serviceWithMessages(),
        0,
        padding: const EdgeInsets.only(bottom: gestureBar),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('表情'));
    await tester.pumpAndSettle();
    final rowWithPanel = tester.getRect(
      find.byKey(const ValueKey('chat_input_row_area')),
    );
    final messageWithPanel = tester.getRect(find.text('第一条'));

    // 同一面板状态下弹起键盘（面板不关闭，被键盘盖住）
    await tester.pumpWidget(
      host(
        serviceWithMessages(),
        keyboardHeight,
        padding: const EdgeInsets.only(bottom: gestureBar),
      ),
    );
    await tester.pumpAndSettle();
    final rowWithKeyboard = tester.getRect(
      find.byKey(const ValueKey('chat_input_row_area')),
    );

    expect(
      rowWithKeyboard.bottom,
      closeTo(rowWithPanel.bottom, 2),
      reason: '面板态与键盘态的输入行位置必须一致（否则切换时会整体位移）',
    );
    expect(
      tester.getRect(find.text('第一条')),
      messageWithPanel,
      reason: '面板 ↔ 键盘切换时消息内容不得位移',
    );
    expect(
      rowWithKeyboard.bottom,
      closeTo(_screenHeight - keyboardHeight, 2),
      reason: '输入行下沿仍应贴住键盘上沿',
    );
  });

  // 真机上暴露过的坑：键盘收起动画会先经过一串中间值（最后还剩一个导航栏高度的
  // 尾巴 24），若直接记「最后一个非零 inset」，记住的键盘高度就变成 24，
  // 面板占位随之缩水，切回面板时输入行又掉下去一截。
  testWidgets('键盘收起动画的中间值不会污染记忆的键盘高度', (tester) async {
    useFixedView(tester);
    const keyboardHeight = 322.0;

    await tester.pumpWidget(host(serviceWithMessages(), 0));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('表情'));
    await tester.pumpAndSettle();

    // 键盘弹起（面板被盖住），再按真实收起的轨迹回落：322 → 24 → 0
    await tester.pumpWidget(host(serviceWithMessages(), keyboardHeight));
    await tester.pumpAndSettle();
    final rowWithKeyboard = tester.getRect(
      find.byKey(const ValueKey('chat_input_row_area')),
    );
    await tester.pumpWidget(host(serviceWithMessages(), 24));
    await tester.pumpAndSettle();
    await tester.pumpWidget(host(serviceWithMessages(), 0));
    await tester.pumpAndSettle();

    expect(
      tester.getRect(find.byKey(const ValueKey('chat_input_row_area'))),
      rowWithKeyboard,
      reason: '键盘完全收起后面板应收住输入行，位置与键盘态一致（记忆高度取峰值，不取尾巴）',
    );
  });
}
