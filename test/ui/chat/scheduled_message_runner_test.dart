import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_rust_demo/data/services/scheduled_message_store.dart';
import 'package:flutter_rust_demo/domain/models/conversation.dart';
import 'package:flutter_rust_demo/domain/models/scheduled_message.dart';
import 'package:flutter_rust_demo/providers/current_user_provider.dart';
import 'package:flutter_rust_demo/ui/chat/providers/conversation_provider.dart';
import 'package:flutter_rust_demo/ui/chat/providers/scheduled_message_provider.dart';
import 'package:flutter_rust_demo/ui/chat/view_models/conversation_view_model.dart';
import 'package:flutter_rust_demo/ui/chat/widgets/scheduled_message_runner.dart';

class _MemoryStore implements ScheduledMessageStore {
  _MemoryStore(this.messages);

  List<ScheduledMessage> messages;

  @override
  Future<List<ScheduledMessage>> load() async => List.of(messages);

  @override
  Future<void> save(List<ScheduledMessage> value) async {
    messages = List.of(value);
  }
}

class _SeededNotifier extends ScheduledMessagesNotifier {
  _SeededNotifier(this.seed);

  final List<ScheduledMessage> seed;

  @override
  List<ScheduledMessage> build() => List.of(seed);
}

class _FakeConversations extends ConversationListNotifier {
  _FakeConversations(this.conversation);

  final Conversation conversation;

  @override
  ConversationListState build() =>
      ConversationListState(conversations: [conversation]);
}

class _FakeCurrentUser extends CurrentUserNotifier {
  @override
  String build() => 'u1';
}

Conversation _groupConversation() => const Conversation(
  conversationId: 'sg_plan',
  conversationType: 3,
  userId: '',
  groupId: 'plan',
  showName: '计划群',
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('到点的定时消息会发送一次并从待发送列表移除', (tester) async {
    final due = ScheduledMessage(
      id: 's1',
      conversationId: 'sg_plan',
      text: '到点发送',
      scheduledAt: DateTime.now()
          .subtract(const Duration(minutes: 1))
          .millisecondsSinceEpoch,
    );
    final future = ScheduledMessage(
      id: 's2',
      conversationId: 'sg_plan',
      text: '还没到点',
      scheduledAt: DateTime.now()
          .add(const Duration(hours: 1))
          .millisecondsSinceEpoch,
    );
    final store = _MemoryStore([due, future]);
    final seeded = _SeededNotifier([due, future]);
    final sent = <ScheduledMessage>[];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          scheduledMessageStoreProvider.overrideWithValue(store),
          scheduledMessagesProvider.overrideWith(() => seeded),
          conversationListProvider.overrideWith(
            () => _FakeConversations(_groupConversation()),
          ),
          currentUserIdProvider.overrideWith(_FakeCurrentUser.new),
        ],
        child: MaterialApp(
          home: ScheduledMessageRunner(
            sendOverride: (message, conversation) async {
              sent.add(message);
              return true;
            },
            child: const SizedBox.shrink(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(sent.map((m) => m.id), ['s1']);
    expect(seeded.state.map((m) => m.id), ['s2'], reason: '只剩未到点那条');
    expect(store.messages.map((m) => m.id), ['s2'], reason: '已落盘');

    // 再等一轮也不会重复发送
    await tester.pump(const Duration(seconds: 11));
    expect(sent.length, 1);
  });
}
