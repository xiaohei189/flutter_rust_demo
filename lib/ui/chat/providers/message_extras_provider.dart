import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/services/message_extras_store.dart';
import '../../../domain/models/message_extras.dart';

final messageExtrasStoreProvider = Provider<MessageExtrasStore>(
  (ref) => MessageExtrasStore(),
);

/// 消息级本地扩展（表情回复 / 置顶消息）：内存状态 + 本地持久化。
///
/// key 为 `conversationId|clientMsgId`，退出会话重进后仍在。
class MessageExtrasNotifier extends Notifier<Map<String, MessageExtras>> {
  @override
  Map<String, MessageExtras> build() {
    Future.microtask(_load);
    return const <String, MessageExtras>{};
  }

  static String keyOf(String conversationId, String clientMsgId) =>
      '$conversationId|$clientMsgId';

  Future<void> _load() async {
    state = await ref.read(messageExtrasStoreProvider).load();
  }

  MessageExtras extrasOf(String conversationId, String clientMsgId) =>
      state[keyOf(conversationId, clientMsgId)] ?? MessageExtras.empty;

  /// 加/取消一条表情回复。
  Future<void> toggleReaction(
    String conversationId,
    String clientMsgId,
    String emoji,
  ) async {
    final key = keyOf(conversationId, clientMsgId);
    final current = state[key] ?? MessageExtras.empty;
    final reactions = Set<String>.from(current.reactions);
    if (!reactions.remove(emoji)) reactions.add(emoji);
    await _write(key, current.copyWith(reactions: reactions));
  }

  /// 置顶/取消置顶一条消息。
  Future<void> setPinned(
    String conversationId,
    String clientMsgId,
    bool pinned,
  ) async {
    final key = keyOf(conversationId, clientMsgId);
    final current = state[key] ?? MessageExtras.empty;
    await _write(
      key,
      current.copyWith(
        pinned: pinned,
        pinnedAt: pinned ? DateTime.now().millisecondsSinceEpoch : 0,
      ),
    );
  }

  /// 标记/取消标记一条消息（本地收藏，供后续回看）。
  Future<bool> toggleFlagged(String conversationId, String clientMsgId) async {
    final key = keyOf(conversationId, clientMsgId);
    final current = state[key] ?? MessageExtras.empty;
    final flagged = !current.flagged;
    await _write(key, current.copyWith(flagged: flagged));
    return flagged;
  }

  /// 某会话内被标记的消息 id（按会话内消息顺序由调用方决定展示顺序）。
  Set<String> flaggedMessageIds(String conversationId) {
    final prefix = '$conversationId|';
    return {
      for (final entry in state.entries)
        if (entry.key.startsWith(prefix) && entry.value.flagged)
          entry.key.substring(prefix.length),
    };
  }

  /// 某会话内被置顶的消息 id，按置顶时间从新到旧。
  List<String> pinnedMessageIds(String conversationId) {
    final prefix = '$conversationId|';
    final pinned = <MapEntry<String, int>>[];
    for (final entry in state.entries) {
      if (!entry.key.startsWith(prefix) || !entry.value.pinned) continue;
      pinned.add(
        MapEntry(entry.key.substring(prefix.length), entry.value.pinnedAt),
      );
    }
    pinned.sort((a, b) => b.value.compareTo(a.value));
    return [for (final item in pinned) item.key];
  }

  Future<void> _write(String key, MessageExtras extras) async {
    final next = Map<String, MessageExtras>.from(state);
    if (extras.isEmpty) {
      next.remove(key);
    } else {
      next[key] = extras;
    }
    state = next;
    await ref.read(messageExtrasStoreProvider).save(next);
  }
}

final messageExtrasProvider =
    NotifierProvider<MessageExtrasNotifier, Map<String, MessageExtras>>(
      MessageExtrasNotifier.new,
    );
