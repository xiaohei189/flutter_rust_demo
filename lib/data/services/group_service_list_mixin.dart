import '../../generated/rust/ffi/client.dart' as fb;
import '../../generated/rust/model/group.dart' show GroupInfo;
import '../../core/utils/app_logger.dart';

mixin GroupListMixin on Object {
  // ==================== 群组列表 ====================

  /// 获取所有已加入的群组列表
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
}

/// GroupInfoMixin
