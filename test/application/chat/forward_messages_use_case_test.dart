import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_rust_demo/application/chat/forward_messages_use_case.dart';
import 'package:flutter_rust_demo/application/chat/message_service_notifier.dart';
import 'package:flutter_rust_demo/application/chat/message_service_state.dart';
import 'package:flutter_rust_demo/domain/models/chat_message.dart'
    show ChatMessage;
import 'package:flutter_rust_demo/domain/models/chat_session_type.dart'
    show ChatSessionType;

ChatMessage _message(String id) => ChatMessage(
  clientMsgId: id,
  serverMsgId: '',
  sendId: 'user_a',
  recvId: 'user_b',
  groupId: '',
  senderPlatformId: 0,
  senderNickname: '张三',
  senderFaceUrl: '',
  sessionType: 1,
  msgFrom: 0,
  contentType: 101,
  content: '{"content":"hi"}',
  seq: 0,
  sendTime: 0,
  createTime: 0,
  status: 2,
  isRead: false,
  attachedInfo: '',
  ex: '',
);

class _FakeService extends MessageServiceNotifier {
  final List<String> calls = [];
  final Set<String> failTargets = {};
  Completer<void>? gate;

  @override
  MessageServiceState build() => MessageServiceState();

  @override
  Future<void> forwardMessage({
    required String clientMsgId,
    required String sourceId,
    required ChatSessionType sessionType,
  }) async {
    calls.add('forward:$sourceId');
    if (gate != null) await gate!.future;
    if (failTargets.contains(sourceId)) {
      throw Exception('send failed: $sourceId');
    }
  }

  @override
  Future<void> sendMergerMessage({
    required List<String> clientMsgIds,
    required String sourceConversationId,
    required String title,
    required List<String> summaryList,
    required String sourceId,
    required ChatSessionType sessionType,
  }) async {
    calls.add('merge:$sourceId');
    if (failTargets.contains(sourceId)) {
      throw Exception('merge failed: $sourceId');
    }
  }
}

void main() {
  test('全部目标转发成功', () async {
    final service = _FakeService();
    final useCase = ForwardMessagesUseCase(messageService: service);
    final outcome = await useCase.forwardToTargets(
      messages: [_message('m1')],
      summaryList: const ['hi'],
      targets: const [(id: 'g1', isGroup: true), (id: 'u9', isGroup: false)],
      merge: false,
    );

    expect(outcome.isOk, isTrue);
    expect(outcome.success, 2);
    expect(outcome.failed, 0);
    expect(useCase.hasFailedTargets, isFalse);
    expect(service.calls, ['forward:g1', 'forward:u9']);
  });

  test('部分失败后重试成功', () async {
    final service = _FakeService()..failTargets.add('u9');
    final useCase = ForwardMessagesUseCase(messageService: service);
    final first = await useCase.forwardToTargets(
      messages: [_message('m1')],
      summaryList: const ['hi'],
      targets: const [(id: 'g1', isGroup: true), (id: 'u9', isGroup: false)],
      merge: false,
    );

    expect(first.isOk, isFalse);
    expect(first.success, 1);
    expect(first.failed, 1);
    expect(useCase.hasFailedTargets, isTrue);

    service.failTargets.clear();
    final retry = await useCase.retryFailed();
    expect(retry.isOk, isTrue);
    expect(retry.success, 1);
    expect(useCase.hasFailedTargets, isFalse);
  });

  test('取消后跳过剩余目标', () async {
    final service = _FakeService()..gate = Completer<void>();
    final useCase = ForwardMessagesUseCase(messageService: service);
    final future = useCase.forwardToTargets(
      messages: [_message('m1')],
      summaryList: const ['hi'],
      targets: const [(id: 'g1', isGroup: true), (id: 'u9', isGroup: false)],
      merge: false,
    );

    useCase.cancel();
    service.gate!.complete();
    final outcome = await future;

    expect(outcome.cancelled, isTrue);
    expect(outcome.success, 1);
    expect(outcome.failed, 0);
    expect(service.calls, ['forward:g1']);
  });
}
