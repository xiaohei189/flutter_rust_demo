import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/repositories/group_repository.dart';
import '../../../../domain/models/group.dart';
import '../../../../domain/models/group_mode.dart';
import '../providers/group_provider.dart';

class CreateGroupState {
  final bool isCreating;
  final Group? createdGroup;
  final List<String> selectedMemberIds;
  final GroupMode mode;
  final String? error;

  const CreateGroupState({
    this.isCreating = false,
    this.createdGroup,
    this.selectedMemberIds = const [],
    this.mode = GroupMode.chat,
    this.error,
  });

  CreateGroupState copyWith({
    bool? isCreating,
    Group? createdGroup,
    List<String>? selectedMemberIds,
    GroupMode? mode,
    String? error,
    bool clearCreatedGroup = false,
  }) {
    return CreateGroupState(
      isCreating: isCreating ?? this.isCreating,
      createdGroup: clearCreatedGroup
          ? null
          : (createdGroup ?? this.createdGroup),
      selectedMemberIds: selectedMemberIds ?? this.selectedMemberIds,
      mode: mode ?? this.mode,
      error: error,
    );
  }
}

class CreateGroupViewModel extends Notifier<CreateGroupState> {
  @override
  CreateGroupState build() => const CreateGroupState();

  GroupRepository get _repository => ref.read(groupRepositoryProvider);

  void setSelectedMembers(List<String> memberIds) {
    state = state.copyWith(selectedMemberIds: memberIds);
  }

  void addSelectedMember(String userId) {
    if (!state.selectedMemberIds.contains(userId)) {
      state = state.copyWith(
        selectedMemberIds: [...state.selectedMemberIds, userId],
      );
    }
  }

  void removeSelectedMember(String userId) {
    state = state.copyWith(
      selectedMemberIds: state.selectedMemberIds
          .where((id) => id != userId)
          .toList(),
    );
  }

  /// 群模式（对话 / 话题）。当前只落在建群流程里，服务端持久化见 P1 计划。
  void setMode(GroupMode mode) {
    state = state.copyWith(mode: mode);
  }

  Future<Group?> createGroup({
    required String groupName,
    required int groupType,
  }) async {
    if (state.selectedMemberIds.isEmpty) {
      state = state.copyWith(error: '请至少选择一名成员');
      return null;
    }

    state = state.copyWith(isCreating: true, error: null);
    try {
      final group = await _repository.createGroup(
        groupName: groupName,
        groupType: groupType,
        memberIds: state.selectedMemberIds,
      );
      state = state.copyWith(
        isCreating: false,
        createdGroup: group,
        selectedMemberIds: [],
      );
      return group;
    } catch (e) {
      state = state.copyWith(isCreating: false, error: '创建群组失败: $e');
      return null;
    }
  }

  void reset() {
    state = const CreateGroupState();
  }
}
