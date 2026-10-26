import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/services/scheduled_message_store.dart';
import '../../../domain/models/scheduled_message.dart';

final scheduledMessageStoreProvider = Provider<ScheduledMessageStore>(
  (ref) => ScheduledMessageStore(),
);

/// 本地定时消息：内存状态 + SharedPreferences 持久化。
class ScheduledMessagesNotifier extends Notifier<List<ScheduledMessage>> {
  int _seq = 0;

  @override
  List<ScheduledMessage> build() {
    Future.microtask(_load);
    return const <ScheduledMessage>[];
  }

  Future<void> _load() async {
    final loaded = await ref.read(scheduledMessageStoreProvider).load();
    if (loaded.isEmpty) return;
    // 加载期间可能已经新建了定时项：按 id 合并，避免把刚写入的覆盖掉。
    final merged = <String, ScheduledMessage>{
      for (final message in loaded) message.id: message,
      for (final message in state) message.id: message,
    };
    state = _sorted(merged.values);
    if (merged.length != loaded.length) {
      await ref.read(scheduledMessageStoreProvider).save(state);
    }
  }

  /// 某会话待发送的定时消息，按时间从早到晚。
  List<ScheduledMessage> forConversation(String conversationId) => [
    for (final message in state)
      if (message.conversationId == conversationId) message,
  ];

  /// 到点待发送的消息，按时间从早到晚。
  List<ScheduledMessage> due(DateTime now) => [
    for (final message in state)
      if (message.isDue(now)) message,
  ];

  Future<ScheduledMessage> schedule({
    required String conversationId,
    required String text,
    required DateTime scheduledAt,
  }) async {
    final message = ScheduledMessage(
      id: '${DateTime.now().microsecondsSinceEpoch}-${_seq++}',
      conversationId: conversationId,
      text: text,
      scheduledAt: scheduledAt.millisecondsSinceEpoch,
    );
    await _write([...state, message]);
    return message;
  }

  /// 取消一条待发送（已发出的由 dispatcher 直接 [remove]）。
  Future<void> cancel(String id) => remove(id);

  Future<void> remove(String id) async {
    if (!state.any((message) => message.id == id)) return;
    await _write([
      for (final message in state)
        if (message.id != id) message,
    ]);
  }

  Future<void> _write(List<ScheduledMessage> messages) async {
    state = _sorted(messages);
    await ref.read(scheduledMessageStoreProvider).save(state);
  }

  List<ScheduledMessage> _sorted(Iterable<ScheduledMessage> messages) {
    final list = messages.toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    return list;
  }
}

final scheduledMessagesProvider =
    NotifierProvider<ScheduledMessagesNotifier, List<ScheduledMessage>>(
      ScheduledMessagesNotifier.new,
    );
