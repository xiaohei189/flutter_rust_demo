import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_rust_demo/application/topics/topic_notification_controller.dart';
import 'package:flutter_rust_demo/domain/models/topic_notification.dart';
import 'package:flutter_rust_demo/ui/core/theme/app_theme.dart';
import 'package:flutter_rust_demo/ui/topics/views/topic_notifications_screen.dart';
import 'package:flutter_test/flutter_test.dart';

class _SeededNotifications extends TopicNotificationsController {
  @override
  List<TopicNotification> build() => const [
    TopicNotification(
      id: 'notification_1',
      groupId: 'group_1',
      topicId: 'topic_1',
      actorId: 'user_2',
      actorName: '张三',
      title: '张三 在话题中提到了你',
      body: '请确认新版发布计划',
      type: TopicNotificationType.mention,
      createdAt: 100,
    ),
  ];

  @override
  Future<void> markAllRead() async {
    state = [for (final item in state) item.copyWith(read: true)];
  }
}

void main() {
  testWidgets('话题通知中心展示未读通知并支持全部已读', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          topicNotificationsProvider.overrideWith(_SeededNotifications.new),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const TopicNotificationsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('话题通知'), findsOneWidget);
    expect(find.text('张三 在话题中提到了你'), findsOneWidget);
    expect(find.text('请确认新版发布计划'), findsOneWidget);

    await tester.tap(find.text('全部已读'));
    await tester.pump();

    expect(find.text('全部已读'), findsNothing);
  });
}
