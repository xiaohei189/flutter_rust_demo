import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/services/conversation_folder_store.dart';

final conversationFolderStoreProvider = Provider<ConversationFolderStore>(
  (ref) => ConversationFolderStore(),
);

/// 自定义分组：内存状态 + 持久化到本地。
class ConversationFoldersNotifier extends Notifier<Map<String, List<String>>> {
  @override
  Map<String, List<String>> build() {
    Future.microtask(_load);
    return const <String, List<String>>{};
  }

  Future<void> _load() async {
    final data = await ref.read(conversationFolderStoreProvider).load();
    state = data;
  }

  bool isInFolder(String folder, String conversationId) =>
      state[folder]?.contains(conversationId) ?? false;

  Future<void> createFolder(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || state.containsKey(trimmed)) return;
    state = {...state, trimmed: <String>[]};
    await _persist();
  }

  Future<void> removeFolder(String name) async {
    if (!state.containsKey(name)) return;
    state = {...state}..remove(name);
    await _persist();
  }

  /// 重命名分组：新名为空、与原名相同或已存在时返回 false。
  ///
  /// 重命名保留分组内会话与分组顺序（Dart Map 保序，整体重建即可）。
  Future<bool> renameFolder(String oldName, String newName) async {
    if (!state.containsKey(oldName)) return false;
    final trimmed = newName.trim();
    if (trimmed.isEmpty || trimmed == oldName) return false;
    if (state.containsKey(trimmed)) return false;
    state = {
      for (final entry in state.entries)
        entry.key == oldName ? trimmed : entry.key: entry.value,
    };
    await _persist();
    return true;
  }

  /// 按给定顺序重排分组。
  ///
  /// 只接受与当前分组集合完全一致的顺序，避免误传导致分组丢失。
  Future<void> reorderFolders(List<String> orderedNames) async {
    if (orderedNames.length != state.length) return;
    if (orderedNames.toSet().length != orderedNames.length) return;
    for (final name in orderedNames) {
      if (!state.containsKey(name)) return;
    }
    state = {for (final name in orderedNames) name: state[name]!};
    await _persist();
  }

  Future<void> addToFolder(String folder, String conversationId) async {
    final current = state[folder] ?? <String>[];
    if (current.contains(conversationId)) return;
    state = {
      ...state,
      folder: [...current, conversationId],
    };
    await _persist();
  }

  Future<void> removeFromFolder(String folder, String conversationId) async {
    final current = state[folder];
    if (current == null) return;
    state = {
      ...state,
      folder: current.where((id) => id != conversationId).toList(),
    };
    await _persist();
  }

  Future<void> _persist() =>
      ref.read(conversationFolderStoreProvider).save(state);
}

final conversationFoldersProvider =
    NotifierProvider<ConversationFoldersNotifier, Map<String, List<String>>>(
      ConversationFoldersNotifier.new,
    );

/// conversationId → 所属分组名（会话可能属于多个分组，列表胶囊只取第一个）。
///
/// 会话列表行显示分组胶囊时用，避免每行都去遍历分组表。
final conversationFolderLabelProvider = Provider<Map<String, String>>((ref) {
  final folders = ref.watch(conversationFoldersProvider);
  final labels = <String, String>{};
  for (final entry in folders.entries) {
    for (final conversationId in entry.value) {
      labels.putIfAbsent(conversationId, () => entry.key);
    }
  }
  return labels;
});
