import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_rust_demo/application/chat/message_service_notifier.dart';
import 'package:flutter_rust_demo/domain/models/conversation.dart';
import 'package:flutter_rust_demo/ui/chat/providers/message_service_provider.dart';
import 'package:flutter_rust_demo/ui/chat/views/chat_list_screen.dart';
import 'package:flutter_rust_demo/ui/chat/widgets/list/chat_list_item.dart';
import 'package:flutter_rust_demo/ui/core/theme/app_theme.dart';

/// 只暴露固定会话列表的假 Service，避免测试触达 Rust 侧。
class _FakeMessageService extends MessageServiceNotifier {
  _FakeMessageService(this._fake);

  final MessageServiceState _fake;

  @override
  MessageServiceState build() => _fake;

  @override
  MessageServiceState get currentState => _fake;

  @override
  void updateState(MessageServiceState next) {}
}

Conversation _conversation(int index, {bool pinned = false}) => Conversation(
  conversationId: 'si_u${index}_u999',
  conversationType: 1,
  userId: 'u$index',
  groupId: '',
  showName: '会话$index',
  faceUrl: '',
  latestMsg: '',
  latestMsgSendTime: 0,
  unreadCount: 0,
  recvMsgOpt: 0,
  isPinned: pinned,
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

Widget _host(List<Conversation> conversations) {
  return ProviderScope(
    overrides: [
      messageServiceProvider.overrideWith(
        () => _FakeMessageService(
          MessageServiceState(conversations: conversations),
        ),
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      home: const ChatListScreen(),
    ),
  );
}

void main() {
  testWidgets('会话列表只构建可视区域内的会话行', (tester) async {
    final conversations = [
      for (var i = 0; i < 300; i++) _conversation(i, pinned: i == 0),
    ];

    await tester.pumpWidget(_host(conversations));
    await tester.pump();

    final builtRows = tester.widgetList(find.byType(ChatListItem)).length;

    // 惰性构建：可见行数量级（个位到十几行），而不是把 300 行全部构建出来。
    expect(builtRows, greaterThan(0));
    expect(
      builtRows,
      lessThan(50),
      reason: '会话列表退化为一次性构建全部行（items=$builtRows）',
    );
    // 最后一条会话在视口之外，不应被构建。
    expect(find.text('会话299'), findsNothing);
  });

  testWidgets('置顶分区标题与普通分区都在惰性列表中保留', (tester) async {
    await tester.pumpWidget(
      _host([_conversation(0, pinned: true), _conversation(1)]),
    );
    await tester.pump();

    expect(find.text('置顶聊天'), findsOneWidget);
    expect(find.text('聊天'), findsOneWidget);
    // 会话名会出现两次：标题 + 无头像时的首字占位头像。
    expect(find.text('会话0'), findsWidgets);
    expect(find.text('会话1'), findsWidgets);
  });
}
