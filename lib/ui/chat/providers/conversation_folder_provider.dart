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
