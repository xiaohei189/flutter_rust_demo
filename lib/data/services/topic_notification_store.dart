import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/topic_notification.dart';
import 'login_storage.dart';

class TopicNotificationStore {
  const TopicNotificationStore();

  static const _prefix = 'topic_notifications_v1';
  static const _limit = 300;

  String _key(String userId) => '$_prefix:$userId';

  Future<List<TopicNotification>> load() async {
    final credentials = await LoginStorage.loadCredentials();
    if (credentials == null) return const [];
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(credentials.userId));
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map<Object?, Object?>>()
          .map(
            (item) =>
                TopicNotification.fromJson(Map<String, dynamic>.from(item)),
          )
          .where((item) => item.id.isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<List<TopicNotification>> add(TopicNotification item) async {
    final current = await load();
    return merge([item, ...current]);
  }

  Future<List<TopicNotification>> merge(
    Iterable<TopicNotification> incoming,
  ) async {
    final current = await load();
    final byId = <String, TopicNotification>{
      for (final item in current) item.id: item,
    };
    for (final item in incoming) {
      if (item.id.isEmpty) continue;
      final existing = byId[item.id];
      byId[item.id] = existing == null
          ? item
          : item.copyWith(read: existing.read || item.read);
    }
    final next = byId.values.toList(growable: false)
      ..sort((left, right) => right.createdAt.compareTo(left.createdAt));
    final limited = next.take(_limit).toList(growable: false);
    await _save(limited);
    return limited;
  }

  Future<List<TopicNotification>> markRead(String id) async {
    final current = await load();
    final next = [
      for (final item in current)
        if (item.id == id) item.copyWith(read: true) else item,
    ];
    await _save(next);
    return next;
  }

  Future<List<TopicNotification>> markAllRead() async {
    final current = await load();
    final next = [for (final item in current) item.copyWith(read: true)];
    await _save(next);
    return next;
  }

  Future<void> _save(List<TopicNotification> items) async {
    final credentials = await LoginStorage.loadCredentials();
    if (credentials == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key(credentials.userId),
      jsonEncode(items.map((item) => item.toJson()).toList(growable: false)),
    );
  }
}
