import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/repositories/friend_search_repository.dart';
import '../../../../domain/models/friend_search_result.dart';
import '../providers/friend_provider.dart';

class FriendSearchState {
  final List<FriendSearchResult> results;
  final bool isLoading;
  final String? error;

  const FriendSearchState({
    this.results = const [],
    this.isLoading = false,
    this.error,
  });

  FriendSearchState copyWith({
    List<FriendSearchResult>? results,
    bool? isLoading,
    String? error,
  }) {
    return FriendSearchState(
      results: results ?? this.results,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class FriendSearchViewModel extends Notifier<FriendSearchState> {
  @override
  FriendSearchState build() => const FriendSearchState();

  FriendSearchRepository get _repository =>
      ref.read(friendSearchRepositoryProvider);

  Future<void> search(String keyword) async {
    if (keyword.trim().isEmpty) {
      state = const FriendSearchState();
      return;
    }

    state = state.copyWith(isLoading: true, error: null);
    try {
      final results = await _repository.search(keyword);
      state = state.copyWith(results: results, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '搜索好友失败: $e');
    }
  }

  void clear() {
    state = const FriendSearchState();
  }

  Future<bool> sendFriendRequest(String userId, String reqMsg) async {
    try {
      await _repository.sendFriendRequest(userId, reqMsg);
      return true;
    } catch (e) {
      state = state.copyWith(error: '发送好友申请失败: $e');
      return false;
    }
  }
}
