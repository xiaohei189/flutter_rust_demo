import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_rust_demo/application/chat/message_service_notifier.dart';
import 'package:flutter_rust_demo/application/chat/message_service_state.dart';
import 'package:flutter_rust_demo/application/chat/search_messages_use_case.dart';
import 'package:flutter_rust_demo/domain/models/message_search_result.dart';

class _FakeService extends MessageServiceNotifier {
  final calls = <String>[];

  @override
  MessageServiceState build() => MessageServiceState();

  @override
  Future<List<MessageSearchResult>> searchLocalMessages({
    required String conversationId,
    required String keyword,
    int offset = 0,
    int count = 50,
  }) async {
    calls.add('$conversationId:$keyword');
    return [
      MessageSearchResult(
        conversationId: conversationId,
        clientMsgId: 'm1',
        serverMsgId: '',
        sendId: 'u1',
        recvId: 'u2',
        senderPlatformId: 0,
        senderNickName: '张三',
        senderFaceUrl: '',
        sessionType: 1,
        msgFrom: 0,
        contentType: 101,
        content: '{"content":"hi"}',
        isRead: false,
        status: 2,
        seq: 0,
        sendTime: 0,
        createTime: 0,
        attachedInfo: '',
        ex: '',
        localEx: '',
        groupId: '',
      ),
    ];
  }
}

void main() {
  test('空关键字短路返回空列表', () async {
    final service = _FakeService();
    final useCase = SearchMessagesUseCase(messageService: service);
    final result = await useCase.search('c1', '   ');
    expect(result, isEmpty);
    expect(service.calls, isEmpty);
  });

  test('非空关键字委托消息服务', () async {
    final service = _FakeService();
    final useCase = SearchMessagesUseCase(messageService: service);
    final result = await useCase.search('c1', 'hello');
    expect(service.calls, ['c1:hello']);
    expect(result, hasLength(1));
  });
}
