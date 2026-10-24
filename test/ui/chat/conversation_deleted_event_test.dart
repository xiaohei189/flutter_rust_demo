import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_rust_demo/application/chat/message_service_conversation_controller.dart';
import 'package:flutter_rust_demo/application/chat/message_service_notifier.dart';
import 'package:flutter_rust_demo/data/services/im_client.dart';
import 'package:flutter_rust_demo/domain/models/chat_message.dart'
    show ChatMessage;
import 'package:flutter_rust_demo/domain/models/conversation.dart';
import 'package:flutter_rust_demo/generated/rust/core/event/events/conversation.dart';
import 'package:flutter_rust_demo/ui/chat/providers/message_service_provider.dart';
import 'package:flutter_rust_demo/ui/chat/views/chat_list_screen.dart';
import 'package:flutter_rust_demo/ui/core/theme/app_theme.dart';

/// 可写状态、可在测试里手工灌事件的假 Service（不触达 Rust 侧）。
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

/// 群会话：`sg_<groupID>`
Conversation _groupConversation(String groupId, {String? name}) => Conversation(
  conversationId: 'sg_$groupId',
  conversationType: 2,
  userId: '',
  groupId: groupId,
  showName: name ?? '群$groupId',
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

ChatMessage _message(String id) => ChatMessage(
  clientMsgId: id,
  serverMsgId: '',
  sendId: 'u1',
  recvId: 'g1',
  groupId: 'g1',
  senderPlatformId: 0,
  senderNickname: '张三',
  senderFaceUrl: '',
  sessionType: 2,
  msgFrom: 0,
  contentType: 101,
  content: '{"content":"$id"}',
  seq: 1,
  sendTime: 1000,
  createTime: 1000,
  status: 2,
  isRead: true,
  attachedInfo: '',
  ex: '',
);

Widget _host(MessageServiceNotifier service) => ProviderScope(
  overrides: [messageServiceProvider.overrideWith(() => service)],
  child: MaterialApp(theme: AppTheme.lightTheme, home: const ChatListScreen()),
);

void main() {
  group('被动清理：ConversationEvent.deleted', () {
    late _FakeMessageService service;
    late ProviderContainer container;

    setUp(() {
      service = _FakeMessageService(
        MessageServiceState(
          currentUserId: 'me',
          conversations: [_groupConversation('g1'), _groupConversation('g2')],
          messages: {
            'sg_g1': [_message('m1')],
            'sg_g2': [_message('m2')],
          },
        ),
      );
      container = ProviderContainer(
        overrides: [messageServiceProvider.overrideWith(() => service)],
      );
      addTearDown(container.dispose);
      // 通过 Provider 挂载 Notifier（否则 state setter 不可用）
      service =
          container.read(messageServiceProvider.notifier)
              as _FakeMessageService;
    });

    MessageServiceConversationController controller() =>
        MessageServiceConversationController(service, ImClient.instance);

    test('按 id 移除会话，并清掉该会话的消息缓存', () {
      controller().handleEvent(const ConversationEvent.deleted(['sg_g1']));

      final ids = service.currentState.conversations
          .map((c) => c.conversationId)
          .toList();
      expect(ids, ['sg_g2'], reason: '被解散/被移出的群不应残留在会话列表');
      expect(
        service.currentState.messages.containsKey('sg_g1'),
        isFalse,
        reason: '会话已删除，缓存消息应一并清理，避免内存泄漏',
      );
      expect(service.currentState.messages.containsKey('sg_g2'), isTrue);
    });

    test('幂等：重复删除同一会话不报错且状态稳定', () {
      controller()
        ..handleEvent(const ConversationEvent.deleted(['sg_g1']))
        ..handleEvent(const ConversationEvent.deleted(['sg_g1']));

      expect(
        service.currentState.conversations
            .map((c) => c.conversationId)
            .toList(),
        ['sg_g2'],
      );
    });

    test('一次删除多个会话，未命中的 id 不影响其他会话', () {
      controller().handleEvent(
        const ConversationEvent.deleted(['sg_g1', 'sg_g2', 'sg_not_exist']),
      );

      expect(service.currentState.conversations, isEmpty);
    });

    test('空 id 列表不改动会话列表', () {
      controller().handleEvent(const ConversationEvent.deleted([]));

      expect(service.currentState.conversations.length, 2);
    });

    test('经 MessageServiceNotifier.onConversationEvent 走同一清理路径', () {
      service.onConversationEvent(const ConversationEvent.deleted(['sg_g1']));

      expect(
        service.currentState.conversations
            .map((c) => c.conversationId)
            .toList(),
        ['sg_g2'],
      );
    });
  });

  testWidgets('群被解散后会话列表无需重启即移除该群', (tester) async {
    final service = _FakeMessageService(
      MessageServiceState(
        currentUserId: 'me',
        conversations: [_groupConversation('g1'), _groupConversation('g2')],
      ),
    );

    await tester.pumpWidget(_host(service));
    await tester.pump();

    expect(find.text('群g1'), findsWidgets);
    expect(find.text('群g2'), findsWidgets);

    // 服务端推送（或同步兜底）广播「会话已删除」
    service.onConversationEvent(const ConversationEvent.deleted(['sg_g1']));
    await tester.pump();

    expect(find.text('群g1'), findsNothing, reason: '死群应即时从列表移除');
    expect(find.text('群g2'), findsWidgets);
  });
}
