import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_rust_demo/src/rust/domain/model/friend.dart' show FriendInfo;
import 'package:flutter_rust_demo/src/rust/core/friend/service.dart' show FriendApplyInfo;
import 'package:flutter_rust_demo/src/rust/api/client.dart' as fb;
import 'package:flutter_rust_demo/src/rust/core/friend/service.dart'
    show SearchFriendItem;
import 'package:flutter_rust_demo/utils/app_logger.dart';

import 'message_service_provider.dart';

// ==================== 好友列表 ====================

/// 好友列表状态
class FriendListState {
  final List<FriendInfo> friends;
  final bool isLoading;
  final String? error;

  const FriendListState({
    this.friends = const [],
    this.isLoading = false,
    this.error,
  });

  FriendListState copyWith({
    List<FriendInfo>? friends,
    bool? isLoading,
    String? error,
  }) {
    return FriendListState(
      friends: friends ?? this.friends,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  /// 好友总数
  int get friendCount => friends.length;
}

/// 好友列表 Notifier
class FriendListNotifier extends StateNotifier<FriendListState> {
  FriendListNotifier(this._ref) : super(const FriendListState());

  final Ref _ref;

  fb.OpenImBridgeClient? get _client =>
      _ref.read(messageServiceProvider.notifier).client;

  /// 加载好友列表
  Future<void> loadFriends() async {
    final client = _client;
    if (client == null) {
      state = state.copyWith(error: '客户端未初始化');
      return;
    }

    state = state.copyWith(isLoading: true, error: null);
    try {
      final friends = await client.getFriendList();
      state = state.copyWith(friends: friends, isLoading: false);
      appLog.i('[FriendProvider] 好友列表加载完成: ${friends.length} 人');
    } catch (e) {
      appLog.e('[FriendProvider] 加载好友列表失败: $e');
      state = state.copyWith(isLoading: false, error: '加载好友列表失败: $e');
    }
  }

  /// 搜索好友
  Future<void> searchFriends(String keyword) async {
    final client = _client;
    if (client == null) return;

    if (keyword.trim().isEmpty) {
      await loadFriends();
      return;
    }

    state = state.copyWith(isLoading: true, error: null);
    try {
      final results = await client.searchFriends(keyword: keyword);
      // SearchFriendItem -> FriendInfo 简单映射
      final friends = results
          .map((item) => FriendInfo(
                userId: item.friendUserId,
                nickname: item.nickname,
                faceUrl: item.faceUrl,
                gender: 0,
                remark: item.remark,
                createTime: item.createTime,
                addSource: '',
                ex: item.ex,
              ))
          .toList();
      state = state.copyWith(friends: friends, isLoading: false);
      appLog.i('[FriendProvider] 搜索好友完成: ${friends.length} 人');
    } catch (e) {
      appLog.e('[FriendProvider] 搜索好友失败: $e');
      state = state.copyWith(isLoading: false, error: '搜索好友失败: $e');
    }
  }

  /// 刷新好友列表
  Future<void> refreshFriends() async {
    await loadFriends();
  }
}

/// 好友列表 Provider
final friendListProvider =
    StateNotifierProvider<FriendListNotifier, FriendListState>((ref) {
  return FriendListNotifier(ref);
});

// ==================== 好友申请 ====================

/// 好友申请状态
class FriendApplyState {
  final List<FriendApplyInfo> received;
  final List<FriendApplyInfo> sent;
  final bool isLoading;
  final String? error;

  const FriendApplyState({
    this.received = const [],
    this.sent = const [],
    this.isLoading = false,
    this.error,
  });

  FriendApplyState copyWith({
    List<FriendApplyInfo>? received,
    List<FriendApplyInfo>? sent,
    bool? isLoading,
    String? error,
  }) {
    return FriendApplyState(
      received: received ?? this.received,
      sent: sent ?? this.sent,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  /// 未处理的申请数量
  int get unhandledCount => received.length;
}

/// 好友申请 Notifier
class FriendApplyNotifier extends StateNotifier<FriendApplyState> {
  FriendApplyNotifier(this._ref) : super(const FriendApplyState());

  final Ref _ref;

  fb.OpenImBridgeClient? get _client =>
      _ref.read(messageServiceProvider.notifier).client;

  /// 加载好友申请列表
  Future<void> loadApplications() async {
    final client = _client;
    if (client == null) {
      state = state.copyWith(error: '客户端未初始化');
      return;
    }

    state = state.copyWith(isLoading: true, error: null);
    try {
      final received = await client.getFriendApplyList();
      final sent = await client.getFriendApplyListAsApplicant();
      state = state.copyWith(
        received: received,
        sent: sent,
        isLoading: false,
      );
      appLog.i(
          '[FriendProvider] 好友申请加载完成: 收到=${received.length}, 发出=${sent.length}');
    } catch (e) {
      appLog.e('[FriendProvider] 加载好友申请失败: $e');
      state = state.copyWith(isLoading: false, error: '加载好友申请失败: $e');
    }
  }

  /// 接受好友申请
  Future<void> acceptApplication(String userId, {String? handleMsg}) async {
    final client = _client;
    if (client == null) return;

    try {
      await client.acceptFriendApplication(
        userId: userId,
        handleMsg: handleMsg,
      );
      appLog.i('[FriendProvider] 已接受好友申请: userId=$userId');
      // 刷新列表
      await loadApplications();
    } catch (e) {
      appLog.e('[FriendProvider] 接受好友申请失败: $e');
      state = state.copyWith(error: '接受好友申请失败: $e');
    }
  }

  /// 拒绝好友申请
  Future<void> refuseApplication(String userId, {String? handleMsg}) async {
    final client = _client;
    if (client == null) return;

    try {
      await client.refuseFriendApplication(
        userId: userId,
        handleMsg: handleMsg,
      );
      appLog.i('[FriendProvider] 已拒绝好友申请: userId=$userId');
      // 刷新列表
      await loadApplications();
    } catch (e) {
      appLog.e('[FriendProvider] 拒绝好友申请失败: $e');
      state = state.copyWith(error: '拒绝好友申请失败: $e');
    }
  }
}

/// 好友申请 Provider
final friendApplyProvider =
    StateNotifierProvider<FriendApplyNotifier, FriendApplyState>((ref) {
  return FriendApplyNotifier(ref);
});

// ==================== 好友搜索 ====================

/// 好友搜索状态
class FriendSearchState {
  final List<SearchFriendItem> results;
  final bool isLoading;
  final String? error;

  const FriendSearchState({
    this.results = const [],
    this.isLoading = false,
    this.error,
  });

  FriendSearchState copyWith({
    List<SearchFriendItem>? results,
    bool? isLoading,
    String? error,
  }) {
    return FriendSearchState(
      results: results ?? this.results,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// 好友搜索 Notifier
class FriendSearchNotifier extends StateNotifier<FriendSearchState> {
  FriendSearchNotifier(this._ref) : super(const FriendSearchState());

  final Ref _ref;

  fb.OpenImBridgeClient? get _client =>
      _ref.read(messageServiceProvider.notifier).client;

  /// 搜索好友
  Future<void> search(String keyword) async {
    final client = _client;
    if (client == null) {
      state = state.copyWith(error: '客户端未初始化');
      return;
    }

    if (keyword.trim().isEmpty) {
      state = const FriendSearchState();
      return;
    }

    state = state.copyWith(isLoading: true, error: null);
    try {
      final results = await client.searchFriends(keyword: keyword);
      state = state.copyWith(results: results, isLoading: false);
      appLog.i('[FriendProvider] 搜索好友完成: ${results.length} 条');
    } catch (e) {
      appLog.e('[FriendProvider] 搜索好友失败: $e');
      state = state.copyWith(isLoading: false, error: '搜索好友失败: $e');
    }
  }

  /// 清空搜索结果
  void clear() {
    state = const FriendSearchState();
  }
}

/// 好友搜索 Provider
final friendSearchProvider =
    StateNotifierProvider<FriendSearchNotifier, FriendSearchState>((ref) {
  return FriendSearchNotifier(ref);
});

// ==================== 黑名单 ====================

/// 黑名单状态
class BlackListState {
  final List<String> userIds;
  final bool isLoading;
  final String? error;

  const BlackListState({
    this.userIds = const [],
    this.isLoading = false,
    this.error,
  });

  BlackListState copyWith({
    List<String>? userIds,
    bool? isLoading,
    String? error,
  }) {
    return BlackListState(
      userIds: userIds ?? this.userIds,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  /// 黑名单人数
  int get count => userIds.length;
}

/// 黑名单 Notifier
class BlackListNotifier extends StateNotifier<BlackListState> {
  BlackListNotifier(this._ref) : super(const BlackListState());

  final Ref _ref;

  fb.OpenImBridgeClient? get _client =>
      _ref.read(messageServiceProvider.notifier).client;

  /// 加载黑名单
  Future<void> load() async {
    final client = _client;
    if (client == null) {
      state = state.copyWith(error: '客户端未初始化');
      return;
    }

    state = state.copyWith(isLoading: true, error: null);
    try {
      final userIds = await client.getBlackList();
      state = state.copyWith(userIds: userIds, isLoading: false);
      appLog.i('[FriendProvider] 黑名单加载完成: ${userIds.length} 人');
    } catch (e) {
      appLog.e('[FriendProvider] 加载黑名单失败: $e');
      state = state.copyWith(isLoading: false, error: '加载黑名单失败: $e');
    }
  }

  /// 加入黑名单
  Future<void> addBlack(String userId) async {
    final client = _client;
    if (client == null) return;

    try {
      await client.addBlack(userId: userId);
      appLog.i('[FriendProvider] 已加入黑名单: userId=$userId');
      await load();
    } catch (e) {
      appLog.e('[FriendProvider] 加入黑名单失败: $e');
      state = state.copyWith(error: '加入黑名单失败: $e');
    }
  }

  /// 移出黑名单
  Future<void> removeBlack(String userId) async {
    final client = _client;
    if (client == null) return;

    try {
      await client.removeBlack(userId: userId);
      appLog.i('[FriendProvider] 已移出黑名单: userId=$userId');
      await load();
    } catch (e) {
      appLog.e('[FriendProvider] 移出黑名单失败: $e');
      state = state.copyWith(error: '移出黑名单失败: $e');
    }
  }
}

/// 黑名单 Provider
final blackListProvider =
    StateNotifierProvider<BlackListNotifier, BlackListState>((ref) {
  return BlackListNotifier(ref);
});
