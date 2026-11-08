import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_rust_demo/application/chat/message_service_notifier.dart';
import 'package:flutter_rust_demo/application/chat/topic_event_revision_provider.dart';
import 'package:flutter_rust_demo/ui/chat/providers/message_service_provider.dart';
import '../../support/fakes/fake_message_repository.dart';
import 'package:flutter_rust_demo/generated/rust/core/event/events/message.dart';
import 'package:flutter_rust_demo/generated/rust/domain/model/message.dart'
    show MessageInfo;

MessageInfo _makeMessage(
  String clientMsgId,
  int seq,
  int sendTime, {
  int contentType = 101,
  String content = '{"content":"hello"}',
}) => MessageInfo(
  clientMsgId: clientMsgId,
  serverMsgId: '',
  sendId: 'user_b',
  recvId: 'user_a',
  groupId: '',
  senderPlatformId: 0,
  senderNickname: '对方',
  senderFaceUrl: '',
  sessionType: 1,
  msgFrom: 0,
  contentType: contentType,
  content: content,
  seq: seq,
  sendTime: sendTime,
  createTime: sendTime,
  status: 2,
  isRead: false,
  attachedInfo: '',
  ex: '',
  topicId: '',
);

MessageServiceNotifier buildNotifier() {
  final container = ProviderContainer(
    overrides: [
      messageRepositoryProvider.overrideWithValue(FakeMessageRepository()),
    ],
  );
  addTearDown(container.dispose);
  return container.read(messageServiceProvider.notifier);
}

void main() {
  group('MessageServiceNotifier 新消息事件', () {
    test('收到 newMessage 事件后消息列表自动追加', () {
      final notifier = buildNotifier();
      final message = _makeMessage('m1', 1, 1000);

      notifier.onMessageEventForTest(
        MessageEvent.newMessage(
          conversationId: 'si_user_a_user_b',
          message: message,
        ),
      );

      final list = notifier.getMessages('si_user_a_user_b');
      expect(list.length, 1);
      expect(list.first.clientMsgId, 'm1');
      expect(list.first.content, contains('hello'));
    });

    test('重复新消息事件不会重复追加', () {
      final notifier = buildNotifier();
      final event = MessageEvent.newMessage(
        conversationId: 'si_user_a_user_b',
        message: _makeMessage('m1', 1, 1000),
      );

      notifier.onMessageEventForTest(event);
      notifier.onMessageEventForTest(event);

      expect(notifier.getMessages('si_user_a_user_b').length, 1);
    });

    test('不同会话的新消息写入各自列表', () {
      final notifier = buildNotifier();

      notifier.onMessageEventForTest(
        MessageEvent.newMessage(
          conversationId: 'si_a_b',
          message: _makeMessage('m1', 1, 1000),
        ),
      );
      notifier.onMessageEventForTest(
        MessageEvent.newMessage(
          conversationId: 'g_group1',
          message: _makeMessage('m2', 2, 2000),
        ),
      );

      expect(notifier.getMessages('si_a_b').length, 1);
      expect(notifier.getMessages('g_group1').length, 1);
    });

    test('Topic 控制事件不进入消息列表，只递增话题 revision', () {
      final container = ProviderContainer(
        overrides: [
          messageRepositoryProvider.overrideWithValue(FakeMessageRepository()),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(messageServiceProvider.notifier);
      final before = container.read(topicEventRevisionProvider);

      notifier.onMessageEventForTest(
        MessageEvent.newMessage(
          conversationId: 'sg_g1',
          message: _makeMessage(
            'topic_event_1',
            0,
            1000,
            contentType: 120,
            content: '{"data":"{\\"type\\":\\"openim.topic.event\\"}" }',
          ),
        ),
      );

      expect(notifier.getMessages('sg_g1'), isEmpty);
      expect(container.read(topicEventRevisionProvider), before + 1);
    });

    test('阅读控制事件使用独立 revision，避免详情页刷新循环', () {
      final container = ProviderContainer(
        overrides: [
          messageRepositoryProvider.overrideWithValue(FakeMessageRepository()),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(messageServiceProvider.notifier);
      final topicBefore = container.read(topicEventRevisionProvider);
      final readBefore = container.read(topicReadRevisionProvider);

      notifier.onMessageEventForTest(
        MessageEvent.newMessage(
          conversationId: 'sn_u1',
          message: _makeMessage(
            'topic_read_event_1',
            0,
            1000,
            contentType: 120,
            content:
                '{"data":"{\\"type\\":\\"openim.topic.event\\",'
                '\\"action\\":\\"topic_read_changed\\"}"}',
          ),
        ),
      );

      expect(notifier.getMessages('sn_u1'), isEmpty);
      expect(container.read(topicEventRevisionProvider), topicBefore);
      expect(container.read(topicReadRevisionProvider), readBefore + 1);
    });
  });
}
