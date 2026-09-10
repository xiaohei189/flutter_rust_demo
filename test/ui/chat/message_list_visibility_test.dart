import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'package:flutter_rust_demo/application/chat/message_service_notifier.dart';
import 'package:flutter_rust_demo/domain/models/chat_message.dart' show ChatMessage;
import 'package:flutter_rust_demo/domain/models/user.dart';
import 'package:flutter_rust_demo/ui/chat/providers/message_service_provider.dart';
import 'package:flutter_rust_demo/ui/chat/widgets/list/chat_message_list_section.dart';

const _conversationId = 'si_user_a_user_b';

class _FakeMessageService extends MessageServiceNotifier {
  _FakeMessageService(this._fake);

  MessageServiceState _fake;

  @override
  MessageServiceState build() => _fake;

  @override
  MessageServiceState get currentState => _fake;

  @override
  void updateState(MessageServiceState next) {
    _fake = next;
    state = next;
  }
}

ChatMessage _message(
  String id, {
  required bool isRead,
  String sendId = 'user_b',
  int seq = 1,
}) => ChatMessage(
  clientMsgId: id,
  serverMsgId: '',
  sendId: sendId,
  recvId: 'user_a',
  groupId: '',
  senderPlatformId: 0,
  senderNickname: '张三',
  senderFaceUrl: '',
  sessionType: 1,
  msgFrom: 0,
  contentType: 101,
  content: '{"content":"$id"}',
  seq: seq,
  sendTime: 1700000000000,
  createTime: 1700000000000,
  status: 2,
  isRead: isRead,
  attachedInfo: '',
  ex: '',
);

MessageServiceState _state(List<ChatMessage> messages) => MessageServiceState(
  currentUserId: 'user_a',
  conversations: const [],
  messages: {_conversationId: messages},
);

Widget _host(
  MessageServiceNotifier service, {
  required void Function(ChatMessage message) onVisible,
}) {
  return ProviderScope(
    overrides: [messageServiceProvider.overrideWith(() => service)],
    child: MaterialApp(
      home: Scaffold(
        body: ChatMessageListSection(
          conversationId: _conversationId,
          user: const User(id: 'user_b', name: '张三'),
          currentUserId: 'user_a',
          currentUserAvatar: null,
          scrollController: ScrollController(),
          isLoading: false,
          selectMode: false,
          selectedClientMsgIds: const {},
          messageReactions: const {},
          onMessageVisible: onVisible,
          onMessageTap: (_) {},
        ),
      ),
    ),
  );
}

void main() {
  setUp(() {
    // 让可见性回调在每帧结束触发，避免测试中残留 500ms 定时器。
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  testWidgets('历史消息全部已读时不挂可见性检测', (tester) async {
    final service = _FakeMessageService(
      _state([_message('m1', isRead: true)]),
    );
    var visibleCount = 0;

    await tester.pumpWidget(
      _host(service, onVisible: (_) => visibleCount++),
    );
    await tester.pump();

    expect(find.text('m1'), findsOneWidget);
    expect(find.byType(VisibilityDetector), findsNothing);
    expect(visibleCount, 0);
  });

  testWidgets('存在未读的对方消息时挂可见性检测并回调', (tester) async {
    final service = _FakeMessageService(
      _state([_message('m1', isRead: false)]),
    );
    final visibleIds = <String>[];

    await tester.pumpWidget(
      _host(service, onVisible: (m) => visibleIds.add(m.clientMsgId)),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(VisibilityDetector), findsWidgets);
    expect(visibleIds, contains('m1'));
  });

  testWidgets('新到达未读消息后重新启用可见性检测', (tester) async {
    final service = _FakeMessageService(
      _state([_message('m1', isRead: true)]),
    );
    final visibleIds = <String>[];

    await tester.pumpWidget(
      _host(service, onVisible: (m) => visibleIds.add(m.clientMsgId)),
    );
    await tester.pump();
    expect(find.byType(VisibilityDetector), findsNothing);

    service.updateState(
      service.currentState.copyWith(
        messages: {
          _conversationId: [
            _message('m1', isRead: true),
            _message('m2', isRead: false, seq: 2),
          ],
        },
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(VisibilityDetector), findsWidgets);
    expect(visibleIds, contains('m2'));
  });
}
