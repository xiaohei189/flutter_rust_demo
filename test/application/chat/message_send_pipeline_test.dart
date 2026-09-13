import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_rust_demo/application/chat/message_send_pipeline.dart';
import 'package:flutter_rust_demo/application/chat/message_service_notifier.dart';
import 'package:flutter_rust_demo/application/chat/message_service_reducer.dart';
import 'package:flutter_rust_demo/application/chat/message_service_state.dart';
import 'package:flutter_rust_demo/data/repositories/message_repository.dart';
import 'package:flutter_rust_demo/domain/models/chat_message.dart'
    show ChatMessage;
import 'package:flutter_rust_demo/domain/models/chat_session_type.dart'
    show ChatSessionType;
import 'package:flutter_rust_demo/domain/models/message.dart'
    show MessageSendStatus;
import 'package:flutter_rust_demo/generated/rust/constant/enums.dart'
    show SessionType;
import 'package:flutter_rust_demo/generated/rust/model/msg_struct.dart'
    show MsgStruct;

/// 只用真实 Reducer 维护状态，避免依赖 FFI 客户端。
class _FakeService extends MessageServiceNotifier {
  MessageServiceState _state = MessageServiceState(currentUserId: 'u1');

  @override
  MessageServiceState build() => _state;

  @override
  MessageServiceState get currentState => _state;

  @override
  void updateState(MessageServiceState next) => _state = next;

  @override
  void upsertSentMessage(String conversationId, ChatMessage result) =>
      updateState(
        MessageServiceReducer.appendIncomingMessage(
          currentState,
          conversationId,
          result,
        ),
      );

  @override
  void applySendStatus(String conversationId, String clientMsgId, int status) =>
      updateState(
        MessageServiceReducer.applySendStatus(
          currentState,
          conversationId,
          clientMsgId,
          status,
        ),
      );

  @override
  void mergeSentMessage(
    String conversationId,
    String clientMsgId,
    ChatMessage sent,
  ) => updateState(
    MessageServiceReducer.mergeSentMessage(
      currentState,
      conversationId,
      clientMsgId,
      sent,
    ),
  );
}

/// 本地构造返回 clientMsgId=m1 的文本消息；发送结果由测试用 Completer 控制。
class _FakeRepo implements MessageRepository {
  final List<String> calls = [];
  Completer<ChatMessage> sendCompleter = Completer<ChatMessage>();

  @override
  Future<MsgStruct> createTextMessage({required String text}) async {
    calls.add('create:$text');
    return _localMessage(text: text);
  }

  @override
  Future<ChatMessage> sendPreparedMessage({
    required MsgStruct message,
    required String sourceId,
    required SessionType sessionType,
  }) {
    calls.add('send:${message.clientMsgId}:$sourceId:${sessionType.name}');
    return sendCompleter.future;
  }

