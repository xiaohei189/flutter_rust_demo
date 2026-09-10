import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_rust_demo/application/chat/message_service_notifier.dart';
import 'package:flutter_rust_demo/domain/models/chat_message.dart' show ChatMessage;
import 'package:flutter_rust_demo/domain/models/conversation.dart';
import 'package:flutter_rust_demo/ui/chat/providers/conversation_provider.dart';
import 'package:flutter_rust_demo/ui/chat/providers/message_service_provider.dart';
import 'package:flutter_rust_demo/ui/chat/view_models/conversation_view_model.dart';

class _FakeMessageService extends MessageServiceNotifier {
  _FakeMessageService(this._fake);

  MessageServiceState _fake;
  int buildCount = 0;

  @override
  MessageServiceState build() {
    buildCount++;
    return _fake;
  }

  @override
  MessageServiceState get currentState => _fake;

  @override
  void updateState(MessageServiceState next) {
    _fake = next;
    state = next;
  }
}

Conversation _conversation(String id) => Conversation(
  conversationId: id,
  conversationType: 1,
  userId: 'u_$id',
  groupId: '',
  showName: id,
  faceUrl: '',
  latestMsg: '',
  latestMsgSendTime: 0,
  unreadCount: 0,
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

ChatMessage _message(String id, {int status = 2}) => ChatMessage(
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
  content: '{"content":"$id"}',
  seq: 1,
  sendTime: 1000,
  createTime: 1000,
  status: status,
  isRead: true,
  attachedInfo: '',
  ex: '',
);

void main() {
  test('会话列表状态只依赖失败集合，消息变化不触发重建', () {
    final service = _FakeMessageService(
      MessageServiceState(conversations: [_conversation('c1')]),
    );
    final container = ProviderContainer(
      overrides: [messageServiceProvider.overrideWith(() => service)],
    );
    addTearDown(container.dispose);

    final before = container.read(conversationListProvider);
    expect(service.buildCount, 1);

    // 历史消息加载/新消息只替换 messages，会话列表状态应保持同一实例。
    service.updateState(
      service.currentState.copyWith(messages: {'c1': [_message('m1')]}),
    );

    final after = container.read(conversationListProvider);
    expect(identical(before, after), isTrue);
    expect(service.buildCount, 1);
    expect(after.failedConversationIds, isEmpty);
  });

  test('最近一条消息发送失败时更新失败集合', () {
    final service = _FakeMessageService(
      MessageServiceState(conversations: [_conversation('c1')]),
    );
    final container = ProviderContainer(
      overrides: [messageServiceProvider.overrideWith(() => service)],
    );
    addTearDown(container.dispose);

    container.read(conversationListProvider);

    service.updateState(
      service.currentState.copyWith(
        messages: {
          'c1': [_message('m1'), _message('m2', status: 3)],
        },
      ),
    );

    expect(
      container.read(conversationListProvider).failedConversationIds,
      {'c1'},
    );

    // 重发成功（非失败状态）后失败集合应清空。
    service.updateState(
      service.currentState.copyWith(
        messages: {
          'c1': [_message('m1'), _message('m2')],
        },
      ),
    );
    expect(
      container.read(conversationListProvider).failedConversationIds,
      isEmpty,
    );
  });

  group('failedConversationIdsKeyOf', () {
    test('空集合返回空串', () {
      expect(failedConversationIdsKeyOf(const {}), '');
      expect(failedConversationIdsKeyOf({'c1': const []}), '');
    });

    test('只看最近一条消息的状态', () {
      expect(
        failedConversationIdsKeyOf({
          'c1': [_message('m1', status: 3), _message('m2')],
        }),
        '',
      );
      expect(
        failedConversationIdsKeyOf({
          'c1': [_message('m1'), _message('m2', status: 3)],
        }),
        'c1',
      );
    });

    test('与 Map 顺序无关（避免同集合重复触发重建）', () {
      final first = {
        'c2': [_message('m2', status: 3)],
        'c1': [_message('m1', status: 3)],
      };
      final second = {
        'c1': [_message('m1', status: 3)],
        'c2': [_message('m2', status: 3)],
      };
      expect(
        failedConversationIdsKeyOf(first),
        failedConversationIdsKeyOf(second),
      );
    });
  });
}
