import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_rust_demo/application/chat/message_history_controller.dart';
import 'package:flutter_rust_demo/application/chat/message_service_notifier.dart';
import 'package:flutter_rust_demo/application/chat/message_service_state.dart';
import 'package:flutter_rust_demo/data/repositories/message_repository.dart';
import 'package:flutter_rust_demo/data/services/im_client.dart';
import 'package:flutter_rust_demo/domain/models/chat_message.dart'
    show ChatMessage, MessageHistoryPage;

class _FakeService extends MessageServiceNotifier {
  MessageServiceState _fake = MessageServiceState();

  @override
  MessageServiceState build() => _fake;

  @override
  MessageServiceState get currentState => _fake;

  @override
  void updateState(MessageServiceState next) {
    _fake = next;
  }
}

class _FakeRepo implements MessageRepository {
  final List<ChatMessage> history = [];

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #getHistoryMessages) {
      return Future.value(
        MessageHistoryPage(messages: List.of(history), isEnd: true),
      );
    }
    throw UnimplementedError(invocation.memberName.toString());
  }
}

ChatMessage _message(String id, int seq, String content) => ChatMessage(
  clientMsgId: id,
  serverMsgId: '',
  sendId: 'u1',
  recvId: 'u2',
  groupId: '',
  senderPlatformId: 0,
  senderNickname: '张三',
  senderFaceUrl: '',
  sessionType: 1,
  msgFrom: 0,
  contentType: 101,
  content: '{"content":"$content"}',
  seq: seq,
  sendTime: 0,
  createTime: 0,
  status: 2,
  isRead: false,
  attachedInfo: '',
  ex: '',
);

void main() {
  test('upsertSentMessage 写入并去重', () {
    final service = _FakeService();
    final controller = MessageHistoryController(
      service,
      ImClient.instance,
      _FakeRepo(),
    );
    controller.upsertSentMessage('c1', _message('m1', 1, 'hi'));
    expect(service.currentState.messages['c1'], hasLength(1));
    controller.upsertSentMessage('c1', _message('m1', 1, 'hi'));
    expect(service.currentState.messages['c1'], hasLength(1));
  });

  test('removeMessage 移除指定消息', () {
    final service = _FakeService();
    final controller = MessageHistoryController(
      service,
      ImClient.instance,
      _FakeRepo(),
    );
    controller.upsertSentMessage('c1', _message('m1', 1, 'a'));
    controller.upsertSentMessage('c1', _message('m2', 2, 'b'));
    controller.removeMessage('c1', 'm1');
    expect(service.currentState.messages['c1']!.map((m) => m.clientMsgId), [
      'm2',
    ]);
  });

  test('getMessages 返回不可变列表', () {
    final service = _FakeService();
    final controller = MessageHistoryController(
      service,
      ImClient.instance,
      _FakeRepo(),
    );
    controller.upsertSentMessage('c1', _message('m1', 1, 'a'));
    final messages = controller.getMessages('c1');
    expect(messages, hasLength(1));
    expect(() => messages.add(_message('m2', 2, 'b')), throwsUnsupportedError);
  });
}
