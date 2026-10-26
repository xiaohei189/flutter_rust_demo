import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_rust_demo/domain/models/chat_message.dart'
    show ChatMessage;
import 'package:flutter_rust_demo/domain/models/message_extras.dart';
import 'package:flutter_rust_demo/ui/chat/providers/message_extras_provider.dart';
import 'package:flutter_rust_demo/ui/chat/providers/message_provider.dart';
import 'package:flutter_rust_demo/ui/chat/widgets/message_extras_sheet.dart';

ChatMessage _message(String id, String text) {
  final now = DateTime.now().millisecondsSinceEpoch;
  return ChatMessage(
    clientMsgId: id,
    serverMsgId: '',
    sendId: 'other',
    recvId: 'me',
    groupId: '',
    senderPlatformId: 0,
    senderNickname: '张三',
    senderFaceUrl: '',
    sessionType: 1,
    msgFrom: 0,
    contentType: 101,
    content: '{"content":"$text"}',
    seq: 1,
    sendTime: now,
    createTime: now,
    status: 2,
    isRead: true,
    attachedInfo: '',
    ex: '',
  );
}

/// 预置本地扩展状态（跳过 SharedPreferences 加载）。
class _FakeExtras extends MessageExtrasNotifier {
  _FakeExtras(this._initial);

  final Map<String, MessageExtras> _initial;

  @override
  Map<String, MessageExtras> build() =>
      Map<String, MessageExtras>.from(_initial);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const conversationId = 'si_a_b';
  const extrasKey = 'si_a_b|m1';

  Widget host({
    required Map<String, MessageExtras> extras,
    required List<ChatMessage> messages,
    ValueChanged<String>? onMessageTap,
  }) {
    final navigatorKey = GlobalKey<NavigatorState>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      navigatorKey.currentState?.push(
        MaterialPageRoute<void>(
          builder: (_) => MarkedMessagesSheet(
            conversationId: conversationId,
            onMessageTap: onMessageTap,
          ),
        ),
      );
    });
    return ProviderScope(
      overrides: [
        messageExtrasProvider.overrideWith(() => _FakeExtras(extras)),
        messagesByConversationProvider(
          conversationId,
        ).overrideWithValue(messages),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        home: const Scaffold(body: SizedBox.shrink()),
      ),
    );
  }

  testWidgets('只列出被标记的消息，点击回调消息 id', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final tapped = <String>[];
    await tester.pumpWidget(
      host(
        extras: {extrasKey: const MessageExtras(flagged: true)},
        messages: [_message('m1', '这条被标记了'), _message('m2', '这条没有标记')],
        onMessageTap: tapped.add,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('标记消息'), findsOneWidget);
    expect(find.text('1 条'), findsOneWidget);
    expect(find.text('这条被标记了'), findsOneWidget);
    expect(find.text('这条没有标记'), findsNothing);

    await tester.tap(find.text('这条被标记了'));
    await tester.pumpAndSettle();
    expect(tapped, ['m1']);
  });

  testWidgets('取消标记后该条从列表移除并回到空态', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      host(
        extras: {extrasKey: const MessageExtras(flagged: true)},
        messages: [_message('m1', '这条被标记了')],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('这条被标记了'), findsOneWidget);

    await tester.tap(find.byTooltip('取消标记'));
    await tester.pumpAndSettle();

    expect(find.text('这条被标记了'), findsNothing);
    expect(find.text('还没有标记的消息'), findsOneWidget);
  });

  testWidgets('没有标记消息时展示空态与引导文案', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      host(extras: const {}, messages: [_message('m1', '普通消息')]),
    );
    await tester.pumpAndSettle();

    expect(find.text('还没有标记的消息'), findsOneWidget);
    expect(find.text('长按消息选择「标记」即可收藏'), findsOneWidget);
  });
}
