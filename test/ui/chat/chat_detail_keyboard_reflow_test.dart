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

/// 键盘/面板变化时「只有底部在动」（对齐飞书实机录屏测得的观感）：
///
/// 顶栏与消息列表**顶部**位置必须完全不变，只有列表底部与输入区在动。
/// 这是用户反馈的「全局抖动」的直接对立面，也与具体机型无关（断言的是相对位置）。
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

Widget host(MessageServiceNotifier service, double keyboardHeight) {
  return ProviderScope(
    overrides: [
      messageServiceProvider.overrideWith(() => service),
      userProfileProvider.overrideWith(() => UserProfileNotifier()),
    ],
    child: MaterialApp(
      home: const ChatDetailScreen(conversationId: _convId),
      // 注入键盘高度：必须放在 MaterialApp 的 builder 里，否则会被上层 MediaQuery 覆盖。
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(viewInsets: EdgeInsets.only(bottom: keyboardHeight)),
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
  });

  // 飞书实机录屏测得的关键性质：键盘从下往上升起时，**消息内容一像素都不移动**，
  // 键盘直接盖在列表之上。这一条如果失败，说明列表还在为键盘让位。
  testWidgets('键盘弹出时消息内容不位移（键盘盖在列表之上）', (tester) async {
    useFixedView(tester);
    const keyboardHeight = 300.0;

    await tester.pumpWidget(host(serviceWithMessages(), 0));
    // 等输入区实测高度回填（异步 post-frame）稳定后再取样，避免把回填过程当成位移。
    await tester.pumpAndSettle();
    final before = tester.getRect(find.text('第一条'));

    await tester.pumpWidget(host(serviceWithMessages(), keyboardHeight));
    await tester.pumpAndSettle();

    expect(
      tester.getRect(find.text('第一条')),
      before,
      reason: '键盘弹出不应让消息内容位移（对齐飞书：键盘盖在列表之上）',
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
}
