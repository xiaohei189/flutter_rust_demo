import 'dart:typed_data' show Int32List;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_rust_demo/application/chat/message_service_conversation_controller.dart';
import 'package:flutter_rust_demo/application/chat/message_service_notifier.dart';
import 'package:flutter_rust_demo/data/mappers/message_mapper.dart'
    show messageInfoFromChatMessage;
import 'package:flutter_rust_demo/data/services/im_client.dart';
import 'package:flutter_rust_demo/domain/models/chat_message.dart'
    show ChatMessage;
import 'package:flutter_rust_demo/domain/models/chat_session_type.dart';
import 'package:flutter_rust_demo/domain/models/conversation.dart';
import 'package:flutter_rust_demo/generated/rust/event/events/conversation.dart';
import 'package:flutter_rust_demo/generated/rust/event/events/message.dart'
    show MessageEvent;
import 'package:flutter_rust_demo/ui/chat/providers/chat_detail_provider.dart';
import 'package:flutter_rust_demo/ui/chat/providers/message_service_provider.dart';
import 'package:flutter_rust_demo/ui/chat/view_models/chat_detail_view_model.dart';

const _convId = 'si_user_a_user_b';

class _FakeService extends MessageServiceNotifier {
  _FakeService(this._fake);

  MessageServiceState _fake;
  final List<bool> typingFocus = [];

  @override
  MessageServiceState build() => _fake;

  @override
  MessageServiceState get currentState => _fake;

  @override
  void updateState(MessageServiceState next) {
    _fake = next;
    state = next;
  }

  @override
  Future<void> sendTyping({
    required String sourceId,
    required ChatSessionType sessionType,
    required bool focus,
  }) async {
    typingFocus.add(focus);
  }
}

Conversation _conversation() => const Conversation(
  conversationId: _convId,
  conversationType: 1,
  userId: 'user_b',
  groupId: '',
  showName: '对方',
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

ChatMessage _message(String id, String sendId) => ChatMessage(
  clientMsgId: id,
  serverMsgId: '',
  sendId: sendId,
  recvId: 'user_a',
  groupId: '',
  senderPlatformId: 0,
  senderNickname: '对方',
  senderFaceUrl: '',
  sessionType: 1,
  msgFrom: 0,
  contentType: 101,
  content: '{"content":"hi"}',
  seq: 1,
  sendTime: 1000,
  createTime: 1000,
  status: 2,
  isRead: true,
  attachedInfo: '',
  ex: '',
);

void main() {
  group('发送端：输入状态', () {
    late _FakeService service;
    late ProviderContainer container;
    late Duration originalDelay;

    setUp(() {
      originalDelay = ChatDetailViewModel.typingStopDelay;
      ChatDetailViewModel.typingStopDelay = const Duration(milliseconds: 60);
      service = _FakeService(
        MessageServiceState(
          currentUserId: 'user_a',
          conversations: [_conversation()],
        ),
      );
      container = ProviderContainer(
        overrides: [messageServiceProvider.overrideWith(() => service)],
      );
      addTearDown(() {
        container.dispose();
        ChatDetailViewModel.typingStopDelay = originalDelay;
      });
    });

    ChatDetailViewModel viewModel() =>
        container.read(chatDetailViewModelProvider(_convId).notifier);

    test('输入发 yes，停止输入后自动发 no', () async {
      viewModel().onTextChanged(text: '你');
      expect(service.typingFocus, [true], reason: '输入应立即发「正在输入」');

      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(service.typingFocus, [true, false], reason: '停止输入后应发「结束输入」');
    });

    test('连续输入只在停止后发一次 no', () async {
      final vm = viewModel();
      vm.onTextChanged(text: '你');
      vm.onTextChanged(text: '你好');
      vm.onTextChanged(text: '你好啊');
      expect(service.typingFocus, [true], reason: '3 秒节流内不重复发 yes');

      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(service.typingFocus, [true, false]);
    });

    test('输入框清空（发送后）立即发 no', () {
      final vm = viewModel();
      vm.onTextChanged(text: '你好');
      vm.onTextChanged(text: '');
      expect(service.typingFocus, [true, false]);
    });

    test('显式 stopTyping（发送成功/退出会话）发 no，且不重复发', () {
      final vm = viewModel();
      vm.onTextChanged(text: '你好');
      vm.stopTyping();
      vm.stopTyping();
      expect(service.typingFocus, [true, false]);
    });
  });

  group('接收端：输入状态', () {
    test('收到对应发送者消息时立即清除「正在输入」', () {
      var service = _FakeService(
        MessageServiceState(currentUserId: 'user_a'),
      );
      final container = ProviderContainer(
        overrides: [messageServiceProvider.overrideWith(() => service)],
      );
      addTearDown(container.dispose);
      // 通过 Provider 挂载 Notifier（否则 state setter 不可用）
      service = container.read(messageServiceProvider.notifier) as _FakeService;
      // 先制造「对方正在输入」
      service.updateState(
        service.currentState.copyWith(typingUsers: {_convId: 'user_b'}),
      );
      service.onMessageEventForTest(
        MessageEvent.newMessage(
          conversationId: _convId,
          message: messageInfoFromChatMessage(_message('m1', 'user_b')),
        ),
      );

      expect(service.currentState.typingUsers[_convId], isNull);
    });

    test('收到「结束输入」事件清除状态；超时兜底也会清除', () async {
      var service = _FakeService(
        MessageServiceState(currentUserId: 'user_a'),
      );
      final container = ProviderContainer(
        overrides: [messageServiceProvider.overrideWith(() => service)],
      );
      addTearDown(container.dispose);
      service = container.read(messageServiceProvider.notifier) as _FakeService;
      final controller = MessageServiceConversationController(
        service,
        ImClient.instance,
      );
      final originalTtl = MessageServiceConversationController.typingTtl;
      MessageServiceConversationController.typingTtl = const Duration(
        milliseconds: 80,
      );
      addTearDown(() {
        MessageServiceConversationController.typingTtl = originalTtl;
      });

      controller.handleEvent(
        ConversationEvent.userInputStatusChanged(
          conversationId: _convId,
          userId: 'user_b',
          platformIds: Int32List.fromList([5]),
        ),
      );
      expect(service.currentState.typingUsers[_convId], 'user_b');

      await Future<void>.delayed(const Duration(milliseconds: 160));
      expect(
        service.currentState.typingUsers[_convId],
        isNull,
        reason: '超时兜底应自动清除，防止对端不发结束输入时提示挂住',
      );
    });
  });
}
