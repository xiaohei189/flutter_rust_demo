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

  const conversationId = 'sg_pin';

  Widget host({
    required Map<String, MessageExtras> extras,
    required List<ChatMessage> messages,
    ValueChanged<String>? onMessageTap,
  }) {
    final navigatorKey = GlobalKey<NavigatorState>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      navigatorKey.currentState?.push(
        MaterialPageRoute<void>(
          builder: (_) => PinnedMessagesSheet(
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

  testWidgets('只列出置顶消息，按置顶时间从新到旧，点击回调消息 id', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final tapped = <String>[];
    await tester.pumpWidget(
      host(
        extras: {
          '$conversationId|m1': const MessageExtras(
            pinned: true,
            pinnedAt: 100,
          ),
          '$conversationId|m2': const MessageExtras(
            pinned: true,
            pinnedAt: 200,
          ),
          '$conversationId|m3': const MessageExtras(flagged: true),
        },
        messages: [
          _message('m1', '先置顶的'),
          _message('m2', '后置顶的'),
          _message('m3', '只是标记'),
        ],
        onMessageTap: tapped.add,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('置顶消息'), findsOneWidget);
    expect(find.text('2 条'), findsOneWidget);
    expect(find.text('只是标记'), findsNothing, reason: '标记不算置顶');

    // 后置顶的排在上面
    final laterTop = tester.getTopLeft(find.text('后置顶的')).dy;
    final earlierTop = tester.getTopLeft(find.text('先置顶的')).dy;
    expect(laterTop, lessThan(earlierTop));

    await tester.tap(find.text('后置顶的'));
    await tester.pumpAndSettle();
    expect(tapped, ['m2']);
  });

  testWidgets('取消置顶后该条从列表移除并回到空态', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      host(
        extras: {
          '$conversationId|m1': const MessageExtras(
            pinned: true,
            pinnedAt: 100,
          ),
        },
        messages: [_message('m1', '这条被置顶了')],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('这条被置顶了'), findsOneWidget);

    await tester.tap(find.byTooltip('取消置顶'));
    await tester.pumpAndSettle();

    expect(find.text('这条被置顶了'), findsNothing);
    expect(find.text('还没有置顶的消息'), findsOneWidget);
  });

  testWidgets('没有置顶消息时展示空态与引导文案', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      host(
        extras: {'$conversationId|m1': const MessageExtras(flagged: true)},
        messages: [_message('m1', '普通消息')],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('还没有置顶的消息'), findsOneWidget);
    expect(find.text('长按消息选择「置顶消息」即可置顶'), findsOneWidget);
  });
}
