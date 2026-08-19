import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_rust_demo/data/repositories/message_repository.dart';
import 'package:flutter_rust_demo/domain/models/conversation.dart';
import 'package:flutter_rust_demo/providers/current_user_provider.dart';
import 'package:flutter_rust_demo/ui/chat/providers/conversation_provider.dart';
import 'package:flutter_rust_demo/ui/chat/providers/message_service_provider.dart';
import 'package:flutter_rust_demo/ui/chat/view_models/conversation_view_model.dart';
import 'package:flutter_rust_demo/application/chat/message_service_notifier.dart';
import 'package:flutter_rust_demo/ui/chat/views/chat_settings_screen.dart';

/// ChatSettingsScreen 挂载回归测试：验证 initState 中不再直接修改 provider 状态
/// （历史 bug：initState 同步调用 initialize 改 provider → FlutterError
///  "Tried to modify a provider while the widget tree was building"）
class _FakeMessageServiceNotifier extends MessageServiceNotifier {
  @override
  MessageServiceState build() => MessageServiceState();
}

class _FakeConversationListNotifier extends ConversationListNotifier {
  _FakeConversationListNotifier(this.conversation);

  final Conversation conversation;

  @override
  ConversationListState build() =>
      ConversationListState(conversations: [conversation]);
}

class _FakeCurrentUserNotifier extends CurrentUserNotifier {
  @override
  String build() => 'u1';
}

class _FakeMessageRepository implements MessageRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

Conversation _makeConversation() {
  return const Conversation(
    conversationId: 'conv1',
    conversationType: 1,
    userId: 'u2',
    groupId: '',
    showName: '张三',
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
}

void main() {
  testWidgets('ChatSettingsScreen 单聊挂载', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWith(() => _FakeCurrentUserNotifier()),
          messageRepositoryProvider.overrideWithValue(_FakeMessageRepository()),
          conversationListProvider.overrideWith(
            () => _FakeConversationListNotifier(_makeConversation()),
          ),
          messageServiceProvider.overrideWith(
            () => _FakeMessageServiceNotifier(),
          ),
        ],
        child: const MaterialApp(
          home: ChatSettingsScreen(conversationId: 'conv1'),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
