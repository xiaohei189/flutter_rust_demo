import '../../domain/models/group.dart';
import '../../domain/models/group_application.dart';
import '../../domain/models/group_member.dart';
import '../../services/group_service.dart';
import '../../services/im_client.dart';
import '../../src/rust/ffi/client.dart';
import '../../src/rust/http/group.dart' show GroupApplyInfo;
import '../../src/rust/model/group.dart' as raw_group;

abstract class GroupRepository {
  Future<List<Group>> loadGroups({int offset = 0, int count = 50});
  Future<List<Group>> searchGroups(String keyword);

  Future<({List<GroupApplication> received, List<GroupApplication> sent})>
  loadApplications();

  Future<void> acceptGroupApplication({
    required String groupId,
    required String userId,
    String? handleMsg,
  });

  Future<void> refuseGroupApplication({
    required String groupId,
    required String userId,
    String? handleMsg,
  });

  Future<Group> createGroup({
    required String groupName,
    required int groupType,
    required List<String> memberIds,
  });

  Future<List<GroupMember>> loadMembers(String groupId);
  Future<void> inviteMembers(String groupId, List<String> memberIds);
  Future<void> kickMembers(String groupId, List<String> memberIds);
  Future<void> muteMember(String groupId, String userId, int mutedSeconds);
  Future<void> transferOwner(String groupId, String newOwnerUserId);
  Future<void> dismissGroup(String groupId);
  Future<void> muteAll(String groupId, bool isMute);
  Future<void> setGroupMemberInfo(
    String groupId,
    String userId, {
    String? nickname,
    String? faceUrl,
    int? roleLevel,
    String? ex,
  });
  Future<List<Group>> getGroupsInfo(List<String> groupIds);
  Future<void> setGroupInfo(
    String groupId, {
    String? groupName,
    String? faceUrl,
    String? introduction,
    String? notification,
  });
  Future<void> quitGroup(String groupId);
  Future<void> joinGroup(String groupId, String reqMsg);
}

class GroupRepositoryImpl implements GroupRepository {
  GroupRepositoryImpl({
    required GroupService groupService,
    required ImClient imClient,
  }) : _groupService = groupService,
       _imClient = imClient;

  final GroupService _groupService;
  final ImClient _imClient;

  @override
  Future<List<Group>> loadGroups({int offset = 0, int count = 50}) async {
    final client = _requireClient();
    final groups = await _groupService.getJoinedGroupListPage(
      client,
      offset: offset,
      count: count,
    );
    return groups.map(mapGroup).toList(growable: false);
  }

  @override
  Future<List<Group>> searchGroups(String keyword) async {
    final client = _requireClient();
    final groups = await _groupService.searchGroups(
      client,
      keyword: keyword,
    );
    return groups.map(mapGroup).toList(growable: false);
  }

  @override
  Future<({List<GroupApplication> received, List<GroupApplication> sent})>
  loadApplications() async {
    final client = _requireClient();
    final received = await _groupService.getGroupApplicationListAsRecipient(
      client,
    );
    final sent = await _groupService.getGroupApplicationListAsApplicant(client);
    return (
      received: received.map(mapApplication).toList(growable: false),
      sent: sent.map(mapApplication).toList(growable: false),
    );
  }

  @override
  Future<void> acceptGroupApplication({
    required String groupId,
    required String userId,
    String? handleMsg,
  }) async {
    final client = _requireClient();
    await _groupService.acceptGroupApplication(
      client,
      groupId: groupId,
      userId: userId,
      handleMsg: handleMsg,
    );
  }

  @override
  Future<void> refuseGroupApplication({
    required String groupId,
    required String userId,
    String? handleMsg,
  }) async {
    final client = _requireClient();
    await _groupService.refuseGroupApplication(
      client,
      groupId: groupId,
      userId: userId,
      handleMsg: handleMsg,
    );
  }

  @override
  Future<Group> createGroup({
    required String groupName,
    required int groupType,
    required List<String> memberIds,
  }) async {
    final client = _requireClient();
    final group = await _groupService.createGroup(
      client,
      groupName: groupName,
      groupType: groupType,
      memberIds: memberIds,
    );
    return mapGroup(group);
  }

