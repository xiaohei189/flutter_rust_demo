import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/repositories/group_repository.dart';
import '../../../../domain/models/group.dart';

class CreateGroupState {
  final bool isCreating;
  final Group? createdGroup;
  final List<String> selectedMemberIds;
  final String? error;

  const CreateGroupState({
    this.isCreating = false,
    this.createdGroup,
    this.selectedMemberIds = const [],
    this.error,
  });

  CreateGroupState copyWith({
    bool? isCreating,
    Group? createdGroup,
    List<String>? selectedMemberIds,
    String? error,
    bool clearCreatedGroup = false,
  }) {
    return CreateGroupState(
      isCreating: isCreating ?? this.isCreating,
      createdGroup: clearCreatedGroup
          ? null
          : (createdGroup ?? this.createdGroup),
      selectedMemberIds: selectedMemberIds ?? this.selectedMemberIds,
      error: error,
    );
  }
}

class CreateGroupViewModel extends StateNotifier<CreateGroupState> {
  CreateGroupViewModel({required GroupRepository repository})
    : _repository = repository,
      super(const CreateGroupState());

  final GroupRepository _repository;

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
