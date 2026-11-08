import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/topic_notification_store.dart';
import '../../data/services/topic_api.dart';
import '../../domain/models/topic.dart';
import '../../domain/models/topic_notification.dart';

final topicNotificationApiProvider = Provider<TopicApi>((ref) {
  final api = TopicApi();
  ref.onDispose(api.close);
  return api;
});

final topicNotificationStoreProvider = Provider<TopicNotificationStore>(
  (ref) => const TopicNotificationStore(),
);

final topicNotificationsProvider =
    NotifierProvider<TopicNotificationsController, List<TopicNotification>>(
      TopicNotificationsController.new,
    );

final unreadTopicNotificationCountProvider = Provider<int>((ref) {
  return ref
      .watch(topicNotificationsProvider)
      .where((item) => !item.read)
      .length;
});

class TopicNotificationsController extends Notifier<List<TopicNotification>> {
  final Map<String, TopicGroupSettings> _policies = {};

  TopicNotificationStore get _store => ref.read(topicNotificationStoreProvider);

  @override
  List<TopicNotification> build() {
    Future.microtask(load);
    return const [];
  }

  Future<void> load() async {
    final local = await _store.load();
    state = local;
    await syncFromServer();
  }

  Future<void> syncFromServer() async {
    try {
      final page = await ref
          .read(topicNotificationApiProvider)
          .getNotifications(count: 100);
      state = await _store.merge(page.notifications);
    } catch (_) {
      // 服务端不可用时保留本地投影。
    }
  }

  Future<void> record(TopicNotification item) async {
    final policy = _policies[item.groupId] ?? const TopicGroupSettings();
    if (item.type == TopicNotificationType.newTopic && !policy.notifyNewTopic) {
      return;
    }
    if (item.type == TopicNotificationType.reply && !policy.notifyReplies) {
      return;
    }
    state = await _store.add(item);
  }

  void updateGroupSettings(String groupId, TopicGroupSettings settings) {
    _policies[groupId] = settings;
  }

  Future<void> markRead(String id) async {
    try {
      await ref.read(topicNotificationApiProvider).markNotificationsRead([id]);
    } catch (_) {}
    state = await _store.markRead(id);
  }

  Future<void> markAllRead() async {
    try {
      await ref.read(topicNotificationApiProvider).markNotificationsRead([]);
    } catch (_) {}
    state = await _store.markAllRead();
  }
}
