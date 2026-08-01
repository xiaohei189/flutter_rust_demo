import 'package:flutter_rust_demo/src/rust/api/client.dart' as fb;
import 'package:flutter_rust_demo/src/rust/core/friend/manager.dart'
    show SearchFriendItem, CheckFriendResult;
import 'package:flutter_rust_demo/src/rust/domain/model/friend.dart'
    show FriendInfo;
import 'package:flutter_rust_demo/src/rust/core/friend/manager.dart'
    show FriendApplyInfo;
import 'package:flutter_rust_demo/utils/app_logger.dart';

/// 好友服务 - 封装好友相关 FFI 调用
///
/// 职责：
/// 1. 好友申请（添加/接受/拒绝/查询）
/// 2. 好友列表（获取/分页/搜索）
/// 3. 黑名单管理
/// 4. 好友信息更新
class FriendService {
  static final FriendService _instance = FriendService._internal();

  /// 全局单例实例
  static FriendService get instance => _instance;

  FriendService._internal();

  // ==================== 好友申请 ====================

  /// 添加好友
  Future<void> addFriend(
    fb.OpenImBridgeClient client, {
    required String userId,
    required String reqMsg,
  }) async {
    try {
      appLog.i('[FriendService] 添加好友: userId=$userId');
      await client.addFriend(userId: userId, reqMsg: reqMsg);
      appLog.i('[FriendService] 添加好友请求已发送');
    } catch (e) {
      appLog.e('[FriendService] 添加好友失败: $e');
      rethrow;
    }
  }

  /// 接受好友申请
  Future<void> acceptFriendApplication(
    fb.OpenImBridgeClient client, {
    required String userId,
    String? handleMsg,
  }) async {
    try {
      appLog.i('[FriendService] 接受好友申请: userId=$userId');
      await client.acceptFriendApplication(
        userId: userId,
        handleMsg: handleMsg,
      );
      appLog.i('[FriendService] 已接受好友申请');
    } catch (e) {
      appLog.e('[FriendService] 接受好友申请失败: $e');
      rethrow;
    }
  }

  /// 拒绝好友申请
  Future<void> refuseFriendApplication(
    fb.OpenImBridgeClient client, {
    required String userId,
    String? handleMsg,
  }) async {
    try {
      appLog.i('[FriendService] 拒绝好友申请: userId=$userId');
      await client.refuseFriendApplication(
        userId: userId,
        handleMsg: handleMsg,
      );
      appLog.i('[FriendService] 已拒绝好友申请');
    } catch (e) {
      appLog.e('[FriendService] 拒绝好友申请失败: $e');
      rethrow;
    }
  }

  /// 获取收到的好友申请列表
  Future<List<FriendApplyInfo>> getFriendApplyList(
    fb.OpenImBridgeClient client,
  ) async {
    try {
      final list = await client.getFriendApplyList();
      appLog.i('[FriendService] 获取好友申请列表: ${list.length} 条');
      return list;
    } catch (e) {
      appLog.e('[FriendService] 获取好友申请列表失败: $e');
      rethrow;
    }
  }

  /// 获取我发出的好友申请列表
  Future<List<FriendApplyInfo>> getFriendApplyListAsApplicant(
    fb.OpenImBridgeClient client,
  ) async {
    try {
      final list = await client.getFriendApplyListAsApplicant();
      appLog.i('[FriendService] 获取我发出的好友申请: ${list.length} 条');
      return list;
    } catch (e) {
      appLog.e('[FriendService] 获取我发出的好友申请失败: $e');
      rethrow;
    }
  }

  /// 获取未处理的好友申请数量
  Future<int> getFriendApplicationUnhandledCount(
    fb.OpenImBridgeClient client,
  ) async {
    try {
      final count = await client.getFriendApplicationUnhandledCount();
      appLog.i('[FriendService] 未处理好友申请数: $count');
      return count;
    } catch (e) {
      appLog.e('[FriendService] 获取未处理好友申请数失败: $e');
      rethrow;
    }
  }

  // ==================== 好友列表 ====================

  /// 获取好友列表
  Future<List<FriendInfo>> getFriendList(
    fb.OpenImBridgeClient client, {
    bool filterBlack = true,
  }) async {
    try {
      final list = await client.getFriendList();
      appLog.i('[FriendService] 获取好友列表: ${list.length} 人');
      return list;
    } catch (e) {
      appLog.e('[FriendService] 获取好友列表失败: $e');
      rethrow;
    }
  }

  /// 分页获取好友列表
  Future<List<FriendInfo>> getFriendListPage(
    fb.OpenImBridgeClient client, {
    required int offset,
    required int count,
    bool filterBlack = true,
  }) async {
    try {
      final list = await client.getFriendListPage(
        offset: offset,
        count: count,
        filterBlack: filterBlack,
      );
      appLog.i(
          '[FriendService] 分页获取好友列表: offset=$offset, count=$count, 结果=${list.length} 人');
      return list;
    } catch (e) {
      appLog.e('[FriendService] 分页获取好友列表失败: $e');
      rethrow;
    }
  }

