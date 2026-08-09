import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'package:flutter_rust_demo/providers/message_service_provider.dart';
import 'package:flutter_rust_demo/providers/user_profile_provider.dart';
import 'package:flutter_rust_demo/screens/chat_detail_screen.dart';
import 'package:flutter_rust_demo/services/message_service_notifier.dart';
import 'package:flutter_rust_demo/src/rust/event/events/message.dart';
import 'package:flutter_rust_demo/src/rust/model/local.dart';
import 'package:flutter_rust_demo/src/rust/model/message.dart';
import 'package:flutter_rust_demo/src/rust/model/user.dart';

const _convId = 'si_user_a_user_b';

MessageInfo _makeMessage(
  String clientMsgId,
  String content,
  int seq,
  int sendTime,
  String sendId,
) => MessageInfo(
  clientMsgId: clientMsgId,
  serverMsgId: '',
  sendId: sendId,
  recvId: 'user_a',
  groupId: '',
  senderPlatformId: 0,
  senderNickname: '对方',
  senderFaceUrl: '',
  sessionType: 1,
  msgFrom: 0,
  contentType: 101,
  content: '{"content":"$content"}',
  seq: seq,
  sendTime: sendTime,
  createTime: sendTime,
  status: 2,
  isRead: false,
  attachedInfo: '',
  ex: '',
);

LocalConversation _makeConversation({int unreadCount = 0}) => LocalConversation(
  conversationId: _convId,
  conversationType: 1,
  userId: 'user_b',
  groupId: '',
  showName: '张三',
  faceUrl: '',
  latestMsg: '',
  latestMsgSendTime: 0,
  unreadCount: unreadCount,
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

Widget _buildHost(MessageServiceNotifier service) {
  return ProviderScope(
    overrides: [
      messageServiceProvider.overrideWith((ref) => service),
      userProfileProvider.overrideWith((ref) => UserProfileNotifier(ref)),
    ],
    child: const MaterialApp(home: ChatDetailScreen(conversationId: _convId)),
  );
}

void main() {
  // visibility_detector 在 widget 测试中会调度 500ms timer，设为立即更新避免 pending timer
  VisibilityDetectorController.instance.updateInterval = Duration.zero;

  testWidgets('进入会话后渲染会话名和已有消息', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final service = MessageServiceNotifier();
    service.state = MessageServiceState(
      currentUserId: 'user_a',
      conversations: [_makeConversation()],
      messages: {
        _convId: [_makeMessage('m1', '你好', 1, 1000, 'user_b')],
      },
      userProfiles: {
        'user_a': const UserInfo(
          userId: 'user_a',
          nickname: '我',
          faceUrl: '',
          gender: 0,
          telephone: '',
          email: '',
          remark: '',
          globalRecvMsgOpt: 0,
        ),
      },
    );

    await tester.pumpWidget(_buildHost(service));
    await tester.pump();
    await tester.pump();

    expect(find.text('张三'), findsOneWidget);
    expect(find.text('你好'), findsOneWidget);
  });

  testWidgets('收到对方新消息后消息列表自动追加', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final service = MessageServiceNotifier();
    service.state = MessageServiceState(
      currentUserId: 'user_a',
      conversations: [_makeConversation()],
      messages: {
        _convId: [_makeMessage('m1', '旧消息', 1, 1000, 'user_b')],
      },
    );

    await tester.pumpWidget(_buildHost(service));
    await tester.pump();
    await tester.pump();
    expect(find.text('旧消息'), findsOneWidget);

    service.onMessageEventForTest(
      MessageEvent.newMessage(
        conversationId: _convId,
        message: _makeMessage('m2', '新消息', 2, 2000, 'user_b'),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('旧消息'), findsOneWidget);
    expect(find.text('新消息'), findsOneWidget);
  });

  testWidgets('会话未读徽标随未读数变化', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final service = MessageServiceNotifier();
    service.state = MessageServiceState(
      currentUserId: 'user_a',
      conversations: [_makeConversation(unreadCount: 2)],
    );

    await tester.pumpWidget(_buildHost(service));
    await tester.pump();
    await tester.pump();

    final badge = find.descendant(
      of: find.byType(AppBar),
      matching: find.text('2'),
    );
    expect(badge, findsOneWidget);

    service.state = service.currentState.copyWith(
      conversations: [_makeConversation(unreadCount: 0)],
    );
    await tester.pump();
    await tester.pump();

    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('2')),
      findsNothing,
    );
  });
}
