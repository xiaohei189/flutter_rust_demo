import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../domain/models/conversation.dart';
import '../../../domain/models/friend_search_result.dart';
import '../../../domain/models/group.dart';
import '../../../domain/models/message_search_result.dart'
    show MessageSearchResult;
import '../../chat/providers/message_service_provider.dart';
import '../../contacts/providers/friend_provider.dart';
import '../../groups/providers/group_provider.dart';
import '../providers/search_provider.dart';

/// 搜索分类
enum SearchCategory { message, conversations, contacts, groups }

/// 搜索数据源，便于测试注入。
abstract class SearchGateway {
  Future<List<MessageSearchResult>> searchMessages(String query);

  Future<List<Conversation>> searchConversations(String query);

  Future<List<FriendSearchResult>> searchContacts(String query);

  Future<List<Group>> searchGroups(String query);
}

/// 基于 Riverpod 的搜索数据源实现。
class RiverpodSearchGateway implements SearchGateway {
  RiverpodSearchGateway(this._ref);

  final Ref _ref;

  @override
  Future<List<MessageSearchResult>> searchMessages(String query) async {
    final svc = _ref.read(messageServiceProvider.notifier);
    final conversations = _ref.read(messageServiceProvider).conversations;
    final all = <MessageSearchResult>[];
    for (final conversation in conversations.take(50)) {
      try {
        all.addAll(
          await svc.searchLocalMessages(
            conversationId: conversation.conversationId,
            keyword: query,
            count: 5,
          ),
        );
      } catch (_) {
        // 单个会话搜索失败不阻塞整体结果
      }
    }
    return all;
  }

  @override
  Future<List<Conversation>> searchConversations(String query) async {
    final keyword = query.trim().toLowerCase();
    if (keyword.isEmpty) return const [];
    final conversations = _ref.read(messageServiceProvider).conversations;
    return conversations
        .where(
          (c) =>
              c.showName.toLowerCase().contains(keyword) ||
              (c.groupId.isNotEmpty && c.groupId.contains(keyword)) ||
              (c.userId.isNotEmpty && c.userId.contains(keyword)),
        )
        .toList(growable: false);
  }

  @override
  Future<List<FriendSearchResult>> searchContacts(String query) {
    return _ref.read(friendSearchRepositoryProvider).search(query);
  }

  @override
  Future<List<Group>> searchGroups(String query) {
    return _ref.read(groupRepositoryProvider).searchGroups(query);
  }
}

/// 搜索页面状态
class SearchState {
  final String query;
  final SearchCategory category;
  final bool searching;
  final String? error;
  final List<MessageSearchResult> messageResults;
  final List<Conversation> conversationResults;
  final List<FriendSearchResult> friendResults;
  final List<Group> groupResults;

  /// 最近搜索关键词（最新在前），空查询时展示。
  final List<String> history;

  const SearchState({
    this.query = '',
    this.category = SearchCategory.message,
    this.searching = false,
    this.error,
    this.messageResults = const [],
    this.conversationResults = const [],
    this.friendResults = const [],
    this.groupResults = const [],
    this.history = const [],
  });

  SearchState copyWith({
    String? query,
    SearchCategory? category,
    bool? searching,
    String? error,
    bool clearError = false,
    List<MessageSearchResult>? messageResults,
    List<Conversation>? conversationResults,
    List<FriendSearchResult>? friendResults,
    List<Group>? groupResults,
    List<String>? history,
  }) {
    return SearchState(
      query: query ?? this.query,
      category: category ?? this.category,
      searching: searching ?? this.searching,
      error: clearError ? null : (error ?? this.error),
      messageResults: messageResults ?? this.messageResults,
      conversationResults: conversationResults ?? this.conversationResults,
      friendResults: friendResults ?? this.friendResults,
      groupResults: groupResults ?? this.groupResults,
      history: history ?? this.history,
    );
  }
}

/// 搜索 ViewModel：负责防抖、分类切换与结果加载。
class SearchViewModel extends Notifier<SearchState> {
  static const _historyKey = 'search_history_v1';
  static const _historyLimit = 10;

  Timer? _debounce;
  int _searchSeq = 0;

  @override
  SearchState build() {
    ref.onDispose(() => _debounce?.cancel());
    unawaited(_loadHistory());
    return const SearchState();
  }

  SearchGateway get _gateway => ref.read(searchGatewayProvider);

  Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final history = prefs.getStringList(_historyKey) ?? const <String>[];
      if (history.isEmpty) return;
      state = state.copyWith(history: history);
    } catch (_) {
      // 本地存储不可用时忽略，不影响搜索本身
    }
  }

  /// 记录一次搜索（去重、最新在前、最多 10 条）。
  Future<void> recordHistory(String rawQuery) async {
    final query = rawQuery.trim();
    if (query.isEmpty) return;
    final next = <String>[
      query,
      ...state.history.where((item) => item != query),
    ].take(_historyLimit).toList(growable: false);
    state = state.copyWith(history: next);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_historyKey, next);
    } catch (_) {
      // 写入失败只影响下次打开时能否看到历史
    }
  }

  Future<void> clearHistory() async {
    state = state.copyWith(history: const []);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_historyKey);
    } catch (_) {}
  }

  void onQueryChanged(String rawQuery) {
    final query = rawQuery.trim();
    _debounce?.cancel();
    if (query.isEmpty) {
      _searchSeq++;
      state = state.copyWith(
        query: '',
        searching: false,
        clearError: true,
        messageResults: const [],
        conversationResults: const [],
        friendResults: const [],
        groupResults: const [],
      );
      return;
    }
    state = state.copyWith(query: query);
    _debounce = Timer(const Duration(milliseconds: 300), () {
      unawaited(_search());
    });
  }

  void setCategory(SearchCategory category) {
    if (state.category == category) return;
    state = state.copyWith(category: category, clearError: true);
    if (state.query.isNotEmpty) {
      _debounce?.cancel();
      unawaited(_search());
    }
  }

  Future<void> _search() async {
    final seq = ++_searchSeq;
    final query = state.query;
    state = state.copyWith(searching: true, clearError: true);
    try {
      switch (state.category) {
        case SearchCategory.message:
          final results = await _gateway.searchMessages(query);
          if (seq != _searchSeq) return;
          state = state.copyWith(searching: false, messageResults: results);
        case SearchCategory.conversations:
          final results = await _gateway.searchConversations(query);
          if (seq != _searchSeq) return;
          state = state.copyWith(
            searching: false,
            conversationResults: results,
          );
        case SearchCategory.contacts:
          final results = await _gateway.searchContacts(query);
          if (seq != _searchSeq) return;
          state = state.copyWith(searching: false, friendResults: results);
        case SearchCategory.groups:
          final results = await _gateway.searchGroups(query);
          if (seq != _searchSeq) return;
          state = state.copyWith(searching: false, groupResults: results);
      }
    } catch (e) {
      if (seq != _searchSeq) return;
      state = state.copyWith(searching: false, error: '搜索失败: $e');
    }
  }
}
