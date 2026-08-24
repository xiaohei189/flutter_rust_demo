import 'package:flutter_rust_demo/generated/rust/ffi/client.dart' as fb;
import 'package:flutter_rust_demo/generated/rust/http/friend.dart'
    show SearchFriendItem, CheckFriendResult;
import 'package:flutter_rust_demo/generated/rust/model/friend.dart'
    show FriendInfo;
import 'package:flutter_rust_demo/generated/rust/http/friend.dart'
    show FriendApplyInfo;
import 'friend_service_parts.dart';

abstract class FriendService {

  Future<void> addFriend(
    fb.OpenImBridgeClient client, {
    required String userId,
    required String reqMsg,
  });

  Future<void> acceptFriendApplication(
    fb.OpenImBridgeClient client, {
    required String userId,
    String? handleMsg,
  });

  Future<void> refuseFriendApplication(
    fb.OpenImBridgeClient client, {
    required String userId,
    String? handleMsg,
  });

  Future<List<FriendApplyInfo>> getFriendApplyList(
    fb.OpenImBridgeClient client,
  );

  Future<List<FriendApplyInfo>> getFriendApplyListAsApplicant(
    fb.OpenImBridgeClient client,
  );

  Future<int> getFriendApplicationUnhandledCount(fb.OpenImBridgeClient client);

  Future<List<FriendInfo>> getFriendList(
    fb.OpenImBridgeClient client, {
    bool filterBlack = true,
  });

  Future<List<FriendInfo>> getFriendListPage(
    fb.OpenImBridgeClient client, {
    required int offset,
    required int count,
    bool filterBlack = true,
  });

  Future<List<String>> getFriendIdList(fb.OpenImBridgeClient client);

  Future<List<FriendInfo>> getSpecifiedFriendsInfo(
    fb.OpenImBridgeClient client, {
    required List<String> friendUserIds,
    bool filterBlack = true,
  });

  Future<bool> isFriend(fb.OpenImBridgeClient client, {required String userId});

  Future<List<CheckFriendResult>> checkFriend(
    fb.OpenImBridgeClient client, {
    required List<String> userIds,
  });

  Future<List<SearchFriendItem>> searchFriends(
    fb.OpenImBridgeClient client, {
    required String keyword,
  });

  Future<void> deleteFriend(
    fb.OpenImBridgeClient client, {
    required String userId,
  });

  Future<void> updateFriends(
    fb.OpenImBridgeClient client, {
    required List<String> friendUserIds,
    bool? isPinned,
    String? remark,
    String? ex,
  });

  Future<void> addBlack(fb.OpenImBridgeClient client, {required String userId});

  Future<void> removeBlack(
    fb.OpenImBridgeClient client, {
    required String userId,
  });

  Future<List<String>> getBlackList(fb.OpenImBridgeClient client);

  Future<bool> isInBlacklist(
    fb.OpenImBridgeClient client, {
    required String userId,
  });
}

/// 好友服务 - 封装好友相关 FFI 调用
///
/// 职责：
/// 1. 好友申请（添加/接受/拒绝/查询）
/// 2. 好友列表（获取/分页/搜索）
/// 3. 黑名单管理
/// 4. 好友信息更新

class FriendServiceImpl
    with FriendApplicationsMixin, FriendListMixin, FriendBlacklistMixin
    implements FriendService {

  FriendServiceImpl();
}
