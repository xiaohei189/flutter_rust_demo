import '../../generated/rust/ffi/client.dart' as fb;
import '../../generated/rust/model/group.dart' show GroupInfo;
import '../../core/utils/app_logger.dart';

mixin GroupInfoMixin on Object {
  // ==================== 群组信息管理 ====================

  /// 创建群组
  Future<GroupInfo> createGroup(
    fb.OpenImBridgeClient client, {
    required String groupName,
    required int groupType,
    required List<String> memberIds,
  }) async {
    try {
      final group = await client.createGroup(
        groupName: groupName,
        groupType: groupType,
        memberIds: memberIds,
      );
      appLog.i('[GroupService] 创建群组成功: ${group.groupId}');
      return group;
    } catch (e) {
      appLog.e('[GroupService] 创建群组失败: $e');
      rethrow;
    }
  }

  /// 修改群组信息
  Future<void> setGroupInfo(
    fb.OpenImBridgeClient client, {
    required String groupId,
    String? groupName,
    String? faceUrl,
    String? introduction,
    String? notification,
  }) async {
    try {
      await client.setGroupInfo(
        groupId: groupId,
        groupName: groupName,
        faceUrl: faceUrl,
        introduction: introduction,
        notification: notification,
      );
      appLog.i('[GroupService] 修改群组信息成功: $groupId');
    } catch (e) {
      appLog.e('[GroupService] 修改群组信息失败: $e');
      rethrow;
    }
  }

  /// 解散群组
  Future<void> dismissGroup(
    fb.OpenImBridgeClient client, {
    required String groupId,
  }) async {
    try {
      await client.dismissGroup(groupId: groupId);
      appLog.i('[GroupService] 解散群组成功: $groupId');
    } catch (e) {
      appLog.e('[GroupService] 解散群组失败: $e');
      rethrow;
    }
  }

  /// 退出群组
  Future<void> quitGroup(
    fb.OpenImBridgeClient client, {
    required String groupId,
  }) async {
    try {
      await client.quitGroup(groupId: groupId);
      appLog.i('[GroupService] 退出群组成功: $groupId');
    } catch (e) {
      appLog.e('[GroupService] 退出群组失败: $e');
      rethrow;
    }
  }

  /// 加入群组
  Future<void> joinGroup(
    fb.OpenImBridgeClient client, {
    required String groupId,
    required String reqMsg,
  }) async {
    try {
      await client.joinGroup(groupId: groupId, reqMsg: reqMsg);
      appLog.i('[GroupService] 申请加入群组成功: $groupId');
    } catch (e) {
      appLog.e('[GroupService] 申请加入群组失败: $e');
      rethrow;
    }
  }

  /// 转让群主
  Future<void> transferGroupOwner(
    fb.OpenImBridgeClient client, {
    required String groupId,
    required String newOwnerUserId,
  }) async {
    try {
      await client.transferGroupOwner(
        groupId: groupId,
        newOwnerUserId: newOwnerUserId,
      );
      appLog.i('[GroupService] 转让群主成功: $groupId -> $newOwnerUserId');
    } catch (e) {
      appLog.e('[GroupService] 转让群主失败: $e');
      rethrow;
    }
  }
}

/// GroupMemberMixin
