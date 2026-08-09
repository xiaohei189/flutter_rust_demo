import '../src/rust/ffi/client.dart' as fb;
import '../src/rust/model/group.dart' show GroupInfo, GroupMember;
import '../src/rust/http/group.dart' show GroupApplyInfo;
import '../utils/app_logger.dart';

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
class GroupServiceImpl implements GroupService {
  static final GroupServiceImpl _instance = GroupServiceImpl._internal();

  /// 全局单例实例
  static GroupServiceImpl get instance => _instance;

  GroupServiceImpl._internal();

  // ==================== 群组列表 ====================

  /// 获取所有已加入的群组列表
  @override
  Future<List<GroupInfo>> getGroupList(fb.OpenImBridgeClient client) async {
    try {
      final groups = await client.getGroupList();
      appLog.i('[GroupService] 获取群组列表成功，共 ${groups.length} 个群');
      return groups;
    } catch (e) {
      appLog.e('[GroupService] 获取群组列表失败: $e');
      rethrow;
    }
  }

  /// 分页获取已加入的群组列表
  @override
  Future<List<GroupInfo>> getJoinedGroupListPage(
    fb.OpenImBridgeClient client, {
    required int offset,
    required int count,
  }) async {
    try {
      return await client.getJoinedGroupListPage(offset: offset, count: count);
    } catch (e) {
      appLog.e('[GroupService] 分页获取群组列表失败: $e');
      rethrow;
    }
  }

  /// 根据群组 ID 列表获取群组信息
  @override
  Future<List<GroupInfo>> getGroupsInfo(
    fb.OpenImBridgeClient client, {
    required List<String> groupIds,
  }) async {
    try {
      return await client.getGroupsInfo(groupIds: groupIds);
    } catch (e) {
      appLog.e('[GroupService] 获取群组信息失败: $e');
      rethrow;
    }
  }

  /// 搜索群组
  @override
  Future<List<GroupInfo>> searchGroups(
    fb.OpenImBridgeClient client, {
    required String keyword,
  }) async {
    try {
      return await client.searchGroups(keyword: keyword);
    } catch (e) {
      appLog.e('[GroupService] 搜索群组失败: $e');
      rethrow;
    }
  }

  // ==================== 群组信息管理 ====================

  /// 创建群组
  @override
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
  @override
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
  @override
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
  @override
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
  @override
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
  @override
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

  // ==================== 群成员管理 ====================

  /// 获取群成员列表
  @override
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
  @override
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
  @override
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
  @override
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
  @override
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
  @override
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
  @override
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
  @override
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
  @override
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
  @override
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
  @override
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

  // ==================== 群申请管理 ====================

  /// 获取所有群申请列表
  @override
  Future<List<GroupApplyInfo>> getGroupApplicationList(
    fb.OpenImBridgeClient client,
  ) async {
    try {
      final list = await client.getGroupApplicationList();
      appLog.i('[GroupService] 获取群申请列表成功，共 ${list.length} 条');
      return list;
    } catch (e) {
      appLog.e('[GroupService] 获取群申请列表失败: $e');
      rethrow;
    }
  }

  /// 获取我发起的群申请列表
  @override
  Future<List<GroupApplyInfo>> getGroupApplicationListAsApplicant(
    fb.OpenImBridgeClient client,
  ) async {
    try {
      return await client.getGroupApplicationListAsApplicant();
    } catch (e) {
      appLog.e('[GroupService] 获取我发起的群申请列表失败: $e');
      rethrow;
    }
  }

  /// 获取我收到的群申请列表
  @override
  Future<List<GroupApplyInfo>> getGroupApplicationListAsRecipient(
    fb.OpenImBridgeClient client,
  ) async {
    try {
      return await client.getGroupApplicationListAsRecipient();
    } catch (e) {
      appLog.e('[GroupService] 获取我收到的群申请列表失败: $e');
      rethrow;
    }
  }

  /// 接受群申请
  @override
  Future<void> acceptGroupApplication(
    fb.OpenImBridgeClient client, {
    required String groupId,
    required String userId,
    String? handleMsg,
  }) async {
    try {
      await client.acceptGroupApplication(
        groupId: groupId,
        userId: userId,
        handleMsg: handleMsg,
      );
      appLog.i('[GroupService] 接受群申请成功: group=$groupId, user=$userId');
    } catch (e) {
      appLog.e('[GroupService] 接受群申请失败: $e');
      rethrow;
    }
  }

  /// 拒绝群申请
  @override
  Future<void> refuseGroupApplication(
    fb.OpenImBridgeClient client, {
    required String groupId,
    required String userId,
    String? handleMsg,
  }) async {
    try {
      await client.refuseGroupApplication(
        groupId: groupId,
        userId: userId,
        handleMsg: handleMsg,
      );
      appLog.i('[GroupService] 拒绝群申请成功: group=$groupId, user=$userId');
    } catch (e) {
      appLog.e('[GroupService] 拒绝群申请失败: $e');
      rethrow;
    }
  }
}