  /// 获取好友 ID 列表
  Future<List<String>> getFriendIdList(
    fb.OpenImBridgeClient client,
  ) async {
    try {
      final list = await client.getFriendIdList();
      appLog.i('[FriendService] 获取好友 ID 列表: ${list.length} 个');
      return list;
    } catch (e) {
      appLog.e('[FriendService] 获取好友 ID 列表失败: $e');
      rethrow;
    }
  }

  /// 获取指定好友信息
  Future<List<FriendInfo>> getSpecifiedFriendsInfo(
    fb.OpenImBridgeClient client, {
    required List<String> friendUserIds,
    bool filterBlack = true,
  }) async {
    try {
      final list = await client.getSpecifiedFriendsInfo(
        friendUserIds: friendUserIds,
        filterBlack: filterBlack,
      );
      appLog.i(
          '[FriendService] 获取指定好友信息: 请求=${friendUserIds.length} 人, 返回=${list.length} 人');
      return list;
    } catch (e) {
      appLog.e('[FriendService] 获取指定好友信息失败: $e');
      rethrow;
    }
  }

  /// 检查是否是好友
  Future<bool> isFriend(
    fb.OpenImBridgeClient client, {
    required String userId,
  }) async {
    try {
      final result = await client.isFriend(userId: userId);
      return result;
    } catch (e) {
      appLog.e('[FriendService] 检查好友关系失败: $e');
      rethrow;
    }
  }

  /// 批量检查好友关系
  Future<List<CheckFriendResult>> checkFriend(
    fb.OpenImBridgeClient client, {
    required List<String> userIds,
  }) async {
    try {
      final results = await client.checkFriend(userIds: userIds);
      appLog.i(
          '[FriendService] 批量检查好友关系: ${userIds.length} 人, 结果=${results.length} 条');
      return results;
    } catch (e) {
      appLog.e('[FriendService] 批量检查好友关系失败: $e');
      rethrow;
    }
  }

  /// 搜索好友（本地 SQLite 模糊查询）
  Future<List<SearchFriendItem>> searchFriends(
    fb.OpenImBridgeClient client, {
    required String keyword,
  }) async {
    try {
      final results = await client.searchFriends(keyword: keyword);
      appLog.i('[FriendService] 搜索好友: keyword=$keyword, 结果=${results.length} 条');
      return results;
    } catch (e) {
      appLog.e('[FriendService] 搜索好友失败: $e');
      rethrow;
    }
  }

  /// 删除好友
  Future<void> deleteFriend(
    fb.OpenImBridgeClient client, {
    required String userId,
  }) async {
    try {
      appLog.i('[FriendService] 删除好友: userId=$userId');
      await client.deleteFriend(userId: userId);
      appLog.i('[FriendService] 已删除好友');
    } catch (e) {
      appLog.e('[FriendService] 删除好友失败: $e');
      rethrow;
    }
  }

  /// 更新好友信息
  Future<void> updateFriends(
    fb.OpenImBridgeClient client, {
    required List<String> friendUserIds,
    bool? isPinned,
    String? remark,
    String? ex,
  }) async {
    try {
      appLog.i('[FriendService] 更新好友信息: userIds=$friendUserIds');
      await client.updateFriends(
        friendUserIds: friendUserIds,
        isPinned: isPinned,
        remark: remark,
        ex: ex,
      );
      appLog.i('[FriendService] 好友信息已更新');
    } catch (e) {
      appLog.e('[FriendService] 更新好友信息失败: $e');
      rethrow;
    }
  }

  // ==================== 黑名单 ====================

  /// 加入黑名单
  Future<void> addBlack(
    fb.OpenImBridgeClient client, {
    required String userId,
  }) async {
    try {
      appLog.i('[FriendService] 加入黑名单: userId=$userId');
      await client.addBlack(userId: userId);
      appLog.i('[FriendService] 已加入黑名单');
    } catch (e) {
      appLog.e('[FriendService] 加入黑名单失败: $e');
      rethrow;
    }
  }

  /// 移出黑名单
  Future<void> removeBlack(
    fb.OpenImBridgeClient client, {
    required String userId,
  }) async {
    try {
      appLog.i('[FriendService] 移出黑名单: userId=$userId');
      await client.removeBlack(userId: userId);
      appLog.i('[FriendService] 已移出黑名单');
    } catch (e) {
      appLog.e('[FriendService] 移出黑名单失败: $e');
      rethrow;
    }
  }

  /// 获取黑名单列表
  Future<List<String>> getBlackList(
    fb.OpenImBridgeClient client,
  ) async {
    try {
      final list = await client.getBlackList();
      appLog.i('[FriendService] 获取黑名单: ${list.length} 人');
      return list;
    } catch (e) {
      appLog.e('[FriendService] 获取黑名单失败: $e');
      rethrow;
    }
  }

  /// 检查是否在黑名单中
  Future<bool> isInBlacklist(
    fb.OpenImBridgeClient client, {
    required String userId,
  }) async {
    try {
      final result = await client.isInBlacklist(userId: userId);
      return result;
    } catch (e) {
      appLog.e('[FriendService] 检查黑名单失败: $e');
      rethrow;
    }
  }
}
