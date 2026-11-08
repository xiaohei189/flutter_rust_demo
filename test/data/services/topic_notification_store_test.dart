import 'package:flutter_rust_demo/data/services/login_storage.dart';
import 'package:flutter_rust_demo/data/services/topic_notification_store.dart';
import 'package:flutter_rust_demo/domain/models/topic_notification.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LoginStorage.saveCredentials(userId: 'user_1', imToken: 'token');
  });

  test('通知按用户持久化并按 id 去重', () async {
    const store = TopicNotificationStore();
    const first = TopicNotification(
      id: 'message:1',
      groupId: 'group_1',
      topicId: 'topic_1',
      actorId: 'user_2',
      actorName: '张三',
      title: '张三 发布了话题',
      body: '有新话题',
      type: TopicNotificationType.newTopic,
      createdAt: 100,
    );
    final replacement = first.copyWith(read: true);

    await store.add(first);
    final items = await store.add(replacement);

    expect(items, hasLength(1));
    expect(items.single.read, isTrue);
  });

  test('全部已读可持久化', () async {
    const store = TopicNotificationStore();
    await store.add(
      const TopicNotification(
        id: 'event:1',
        groupId: 'group_1',
        topicId: 'topic_1',
        actorId: 'user_2',
        actorName: '',
        title: '话题状态已更新',
        body: '打开查看',
        type: TopicNotificationType.stateChanged,
        createdAt: 100,
      ),
    );

    await store.markAllRead();
    final loaded = await store.load();

    expect(loaded.single.read, isTrue);
  });

  test('服务端通知字段和数字类型可兼容解析', () {
    final item = TopicNotification.fromJson({
      'notificationID': 'notification_1',
      'groupID': 'group_1',
      'topicID': 'topic_1',
      'actorID': 'user_2',
      'title': '你收到一个话题任务',
      'body': '确认发布',
      'type': 6,
      'createdAt': 100,
      'read': false,
    });

    expect(item.id, 'notification_1');
    expect(item.type, TopicNotificationType.taskAssigned);
  });
}
