import 'dart:async';

import '../src/rust/domain/model/user.dart' show UserInfo;
import '../utils/app_logger.dart';
import 'im_client.dart';

/// 用户服务 - 管理用户资料
///
/// 职责：
/// 1. 获取和缓存用户资料
/// 2. 更新当前登录用户资料
/// 3. 批量预加载用户资料
/// 4. 管理当前登录用户信息
class UserService {
  static final UserService _instance = UserService._internal();

  /// 全局单例实例
  static UserService get instance => _instance;

  // 用户资料缓存
  final Map<String, UserInfo> _profiles = {};

  // 当前登录用户资料
  UserInfo? _loginUserProfile;
  String _currentUserId = '';

  // 流控制器
  final _profilesController = StreamController<Map<String, UserInfo>>.broadcast();
  final _loginUserController = StreamController<UserInfo?>.broadcast();

  bool _isDisposed = false;

  UserService._internal();

  /// 设置当前用户ID
  void setCurrentUserId(String userId) {
    _currentUserId = userId;
  }

  /// 获取当前用户ID
  String get currentUserId => _currentUserId;

  /// 当前登录用户资料
  UserInfo? get loginUserProfile => _loginUserProfile;

  /// 当前登录用户资料流
  Stream<UserInfo?> get loginUserStream => _loginUserController.stream;

  /// 所有用户资料流
  Stream<Map<String, UserInfo>> get profilesStream => _profilesController.stream;

  /// 获取指定用户资料
  UserInfo? getUserProfile(String userId) {
    return _profiles[userId];
  }

  /// 获取多个用户资料
  List<UserInfo> getUserProfiles(List<String> userIds) {
    return userIds
        .map((id) => _profiles[id])
        .where((profile) => profile != null)
        .cast<UserInfo>()
        .toList();
  }

  /// 刷新当前登录用户资料
  Future<UserInfo?> refreshLoginUserProfile() async {
    final client = ImClient.instance.client;
    if (client == null || _currentUserId.isEmpty) {
      appLog.w('[UserService] 客户端为空或用户ID为空');
      return null;
    }

    try {
      appLog.i('[UserService] 刷新当前用户资料: $_currentUserId');
      final list = await client.getUsersInfo(userIds: [_currentUserId]);
      final profile = list.isNotEmpty ? list.first : null;

      if (profile != null) {
        _loginUserProfile = profile;
        _profiles[profile.userId] = profile;
        _notifyLoginUserChanged();
        _notifyProfilesChanged();
        appLog.i('[UserService] 当前用户资料刷新成功');
      }
      return _loginUserProfile;
    } catch (e) {
      appLog.e('[UserService] 刷新当前用户资料失败: $e');
      return null;
    }
  }

  /// 批量预加载用户资料
  Future<void> preloadUserProfiles(List<String> userIds) async {
    final client = ImClient.instance.client;
    if (client == null || userIds.isEmpty) return;

    // 过滤掉已缓存的
    final uncachedIds = userIds
        .where((id) => id.isNotEmpty && !_profiles.containsKey(id))
        .toSet()
        .toList();

    if (uncachedIds.isEmpty) return;

    try {
      appLog.i('[UserService] 批量加载用户资料: ${uncachedIds.length} 个');
      final list = await client.getUsersInfo(userIds: uncachedIds);

      for (final p in list) {
        _profiles[p.userId] = p;
      }
      _notifyProfilesChanged();
      appLog.i('[UserService] 批量加载用户资料完成');
    } catch (e) {
      appLog.w('[UserService] 批量加载用户资料失败: $e');
    }
  }

  /// 获取单个用户资料（优先从缓存获取）
  Future<UserInfo?> fetchUserProfile(String userId) async {
    // 先检查缓存
    if (_profiles.containsKey(userId)) {
      return _profiles[userId];
    }

    // 从服务器获取
    final client = ImClient.instance.client;
    if (client == null) return null;

    try {
      final list = await client.getUsersInfo(userIds: [userId]);
      if (list.isNotEmpty) {
        final profile = list.first;
        _profiles[userId] = profile;
        _notifyProfilesChanged();
        return profile;
      }
    } catch (e) {
      appLog.e('[UserService] 获取用户资料失败: $e');
    }
    return null;
  }

  /// 更新当前登录用户资料
  Future<UserInfo?> updateLoginUserProfile({
    String? nickname,
    String? faceUrl,
    String? ex,
    int? globalRecvMsgOpt,
  }) async {
    final client = ImClient.instance.client;
    if (client == null) {
      appLog.w('[UserService] 客户端为空');
      return null;
    }

    try {
      appLog.i('[UserService] 更新当前用户资料');

      // 调用 Rust API 更新
      await client.updateUserProfile(
        nickname: nickname,
        faceUrl: faceUrl,
        ex: ex,
      );

      // 更新成功后重新获取
      return await refreshLoginUserProfile();
    } catch (e) {
      appLog.e('[UserService] 更新当前用户资料失败: $e');
      return null;
    }
  }

  /// 清除缓存
  void clearCache() {
    _profiles.clear();
    _loginUserProfile = null;
    _notifyProfilesChanged();
    _notifyLoginUserChanged();
  }

  /// 通知用户资料变化
  void _notifyProfilesChanged() {
    if (!_isDisposed && !_profilesController.isClosed) {
      _profilesController.add(Map.unmodifiable(_profiles));
    }
  }

  /// 通知当前登录用户变化
  void _notifyLoginUserChanged() {
    if (!_isDisposed && !_loginUserController.isClosed) {
      _loginUserController.add(_loginUserProfile);
    }
  }

  /// 重置状态
  void reset() {
    _profiles.clear();
    _loginUserProfile = null;
    _currentUserId = '';
  }

  /// 释放资源
  void dispose() {
    _isDisposed = true;
    reset();
    _profilesController.close();
    _loginUserController.close();
  }
}
