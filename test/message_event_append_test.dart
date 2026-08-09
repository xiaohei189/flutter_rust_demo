import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_rust_demo/services/message_service_notifier.dart';
import 'package:flutter_rust_demo/src/rust/event/events/message.dart';
import 'package:flutter_rust_demo/src/rust/model/message.dart';

MessageInfo _makeMessage(String clientMsgId, int seq, int sendTime) => MessageInfo(
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
      contentType: 101,
      content: '{"content":"hello"}',
      seq: seq,
      sendTime: sendTime,
      createTime: sendTime,
      status: 2,
      isRead: false,
      attachedInfo: '',
      ex: '',
    );

void main() {
  group('MessageServiceNotifier 新消息事件', () {
    test('收到 newMessage 事件后消息列表自动追加', () {
      final notifier = MessageServiceNotifier();
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
      final notifier = MessageServiceNotifier();
      final event = MessageEvent.newMessage(
        conversationId: 'si_user_a_user_b',
        message: _makeMessage('m1', 1, 1000),
      );

      notifier.onMessageEventForTest(event);
      notifier.onMessageEventForTest(event);

      expect(notifier.getMessages('si_user_a_user_b').length, 1);
    });

    test('不同会话的新消息写入各自列表', () {
      final notifier = MessageServiceNotifier();

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
  });
}
