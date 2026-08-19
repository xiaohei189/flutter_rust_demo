import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/repositories/group_repository.dart';
import '../../../../domain/models/group_application.dart';
import '../providers/group_provider.dart';
import '../../chat/providers/message_service_provider.dart';

class GroupApplicationState {
  final List<GroupApplication> received;
  final List<GroupApplication> sent;
  final bool isLoading;
  final String? error;

  const GroupApplicationState({
    this.received = const [],
    this.sent = const [],
    this.isLoading = false,
    this.error,
  });

  GroupApplicationState copyWith({
    List<GroupApplication>? received,
    List<GroupApplication>? sent,
    bool? isLoading,
    String? error,
  }) {
    return GroupApplicationState(
      received: received ?? this.received,
      sent: sent ?? this.sent,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  int get unhandledCount => received.where((a) => a.handleResult == 0).length;
}

class GroupApplicationViewModel extends Notifier<GroupApplicationState> {
  bool _hasLoaded = false;

  @override
  GroupApplicationState build() {
    ref.listen(messageServiceProvider.select((s) => s.groupRevision), (prev, next) {
      if (prev != next && _hasLoaded) {
        loadApplications();
      }
    });
    Future.microtask(() {
      if (!_hasLoaded) {
        _hasLoaded = true;
        loadApplications();
      }
    });
    return const GroupApplicationState();
  }

  GroupRepository get _repository => ref.read(groupRepositoryProvider);

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
      state = state.copyWith(isLoading: false, error: '加载群申请列表失败: $e');
    }
  }

  Future<bool> acceptApplication({
    required String groupId,
    required String userId,
    String? handleMsg,
  }) async {
    try {
      await _repository.acceptGroupApplication(
        groupId: groupId,
        userId: userId,
        handleMsg: handleMsg,
      );
      await loadApplications();
      return true;
    } catch (e) {
      state = state.copyWith(error: '接受群申请失败: $e');
      return false;
    }
  }

  Future<bool> refuseApplication({
    required String groupId,
    required String userId,
    String? handleMsg,
  }) async {
    try {
      await _repository.refuseGroupApplication(
        groupId: groupId,
        userId: userId,
        handleMsg: handleMsg,
      );
      await loadApplications();
      return true;
    } catch (e) {
      state = state.copyWith(error: '拒绝群申请失败: $e');
      return false;
    }
  }
}
