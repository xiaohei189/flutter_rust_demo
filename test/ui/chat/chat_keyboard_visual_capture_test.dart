// 视觉取证：把会话页在三种状态下渲染成 PNG，并在底部画出**键盘区域**标线，
// 用于人工核对「输入行是否浮在键盘之上」「面板是否留在底部被键盘覆盖」
// 「消息内容是否为键盘让位」。
//
// 这三张图是几何断言的补充证据（断言只给数字，图能一眼看出布局是否合理）：
//   goldens/chat_kbd300_panel.png   键盘 + 面板：输入行在键盘上、面板被键盘覆盖，
//                                   消息位置与「只有键盘」那张完全一致（切换零位移）
//   goldens/chat_kbd300_nopanel.png 键盘：消息为键盘让位，停在输入行上方（业界模型）
//   goldens/chat_nokbd_panel.png    面板：面板贴底、输入行在其上沿
//
// 注意：仓库 .gitignore 忽略 *.png，这三张基准图**不入库**。
// 本地缺少基准图时用例自动跳过（不打扰他人与 CI）；需要时用
// `flutter test test/ui/chat/chat_keyboard_visual_capture_test.dart --update-goldens`
// 生成，之后本用例即可校验布局是否漂移。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'package:flutter_rust_demo/application/chat/message_service_notifier.dart';
import 'package:flutter_rust_demo/domain/models/chat_message.dart'
    show ChatMessage;
import 'package:flutter_rust_demo/domain/models/conversation.dart';
import 'package:flutter_rust_demo/ui/chat/providers/message_service_provider.dart';
import 'package:flutter_rust_demo/ui/chat/views/chat_detail_screen.dart';
import 'package:flutter_rust_demo/ui/profile/providers/user_profile_provider.dart';
import 'package:flutter_rust_demo/ui/profile/view_models/user_profile_view_model.dart';

const _convId = 'si_user_a_user_b';
const _width = 400.0;
const _height = 800.0;

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

ChatMessage _message(String id, String text, int sendTime) => ChatMessage(
  clientMsgId: id,
  serverMsgId: '',
  sendId: sendTime.isEven ? 'user_b' : 'user_a',
  recvId: 'user_a',
  groupId: '',
  senderPlatformId: 0,
  senderNickname: '对方',
  senderFaceUrl: '',
  sessionType: 1,
  msgFrom: 0,
  contentType: 101,
  content: '{"content":"$text"}',
  seq: sendTime,
  sendTime: sendTime,
  createTime: sendTime,
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

void main() {
  // 语音录制插件（record）在测试环境没有原生实现，注册空 handler 消除
  // MissingPluginException（会话页初始化时会构造 AudioRecorder）。
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.llfbandit.record/messages'),
          (call) async => null,
        );
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  /// 渲染会话页；[keyboardHeight] > 0 时在底部画出半透明「键盘区域」标线。
  Widget host(MessageServiceNotifier service, double keyboardHeight) {
    return ProviderScope(
      overrides: [
        messageServiceProvider.overrideWith(() => service),
        userProfileProvider.overrideWith(() => UserProfileNotifier()),
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: const Size(_width, _height),
            viewInsets: EdgeInsets.only(bottom: keyboardHeight),
          ),
          child: Scaffold(
            resizeToAvoidBottomInset: false,
            body: Stack(
              children: [
                const ChatDetailScreen(conversationId: _convId),
                if (keyboardHeight > 0)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: keyboardHeight,
                    child: const ColoredBox(
                      color: Color(0x33FF0000),
                      child: Center(child: Text('KEYBOARD AREA')),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  MessageServiceNotifier service() => _TestService(
    MessageServiceState(
      currentUserId: 'user_a',
      conversations: [_conversation()],
      messages: {
        _convId: [
          _message('m1', '第一条消息', 1000),
          _message('m2', '第二条消息', 2000),
          _message('m3', '第三条消息', 3000),
        ],
      },
    ),
  );

  Future<void> capture(
    WidgetTester tester,
    String name, {
    required double keyboardHeight,
    required bool openPanel,
  }) async {
    tester.view.physicalSize = const Size(_width * 2, _height * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    // 基准图不入库（.gitignore 忽略 *.png）：本地没有就跳过，避免他人跑测试时失败。
    final golden = File('test/ui/chat/goldens/$name.png');
    if (!golden.existsSync()) {
      markTestSkipped('缺少基准图 $name.png，跳过（用 --update-goldens 生成）');
      return;
    }

    await tester.pumpWidget(host(service(), keyboardHeight));
    await tester.pumpAndSettle();
    if (openPanel) {
      await tester.tap(find.byTooltip('表情'));
      await tester.pumpAndSettle();
    }
    await expectLater(
      find.byType(Stack).first,
      matchesGoldenFile('goldens/$name.png'),
    );
  }

  testWidgets('capture keyboard+panel', (tester) async {
    await capture(
      tester,
      'chat_kbd300_panel',
      keyboardHeight: 300,
      openPanel: true,
    );
  });

  testWidgets('capture keyboard only', (tester) async {
    await capture(
      tester,
      'chat_kbd300_nopanel',
      keyboardHeight: 300,
      openPanel: false,
    );
  });

  testWidgets('capture panel only', (tester) async {
    await capture(
      tester,
      'chat_nokbd_panel',
      keyboardHeight: 0,
      openPanel: true,
    );
  });
}
