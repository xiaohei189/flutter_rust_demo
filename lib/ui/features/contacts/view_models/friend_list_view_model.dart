import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/repositories/friend_repository.dart';
import '../../../../domain/models/friend.dart';

class FriendListState {
  final List<Friend> friends;
  final bool isLoading;
  final String? error;

  const FriendListState({
    this.friends = const [],
    this.isLoading = false,
    this.error,
  });

  FriendListState copyWith({
    List<Friend>? friends,
    bool? isLoading,
    String? error,
  }) {
    return FriendListState(
      friends: friends ?? this.friends,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  int get friendCount => friends.length;
}

class FriendListViewModel extends StateNotifier<FriendListState> {
  FriendListViewModel({required FriendRepository repository})
    : _repository = repository,
      super(const FriendListState());

  final FriendRepository _repository;

  Future<void> loadFriends() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final friends = await _repository.loadFriends();
      state = state.copyWith(friends: friends, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '加载好友列表失败: $e');
    }
  }

  Future<void> searchFriends(String keyword) async {
    if (keyword.trim().isEmpty) {
      await loadFriends();
      return;
    }

    state = state.copyWith(isLoading: true, error: null);
    try {
      final friends = await _repository.searchFriends(keyword);
      state = state.copyWith(friends: friends, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '搜索好友失败: $e');
    }
  }

  Future<bool> deleteFriend(String userId) async {
    try {
      await _repository.deleteFriend(userId);
      await loadFriends();
      return true;
    } catch (e) {
      state = state.copyWith(error: '删除好友失败: $e');
      return false;
    }
  }
}
