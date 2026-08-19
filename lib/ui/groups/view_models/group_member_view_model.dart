import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/repositories/group_repository.dart';
import '../../../../domain/models/group_member.dart';
import '../providers/group_provider.dart';
import '../../chat/providers/message_service_provider.dart';

class GroupMemberState {
  final List<GroupMember> members;
  final bool isLoading;
  final String? error;

  const GroupMemberState({
    this.members = const [],
    this.isLoading = false,
    this.error,
  });

  GroupMemberState copyWith({
    List<GroupMember>? members,
    bool? isLoading,
    String? error,
  }) {
    return GroupMemberState(
      members: members ?? this.members,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class GroupMemberViewModel extends FamilyNotifier<GroupMemberState, String> {
  @override
  GroupMemberState build(String groupId) {
    ref.listen(messageServiceProvider.select((s) => s.groupRevision), (prev, next) {
      if (prev != next) {
        loadMembers();
      }
    });
    return const GroupMemberState();
  }

  GroupRepository get _repository => ref.read(groupRepositoryProvider);

  Future<void> loadMembers() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final members = await _repository.loadMembers(arg);
      state = state.copyWith(members: members, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '加载群成员失败: $e');
    }
  }

  Future<bool> inviteMembers(List<String> memberIds) async {
    try {
      await _repository.inviteMembers(arg, memberIds);
      await loadMembers();
      return true;
    } catch (e) {
      state = state.copyWith(error: '邀请成员失败: $e');
      return false;
    }
  }

  Future<bool> kickMembers(List<String> memberIds) async {
    try {
      await _repository.kickMembers(arg, memberIds);
      await loadMembers();
      return true;
    } catch (e) {
      state = state.copyWith(error: '踢出成员失败: $e');
      return false;
    }
  }

  Future<bool> muteMember(String userId, int mutedSeconds) async {
    try {
      await _repository.muteMember(arg, userId, mutedSeconds);
      await loadMembers();
      return true;
    } catch (e) {
      state = state.copyWith(error: '禁言成员失败: $e');
      return false;
    }
  }

  Future<bool> unmuteMember(String userId) async {
    return muteMember(userId, 0);
  }

  Future<bool> transferOwner(String newOwnerUserId) async {
    try {
      await _repository.transferOwner(arg, newOwnerUserId);
      await loadMembers();
      return true;
    } catch (e) {
      state = state.copyWith(error: '转让群主失败: $e');
      return false;
    }
  }

  Future<bool> dismissGroup() async {
    try {
      await _repository.dismissGroup(arg);
      return true;
    } catch (e) {
      state = state.copyWith(error: '解散群组失败: $e');
      return false;
    }
  }

  Future<bool> muteAll(bool isMute) async {
    try {
      await _repository.muteAll(arg, isMute);
      await loadMembers();
      return true;
    } catch (e) {
      state = state.copyWith(error: '全员禁言失败: $e');
      return false;
    }
  }

  Future<bool> setMemberRole(String userId, int roleLevel) async {
    try {
      await _repository.setGroupMemberInfo(arg, userId, roleLevel: roleLevel);
      await loadMembers();
      return true;
    } catch (e) {
      state = state.copyWith(error: '设置成员角色失败: $e');
      return false;
    }
  }
}
