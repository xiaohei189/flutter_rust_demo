import '../../generated/rust/ffi/client.dart' as fb;
import '../../generated/rust/model/group.dart' show GroupInfo, GroupMember;
import '../../generated/rust/http/group.dart' show GroupApplyInfo;
import 'group_service_parts.dart';

abstract class GroupService {
  static GroupService get instance => GroupServiceImpl.instance;

  Future<List<GroupInfo>> getGroupList(fb.OpenImBridgeClient client);

  Future<List<GroupInfo>> getJoinedGroupListPage(
    fb.OpenImBridgeClient client, {
    required int offset,
    required int count,
  });

  Future<List<GroupInfo>> getGroupsInfo(
    fb.OpenImBridgeClient client, {
    required List<String> groupIds,
  });

  Future<List<GroupInfo>> searchGroups(
    fb.OpenImBridgeClient client, {
    required String keyword,
  });

  Future<GroupInfo> createGroup(
    fb.OpenImBridgeClient client, {
    required String groupName,
    required int groupType,
    required List<String> memberIds,
  });

  Future<void> setGroupInfo(
    fb.OpenImBridgeClient client, {
    required String groupId,
    String? groupName,
    String? faceUrl,
    String? introduction,
    String? notification,
  });

  Future<void> dismissGroup(
    fb.OpenImBridgeClient client, {
    required String groupId,
  });

  Future<void> quitGroup(
    fb.OpenImBridgeClient client, {
    required String groupId,
  });

  Future<void> joinGroup(
    fb.OpenImBridgeClient client, {
    required String groupId,
    required String reqMsg,
  });

  Future<void> transferGroupOwner(
    fb.OpenImBridgeClient client, {
    required String groupId,
    required String newOwnerUserId,
  });

  Future<List<GroupMember>> getGroupMembers(
    fb.OpenImBridgeClient client, {
    required String groupId,
  });

  Future<List<GroupMember>> getGroupMemberOwnerAndAdmin(
    fb.OpenImBridgeClient client, {
    required String groupId,
  });

  Future<List<GroupMember>> getGroupMembersInfo(
    fb.OpenImBridgeClient client, {
    required String groupId,
    required List<String> userIds,
  });

  Future<List<GroupMember>> searchGroupMembers(
    fb.OpenImBridgeClient client, {
    required String groupId,
    required String keyword,
  });

  Future<void> inviteGroupMembers(
    fb.OpenImBridgeClient client, {
    required String groupId,
    required List<String> memberIds,
  });

  Future<void> kickGroupMembers(
    fb.OpenImBridgeClient client, {
    required String groupId,
    required List<String> memberIds,
  });

  Future<void> muteGroup(
    fb.OpenImBridgeClient client, {
    required String groupId,
    required bool isMute,
  });

  Future<void> muteGroupMember(
    fb.OpenImBridgeClient client, {
    required String groupId,
    required String userId,
    required int mutedSeconds,
  });

  Future<void> muteGroupMembers(
    fb.OpenImBridgeClient client, {
    required String groupId,
    required List<String> userIds,
    required int mutedSeconds,
  });

  Future<void> setGroupMemberInfo(
    fb.OpenImBridgeClient client, {
    required String groupId,
    required String userId,
    String? nickname,
    String? faceUrl,
    int? roleLevel,
    String? ex,
  });

  Future<bool> isInGroup(
    fb.OpenImBridgeClient client, {
    required String groupId,
  });

  Future<List<GroupApplyInfo>> getGroupApplicationList(
    fb.OpenImBridgeClient client,
  );

  Future<List<GroupApplyInfo>> getGroupApplicationListAsApplicant(
    fb.OpenImBridgeClient client,
  );

  Future<List<GroupApplyInfo>> getGroupApplicationListAsRecipient(
    fb.OpenImBridgeClient client,
  );

  Future<void> acceptGroupApplication(
    fb.OpenImBridgeClient client, {
    required String groupId,
    required String userId,
    String? handleMsg,
  });

  Future<void> refuseGroupApplication(
    fb.OpenImBridgeClient client, {
    required String groupId,
    required String userId,
    String? handleMsg,
  });
}

/// 群组服务 - 封装群组相关 FFI 调用
///
/// 职责：
/// 1. 群组列表管理（获取、搜索、分页）
/// 2. 群组信息管理（创建、修改、解散）
/// 3. 群成员管理（邀请、踢出、禁言、设置信息）
/// 4. 群申请管理（接受、拒绝）

class GroupServiceImpl
    with GroupListMixin, GroupInfoMixin, GroupMemberMixin, GroupApplicationMixin
    implements GroupService {
  static final GroupServiceImpl _instance = GroupServiceImpl();

  /// 全局单例实例
  static GroupServiceImpl get instance => _instance;

  GroupServiceImpl();
}