  @override
  Future<ChatMessage> resendMessage({
    required ChatMessage message,
    required String sourceId,
    required SessionType sessionType,
  }) {
    calls.add('resend:${message.clientMsgId}:$sourceId:${sessionType.name}');
    return sendCompleter.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

MsgStruct _localMessage({required String text, String clientMsgId = 'm1'}) =>
    MsgStruct(
      clientMsgId: clientMsgId,
      serverMsgId: '',
      createTime: 1700000000000,
      sendTime: 1700000000000,
      sessionType: 1,
      sendId: '',
      recvId: '',
      msgFrom: 100,
      contentType: 101,
      senderPlatformId: 5,
      senderNickname: '',
      senderFaceUrl: '',
      groupId: '',
      content: '{"content":"$text"}',
      seq: 0,
      isRead: false,
      status: MessageSendStatus.sending.value,
      attachedInfo: '',
      ex: '',
      localEx: '',
    );

ChatMessage _serverConfirmed({
  String clientMsgId = 'm1',
  int seq = 7,
  String serverMsgId = 'srv-1',
}) => ChatMessage(
  clientMsgId: clientMsgId,
  serverMsgId: serverMsgId,
  sendId: 'u1',
  recvId: 'u2',
  groupId: '',
  senderPlatformId: 5,
  senderNickname: '我',
  senderFaceUrl: '',
  sessionType: 1,
  msgFrom: 100,
  contentType: 101,
  content: '{"content":"hi"}',
  seq: seq,
  sendTime: 1700000000000,
  createTime: 1700000000000,
  status: MessageSendStatus.sendSuccess.value,
  isRead: false,
  attachedInfo: '',
  ex: '',
);

MessageSendPipeline _pipeline(_FakeService service, _FakeRepo repo) =>
    MessageSendPipeline(
      service: service,
      repository: repo,
      isClientReady: () => true,
    );

void main() {
  test('发送先本地构造并乐观上屏（对齐 Go CreateXxxMessage + add）', () async {
    final repo = _FakeRepo();
    final service = _FakeService();

    final pending = await _pipeline(service, repo).sendText(
      conversationId: 'c1',
      sourceId: 'u2',
      sessionType: ChatSessionType.singleChat,
      text: 'hi',
    );

    // 尚未收到网络结果，气泡已在列表中且状态为「发送中」
    final list = service.currentState.messages['c1']!;
    expect(list, hasLength(1));
    expect(list.single.clientMsgId, 'm1');
    expect(list.single.status, MessageSendStatus.sending.value);
    expect(list.single.sendId, 'u1');
    expect(list.single.recvId, 'u2');

    // 发送用的就是本地构造的那一条（id 一致，服务端回执/去重才能对齐）
    expect(repo.calls, ['create:hi', 'send:m1:u2:singleChat']);
    expect(pending.message.clientMsgId, 'm1');
  });

  test('发送成功：就地合并服务端字段，不新增气泡', () async {
    final repo = _FakeRepo();
    final service = _FakeService();

    final pending = await _pipeline(service, repo).sendText(
      conversationId: 'c1',
      sourceId: 'u2',
      sessionType: ChatSessionType.singleChat,
      text: 'hi',
    );
    repo.sendCompleter.complete(_serverConfirmed());
    final sent = await pending.done;

    expect(sent.serverMsgId, 'srv-1');
    final list = service.currentState.messages['c1']!;
    expect(list, hasLength(1));
    expect(list.single.clientMsgId, 'm1');
    expect(list.single.status, MessageSendStatus.sendSuccess.value);
    expect(list.single.seq, 7);
    expect(list.single.serverMsgId, 'srv-1');
  });

  test('发送失败：保留气泡并标为失败，重发沿用同一 clientMsgId', () async {
    final repo = _FakeRepo();
    final service = _FakeService();
    final pipeline = _pipeline(service, repo);

    final pending = await pipeline.sendText(
      conversationId: 'c1',
      sourceId: 'u2',
      sessionType: ChatSessionType.singleChat,
      text: 'hi',
    );
    repo.sendCompleter.completeError(Exception('网络不可用'));
    await expectLater(pending.done, throwsException);

    final afterFail = service.currentState.messages['c1']!;
    expect(afterFail, hasLength(1));
    expect(afterFail.single.status, MessageSendStatus.sendFailed.value);
    expect(afterFail.single.clientMsgId, 'm1');

    // 重发：同一条置回发送中（不新增条目），成功后仍只有一条
    repo.sendCompleter = Completer<ChatMessage>();
    final retry = await pipeline.resend(
      conversationId: 'c1',
      message: afterFail.single,
      sourceId: 'u2',
      sessionType: ChatSessionType.singleChat,
    );
    expect(service.currentState.messages['c1'], hasLength(1));
    expect(
      service.currentState.messages['c1']!.single.status,
      MessageSendStatus.sending.value,
    );

    repo.sendCompleter.complete(_serverConfirmed(seq: 8, serverMsgId: 'srv-2'));
    await retry.done;

    final afterRetry = service.currentState.messages['c1']!;
    expect(afterRetry, hasLength(1));
    expect(afterRetry.single.clientMsgId, 'm1');
    expect(afterRetry.single.status, MessageSendStatus.sendSuccess.value);
    expect(repo.calls.last, 'resend:m1:u2:singleChat');
  });

  test('客户端未初始化：发送前即失败，不写入任何消息', () async {
    final repo = _FakeRepo();
    final service = _FakeService();
    final pipeline = MessageSendPipeline(
      service: service,
      repository: repo,
      isClientReady: () => false,
    );

    await expectLater(
      pipeline.sendText(
        conversationId: 'c1',
        sourceId: 'u2',
        sessionType: ChatSessionType.singleChat,
        text: 'hi',
      ),
      throwsStateError,
    );
    expect(service.currentState.messages['c1'], isNull);
    expect(repo.calls, isEmpty);
  });
}
