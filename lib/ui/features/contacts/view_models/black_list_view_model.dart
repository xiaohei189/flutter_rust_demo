import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/repositories/blacklist_repository.dart';
import '../../../../domain/models/blacklist_user.dart';

class BlackListState {
  final List<BlacklistUser> users;
  final bool isLoading;
  final String? error;

  const BlackListState({
    this.users = const [],
    this.isLoading = false,
    this.error,
  });

  BlackListState copyWith({
    List<BlacklistUser>? users,
    bool? isLoading,
    String? error,
  }) {
    return BlackListState(
      users: users ?? this.users,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  int get count => users.length;
}

class BlackListViewModel extends StateNotifier<BlackListState> {
  BlackListViewModel({required BlacklistRepository repository})
    : _repository = repository,
      super(const BlackListState());

  final BlacklistRepository _repository;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final users = await _repository.load();
      state = state.copyWith(users: users, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '加载黑名单失败: $e');
    }
  }

  Future<bool> add(String userId) async {
    try {
      await _repository.add(userId);
      await load();
      return true;
    } catch (e) {
      state = state.copyWith(error: '加入黑名单失败: $e');
      return false;
    }
  }

  Future<bool> remove(String userId) async {
    try {
      await _repository.remove(userId);
      await load();
      return true;
    } catch (e) {
      state = state.copyWith(error: '移出黑名单失败: $e');
      return false;
    }
  }
}