  @override
  Future<List<GroupMember>> loadMembers(String groupId) async {
    final client = _requireClient();
    final members = await _groupService.getGroupMembers(
      client,
      groupId: groupId,
    );
    return members.map(mapMember).toList(growable: false);
  }

  @override
  Future<void> inviteMembers(String groupId, List<String> memberIds) async {
    final client = _requireClient();
    await _groupService.inviteGroupMembers(
      client,
      groupId: groupId,
      memberIds: memberIds,
    );
  }

  @override
  Future<void> kickMembers(String groupId, List<String> memberIds) async {
    final client = _requireClient();
    await _groupService.kickGroupMembers(
      client,
      groupId: groupId,
      memberIds: memberIds,
    );
  }

  @override
  Future<void> muteMember(
    String groupId,
    String userId,
    int mutedSeconds,
  ) async {
    final client = _requireClient();
    await _groupService.muteGroupMember(
      client,
      groupId: groupId,
      userId: userId,
      mutedSeconds: mutedSeconds,
    );
  }

  @override
  Future<void> transferOwner(String groupId, String newOwnerUserId) async {
    final client = _requireClient();
    await _groupService.transferGroupOwner(
      client,
      groupId: groupId,
      newOwnerUserId: newOwnerUserId,
    );
  }

  @override
  Future<void> dismissGroup(String groupId) async {
    final client = _requireClient();
    await _groupService.dismissGroup(client, groupId: groupId);
  }

  @override
  Future<void> muteAll(String groupId, bool isMute) async {
    final client = _requireClient();
    await _groupService.muteGroup(client, groupId: groupId, isMute: isMute);
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
    final client = _requireClient();
    await _groupService.setGroupMemberInfo(
      client,
      groupId: groupId,
      userId: userId,
      nickname: nickname,
      faceUrl: faceUrl,
      roleLevel: roleLevel,
      ex: ex,
    );
  }

  @override
  Future<List<Group>> getGroupsInfo(List<String> groupIds) async {
    final client = _requireClient();
    final groups = await _groupService.getGroupsInfo(
      client,
      groupIds: groupIds,
    );
    return groups.map(mapGroup).toList(growable: false);
  }

  @override
  Future<void> setGroupInfo(
    String groupId, {
    String? groupName,
    String? faceUrl,
    String? introduction,
    String? notification,
  }) async {
    final client = _requireClient();
    await _groupService.setGroupInfo(
      client,
      groupId: groupId,
      groupName: groupName,
      faceUrl: faceUrl,
      introduction: introduction,
      notification: notification,
    );
  }

  @override
  Future<void> quitGroup(String groupId) async {
    final client = _requireClient();
    await _groupService.quitGroup(client, groupId: groupId);
  }

  @override
  Future<void> joinGroup(String groupId, String reqMsg) async {
    final client = _requireClient();
    await _groupService.joinGroup(client, groupId: groupId, reqMsg: reqMsg);
  }

  OpenImBridgeClient _requireClient() {
    final client = _imClient.client;
    if (client == null) {
      throw StateError('客户端未初始化');
    }
    return client;
  }

  static Group mapGroup(raw_group.GroupInfo item) {
    return Group(
      groupId: item.groupId,
      groupName: item.groupName,
      faceUrl: item.faceUrl,
      introduction: item.introduction,
      notification: item.notification,
      ownerUserId: item.ownerUserId,
      memberCount: item.memberCount,
      status: item.status,
      createdTime: _epochOrNull(item.createTime.toInt()),
    );
  }

  static GroupApplication mapApplication(GroupApplyInfo item) {
    return GroupApplication(
      groupId: item.groupId,
      userId: item.userId,
      nickname: item.nickname,
      faceUrl: item.faceUrl,
      reason: item.reason,
      handleResult: item.handleResult,
      ex: item.ex,
    );
  }

  static GroupMember mapMember(raw_group.GroupMember item) {
    return GroupMember(
      groupId: item.groupId,
      userId: item.userId,
      nickname: item.nickname,
      faceUrl: item.faceUrl,
      roleLevel: item.roleLevel,
      joinSource: item.joinSource,
      joinTime: _epochOrNull(item.joinTime.toInt()),
    );
  }

  static DateTime? _epochOrNull(int epochMs) {
    if (epochMs <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(epochMs);
  }
}
