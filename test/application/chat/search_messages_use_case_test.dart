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
    List<int> messageTypes = const [],
    bool allowEmptyKeyword = false,
  }) async {
    calls.add(
      '$conversationId:$keyword:${messageTypes.join(",")}:$allowEmptyKeyword',
    );
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
    expect(service.calls, ['c1:hello::false']);
    expect(result, hasLength(1));
  });

  test('空关键字但带类型过滤时同样委托（类型浏览）', () async {
    final service = _FakeService();
    final useCase = SearchMessagesUseCase(messageService: service);
    final result = await useCase.search('c1', '', messageTypes: [102, 104]);
    expect(service.calls, ['c1::102,104:false']);
    expect(result, hasLength(1));
  });

  test('允许空关键字时浏览最近消息（全部）', () async {
    final service = _FakeService();
    final useCase = SearchMessagesUseCase(messageService: service);
    final result = await useCase.search('c1', '', allowEmptyKeyword: true);
    expect(service.calls, ['c1:::true']);
    expect(result, hasLength(1));
  });
}
