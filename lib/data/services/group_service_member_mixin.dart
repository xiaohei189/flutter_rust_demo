import '../../generated/rust/ffi/client.dart' as fb;
import '../../generated/rust/model/group.dart' show GroupMember;
import '../../core/utils/app_logger.dart';

mixin GroupMemberMixin on Object {
  // ==================== 群成员管理 ====================

  /// 获取群成员列表
  Future<List<GroupMember>> getGroupMembers(
    fb.OpenImBridgeClient client, {
    required String groupId,
  }) async {
    try {
      final members = await client.getGroupMembers(groupId: groupId);
      appLog.i('[GroupService] 获取群成员列表成功: $groupId, 共 ${members.length} 人');
      return members;
    } catch (e) {
      appLog.e('[GroupService] 获取群成员列表失败: $e');
      rethrow;
    }
  }

  /// 获取群主和管理员列表
  Future<List<GroupMember>> getGroupMemberOwnerAndAdmin(
    fb.OpenImBridgeClient client, {
    required String groupId,
  }) async {
    try {
      return await client.getGroupMemberOwnerAndAdmin(groupId: groupId);
    } catch (e) {
      appLog.e('[GroupService] 获取群主和管理员列表失败: $e');
      rethrow;
    }
  }

  /// 根据用户 ID 列表获取群成员信息
  Future<List<GroupMember>> getGroupMembersInfo(
    fb.OpenImBridgeClient client, {
    required String groupId,
    required List<String> userIds,
  }) async {
    try {
      return await client.getGroupMembersInfo(
        groupId: groupId,
        userIds: userIds,
      );
    } catch (e) {
      appLog.e('[GroupService] 获取群成员信息失败: $e');
      rethrow;
    }
  }

  /// 搜索群成员
  Future<List<GroupMember>> searchGroupMembers(
    fb.OpenImBridgeClient client, {
    required String groupId,
    required String keyword,
  }) async {
    try {
      return await client.searchGroupMembers(
        groupId: groupId,
        keyword: keyword,
      );
    } catch (e) {
      appLog.e('[GroupService] 搜索群成员失败: $e');
      rethrow;
    }
  }

  /// 邀请用户加入群组
  Future<void> inviteGroupMembers(
    fb.OpenImBridgeClient client, {
    required String groupId,
    required List<String> memberIds,
  }) async {
    try {
      await client.inviteGroupMembers(groupId: groupId, memberIds: memberIds);
      appLog.i('[GroupService] 邀请群成员成功: $groupId, ${memberIds.length} 人');
    } catch (e) {
      appLog.e('[GroupService] 邀请群成员失败: $e');
      rethrow;
    }
  }

  /// 踢出群成员
  Future<void> kickGroupMembers(
    fb.OpenImBridgeClient client, {
    required String groupId,
    required List<String> memberIds,
  }) async {
    try {
      await client.kickGroupMembers(groupId: groupId, memberIds: memberIds);
      appLog.i('[GroupService] 踢出群成员成功: $groupId, ${memberIds.length} 人');
    } catch (e) {
      appLog.e('[GroupService] 踢出群成员失败: $e');
      rethrow;
    }
  }

  /// 禁言群组（全员禁言）
  Future<void> muteGroup(
    fb.OpenImBridgeClient client, {
    required String groupId,
    required bool isMute,
  }) async {
    try {
      await client.muteGroup(groupId: groupId, isMute: isMute);
      appLog.i('[GroupService] ${isMute ? "禁言" : "解除禁言"}群组成功: $groupId');
    } catch (e) {
      appLog.e('[GroupService] 禁言群组失败: $e');
      rethrow;
    }
  }

  /// 禁言群成员（单个用户）
  Future<void> muteGroupMember(
    fb.OpenImBridgeClient client, {
    required String groupId,
    required String userId,
    required int mutedSeconds,
  }) async {
    try {
      await client.muteGroupMember(
        groupId: groupId,
        userId: userId,
        mutedSeconds: mutedSeconds,
      );
      appLog.i(
        '[GroupService] 禁言群成员成功: $groupId, user=$userId, '
        'seconds=$mutedSeconds',
      );
    } catch (e) {
      appLog.e('[GroupService] 禁言群成员失败: $e');
      rethrow;
    }
  }

  /// 批量禁言群成员
  ///
  /// 逐个调用 FFI 禁言接口，失败时记录日志但不中断后续操作。
  Future<void> muteGroupMembers(
    fb.OpenImBridgeClient client, {
    required String groupId,
    required List<String> userIds,
    required int mutedSeconds,
  }) async {
    for (final userId in userIds) {
      try {
        await muteGroupMember(
          client,
          groupId: groupId,
          userId: userId,
          mutedSeconds: mutedSeconds,
        );
      } catch (e) {
        appLog.w('[GroupService] 批量禁言部分失败: userId=$userId, error=$e');
      }
    }
  }

  /// 设置群成员信息
  Future<void> setGroupMemberInfo(
    fb.OpenImBridgeClient client, {
    required String groupId,
    required String userId,
    String? nickname,
    String? faceUrl,
    int? roleLevel,
    String? ex,
  }) async {
    try {
      await client.setGroupMemberInfo(
        groupId: groupId,
        userId: userId,
        nickname: nickname,
        faceUrl: faceUrl,
        roleLevel: roleLevel,
        ex: ex,
      );
      appLog.i('[GroupService] 设置群成员信息成功: $groupId, user=$userId');
    } catch (e) {
      appLog.e('[GroupService] 设置群成员信息失败: $e');
      rethrow;
    }
  }

  /// 检查当前用户是否在指定群组中
  Future<bool> isInGroup(
    fb.OpenImBridgeClient client, {
    required String groupId,
  }) async {
    try {
      final group = await client.getGroupsInfo(groupIds: [groupId]);
      return group.isNotEmpty;
    } catch (e) {
      appLog.e('[GroupService] 检查是否在群组中失败: $e');
      return false;
    }
  }
}

/// GroupApplicationMixin
