import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_rust_demo/application/chat/message_send_controller.dart';
import 'package:flutter_rust_demo/application/chat/message_service_notifier.dart';
import 'package:flutter_rust_demo/application/chat/message_service_state.dart';
import 'package:flutter_rust_demo/data/repositories/message_repository.dart';
import 'package:flutter_rust_demo/data/services/im_client.dart';
import 'package:flutter_rust_demo/domain/models/chat_session_type.dart'
    show ChatSessionType;

class _FakeService extends MessageServiceNotifier {
  @override
  MessageServiceState build() => MessageServiceState();
}

class _FakeRepo implements MessageRepository {
  final calls = <String>[];

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final name = invocation.memberName.toString();
    final sessionType = invocation.namedArguments[const Symbol('sessionType')];
    calls.add('$name:$sessionType');
    if (invocation.memberName == #sendTyping ||
        invocation.memberName == #sendMergerMessage ||
        invocation.memberName == #forwardMessage) {
      return Future.value();
    }
    throw UnimplementedError(name);
  }
}

void main() {
  test('sendTyping 委托仓库并转换会话类型', () async {
    final repo = _FakeRepo();
    final controller = MessageSendController(
      _FakeService(),
      repo,
      ImClient.instance,
    );

    await controller.sendTyping(
      sourceId: 'u1',
      sessionType: ChatSessionType.singleChat,
      focus: true,
    );

    expect(repo.calls.single, contains('sendTyping'));
    expect(repo.calls.single, contains('SessionType.singleChat'));
  });

  test('客户端未初始化时发送文本抛出 StateError', () {
    final controller = MessageSendController(
      _FakeService(),
      _FakeRepo(),
      ImClient.instance,
    );

    expect(
      () => controller.sendTextMessage(
        text: 'hi',
        recvId: 'u1',
        conversationId: 'c1',
        sessionType: ChatSessionType.singleChat,
      ),
      throwsStateError,
    );
  });
}
