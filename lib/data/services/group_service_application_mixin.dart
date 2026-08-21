import '../../generated/rust/ffi/client.dart' as fb;
import '../../generated/rust/http/group.dart' show GroupApplyInfo;
import '../../core/utils/app_logger.dart';

mixin GroupApplicationMixin on Object {
  // ==================== 群申请管理 ====================

  /// 获取所有群申请列表
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
