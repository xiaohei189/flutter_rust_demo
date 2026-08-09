import 'package:flutter_rust_demo/data/repositories/group_repository.dart';
import 'package:flutter_rust_demo/domain/models/group.dart';
import 'package:flutter_rust_demo/domain/models/group_application.dart';
import 'package:flutter_rust_demo/domain/models/group_member.dart';

class BaseFakeGroupRepository implements GroupRepository {
  @override
  Future<List<Group>> loadGroups({int offset = 0, int count = 50}) async {
    throw UnimplementedError();
  }

  @override
  Future<List<Group>> searchGroups(String keyword) async {
    throw UnimplementedError();
  }

  @override
  Future<({List<GroupApplication> received, List<GroupApplication> sent})>
  loadApplications() async {
    throw UnimplementedError();
  }

  @override
  Future<void> acceptGroupApplication({
    required String groupId,
    required String userId,
    String? handleMsg,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> refuseGroupApplication({
    required String groupId,
    required String userId,
    String? handleMsg,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<Group> createGroup({
    required String groupName,
    required int groupType,
    required List<String> memberIds,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<List<GroupMember>> loadMembers(String groupId) async {
    throw UnimplementedError();
  }

  @override
  Future<void> inviteMembers(String groupId, List<String> memberIds) async {
    throw UnimplementedError();
  }

  @override
  Future<void> kickMembers(String groupId, List<String> memberIds) async {
    throw UnimplementedError();
  }

  @override
  Future<void> muteMember(
    String groupId,
    String userId,
    int mutedSeconds,
  ) async {
    throw UnimplementedError();
  }

  @override
  Future<void> transferOwner(String groupId, String newOwnerUserId) async {
    throw UnimplementedError();
  }

  @override
  Future<void> dismissGroup(String groupId) async {
    throw UnimplementedError();
  }

  @override
  Future<void> muteAll(String groupId, bool isMute) async {
    throw UnimplementedError();
  }

  @override
  Future<void> setGroupMemberInfo(
    String groupId,
    String userId, {
    String? nickname,
    String? faceUrl,
    int? roleLevel,
    String? ex,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<List<Group>> getGroupsInfo(List<String> groupIds) async {
    throw UnimplementedError();
  }

  @override
  Future<void> setGroupInfo(
    String groupId, {
    String? groupName,
    String? faceUrl,
    String? introduction,
    String? notification,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> quitGroup(String groupId) async {
    throw UnimplementedError();
  }

  @override
  Future<void> joinGroup(String groupId, String reqMsg) async {
    throw UnimplementedError();
  }
}
