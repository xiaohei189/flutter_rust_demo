import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/topic_repository.dart';
import '../../../domain/models/topic.dart';
import '../providers/topic_provider.dart';

class TopicGroupState {
  final TopicTab tab;
  final List<TopicFeedItem> items;
  final String cursor;
  final bool hasMore;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;

  const TopicGroupState({
    this.tab = TopicTab.all,
    this.items = const [],
    this.cursor = '',
    this.hasMore = true,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
  });

  TopicGroupState copyWith({
    TopicTab? tab,
    List<TopicFeedItem>? items,
    String? cursor,
    bool? hasMore,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    bool clearError = false,
  }) {
    return TopicGroupState(
      tab: tab ?? this.tab,
      items: items ?? this.items,
      cursor: cursor ?? this.cursor,
      hasMore: hasMore ?? this.hasMore,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class TopicGroupViewModel extends FamilyNotifier<TopicGroupState, String> {
  TopicRepository get _repository => ref.read(topicRepositoryProvider);

  @override
  TopicGroupState build(String groupId) {
    Future.microtask(load);
    return const TopicGroupState(isLoading: true);
  }

  Future<void> setTab(TopicTab tab) async {
    if (state.tab == tab) return;
    state = state.copyWith(tab: tab, items: const [], cursor: '', hasMore: true);
    await load();
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final page = await _repository.getTopics(groupId: arg, tab: state.tab);
      state = state.copyWith(
        items: page.items,
        cursor: page.nextCursor,
        hasMore: page.hasMore,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '加载话题失败: $e');
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) return;
    state = state.copyWith(isLoadingMore: true, clearError: true);
    try {
      final page = await _repository.getTopics(
        groupId: arg,
        tab: state.tab,
        cursor: state.cursor,
      );
      final seen = state.items.map((item) => item.topic?.topicId ?? item.systemEventId).toSet();
      final more = page.items
          .where(
            (item) => seen.add(item.topic?.topicId ?? item.systemEventId),
          )
          .toList(growable: false);
      state = state.copyWith(
        items: [...state.items, ...more],
        cursor: page.nextCursor,
        hasMore: page.hasMore,
        isLoadingMore: false,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false, error: '加载更多失败: $e');
    }
  }

  Future<void> refresh() => load();
}
