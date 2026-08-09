import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/repositories/friend_application_repository.dart';
import '../../../../domain/models/friend_application.dart';

class FriendApplyState {
  final List<FriendApplication> received;
  final List<FriendApplication> sent;
  final bool isLoading;
  final String? error;

  const FriendApplyState({
    this.received = const [],
    this.sent = const [],
    this.isLoading = false,
    this.error,
  });

  FriendApplyState copyWith({
    List<FriendApplication>? received,
    List<FriendApplication>? sent,
    bool? isLoading,
    String? error,
  }) {
    return FriendApplyState(
      received: received ?? this.received,
      sent: sent ?? this.sent,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  int get unhandledCount => received.length;
}

class FriendApplyViewModel extends StateNotifier<FriendApplyState> {
  FriendApplyViewModel({required FriendApplicationRepository repository})
    : _repository = repository,
      super(const FriendApplyState());

  final FriendApplicationRepository _repository;

  Future<void> loadApplications() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _repository.loadApplications();
      state = state.copyWith(
        received: result.received,
        sent: result.sent,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '加载好友申请失败: $e');
    }
  }

  Future<bool> acceptApplication(String userId, {String? handleMsg}) async {
    try {
      await _repository.accept(userId, handleMsg: handleMsg);
      await loadApplications();
      return true;
    } catch (e) {
      state = state.copyWith(error: '接受好友申请失败: $e');
      return false;
    }
  }

  Future<bool> refuseApplication(String userId, {String? handleMsg}) async {
    try {
      await _repository.refuse(userId, handleMsg: handleMsg);
      await loadApplications();
      return true;
    } catch (e) {
      state = state.copyWith(error: '拒绝好友申请失败: $e');
      return false;
    }
  }
}
