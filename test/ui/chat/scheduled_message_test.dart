import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_rust_demo/data/services/scheduled_message_store.dart';
import 'package:flutter_rust_demo/domain/models/scheduled_message.dart';
import 'package:flutter_rust_demo/ui/chat/providers/scheduled_message_provider.dart';
import 'package:flutter_rust_demo/ui/chat/widgets/composer/schedule_message_sheet.dart';

/// 内存版存储：避免 SharedPreferences 异步加载影响 widget 测试。
class _MemoryStore implements ScheduledMessageStore {
  List<ScheduledMessage> messages = [];

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const conversationId = 'sg_plan';

  ScheduledMessage scheduled(
    String id,
    String text,
    DateTime at, {
    String conversation = conversationId,
  }) => ScheduledMessage(
    id: id,
    conversationId: conversation,
    text: text,
    scheduledAt: at.millisecondsSinceEpoch,
  );

  group('ScheduledMessagesNotifier', () {
    test('按会话筛选、按时间排序、到期可查出，取消后消失', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await pumpEventQueue();

      final notifier = container.read(scheduledMessagesProvider.notifier);
      final now = DateTime.now();
      final later = await notifier.schedule(
        conversationId: conversationId,
        text: '稍后发',
        scheduledAt: now.add(const Duration(minutes: 30)),
      );
      final overdue = await notifier.schedule(
        conversationId: conversationId,
        text: '已到点',
        scheduledAt: now.subtract(const Duration(minutes: 1)),
      );
      await notifier.schedule(
        conversationId: 'si_other',
        text: '别的会话',
        scheduledAt: now.add(const Duration(hours: 1)),
      );

      expect(notifier.forConversation(conversationId).map((m) => m.text), [
        '已到点',
        '稍后发',
      ]);
      expect(notifier.due(now).map((m) => m.id), [overdue.id]);

      await notifier.cancel(later.id);
      expect(notifier.forConversation(conversationId).map((m) => m.id), [
        overdue.id,
      ]);
    });

    test('重启后从本地存储恢复', () async {
      SharedPreferences.setMockInitialValues({});
      final now = DateTime.now();
      final store = _MemoryStore()
        ..messages = [
          scheduled('m2', '第二条', now.add(const Duration(minutes: 20))),
          scheduled('m1', '第一条', now.add(const Duration(minutes: 10))),
        ];

      final container = ProviderContainer(
        overrides: [scheduledMessageStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);
      container.read(scheduledMessagesProvider);
      await pumpEventQueue();

      expect(container.read(scheduledMessagesProvider).map((m) => m.text), [
        '第一条',
        '第二条',
      ]);
    });
  });

  group('ScheduleMessageSheet', () {
    Widget host({
      required List<ScheduledMessage> seeded,
      required Future<bool> Function(DateTime at) onSchedule,
    }) {
      final store = _MemoryStore();
      final navigatorKey = GlobalKey<NavigatorState>();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        navigatorKey.currentState?.push(
          MaterialPageRoute<void>(
            builder: (_) => ScheduleMessageSheet(
              conversationId: conversationId,
              text: '这条要定时发送',
              onSchedule: onSchedule,
            ),
          ),
        );
      });
      return ProviderScope(
        overrides: [
          scheduledMessageStoreProvider.overrideWithValue(store),
          scheduledMessagesProvider.overrideWith(() => _SeededNotifier(seeded)),
        ],
        child: MaterialApp(
          navigatorKey: navigatorKey,
          home: const Scaffold(body: SizedBox.shrink()),
        ),
      );
    }

    testWidgets('展示待发送列表，可取消', (tester) async {
      final at = DateTime.now().add(const Duration(minutes: 30));
      await tester.pumpWidget(
        host(
          seeded: [scheduled('p1', '待发送内容', at)],
          onSchedule: (_) async => true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('定时消息'), findsOneWidget);
      expect(find.text('这条要定时发送'), findsOneWidget);
      expect(find.text('已定时 · 1 条'), findsOneWidget);
      expect(find.text('待发送内容'), findsOneWidget);

      await tester.tap(find.byTooltip('取消定时'));
      await tester.pumpAndSettle();

      expect(find.text('待发送内容'), findsNothing);
      expect(find.text('本会话还没有定时消息'), findsOneWidget);
    });

    testWidgets('点「10 分钟后」按当前时间+10 分钟回调，成功后关闭弹层', (tester) async {
      DateTime? picked;
      final before = DateTime.now();
      await tester.pumpWidget(
        host(
          seeded: const [],
          onSchedule: (at) async {
            picked = at;
            return true;
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('10 分钟后'));
      await tester.pumpAndSettle();

      expect(picked, isNotNull);
      expect(picked!.difference(before).inMinutes, inInclusiveRange(9, 10));
      expect(find.text('定时消息'), findsNothing, reason: '成功后关闭弹层');
    });
  });
}
