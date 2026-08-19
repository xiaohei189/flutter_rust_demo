import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/repositories/group_repository.dart';
import '../../../../domain/models/group.dart';
import '../providers/group_provider.dart';
import '../../chat/providers/message_service_provider.dart';

class GroupListState {
  final List<Group> groups;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? error;

  const GroupListState({
    this.groups = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.error,
  });

  GroupListState copyWith({
    List<Group>? groups,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? error,
  }) {
    return GroupListState(
      groups: groups ?? this.groups,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      error: error,
    );
  }
}

class GroupListViewModel extends Notifier<GroupListState> {
  static const int _pageSize = 50;

  int _offset = 0;
  bool _hasLoaded = false;

  @override
  GroupListState build() {
    ref.listen(messageServiceProvider.select((s) => s.groupRevision), (prev, next) {
      if (prev != next && _hasLoaded) {
        loadGroups();
      }
    });
    Future.microtask(() {
      if (!_hasLoaded) {
        _hasLoaded = true;
        loadGroups();
      }
    });
    return const GroupListState();
  }

  GroupRepository get _repository => ref.read(groupRepositoryProvider);

  Future<void> loadGroups() async {
    state = state.copyWith(isLoading: true, isLoadingMore: false, error: null);
    try {
      final groups = await _repository.loadGroups(offset: 0, count: _pageSize);
      _offset = groups.length;
      state = state.copyWith(
        groups: groups,
        isLoading: false,
        hasMore: groups.length >= _pageSize,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '加载群组列表失败: $e');
    }
  }

  Future<void> refreshGroups() async {
    await loadGroups();
  }

  Future<void> loadMoreGroups() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) {
      return;
    }
    state = state.copyWith(isLoadingMore: true);
    try {
      final more = await _repository.loadGroups(
        offset: _offset,
        count: _pageSize,
      );
      final merged = [...state.groups, ...more];
      _offset = merged.length;
      state = state.copyWith(
        groups: merged,
        isLoadingMore: false,
        hasMore: more.length >= _pageSize,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false, error: '加载更多群组失败: $e');
    }
  }
}
