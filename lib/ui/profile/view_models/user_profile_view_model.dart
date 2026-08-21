import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/user_profile.dart';
import '../../../core/utils/app_logger.dart';
import '../../../providers/im_providers.dart';
import '../../chat/providers/message_revision_provider.dart';
import '../../chat/providers/message_service_provider.dart';
import 'user_avatar_store.dart';

/// 用户资料展示状态：服务端资料 + 本地覆盖（头像路径/URL/加载/错误）。
class UserProfileState {
  final UserProfile? profile;
  final String nickname;
  final String alias;
  final String signature;
  final String? localAvatarPath; // 本地头像路径（用于持久化显示）
  final bool isLoading;
  final String? error;

  const UserProfileState({
    this.profile,
    this.nickname = '',
    this.alias = '',
    this.signature = '',
    this.localAvatarPath,
    this.isLoading = false,
    this.error,
  });

  UserProfileState copyWith({
    UserProfile? profile,
    String? nickname,
    String? alias,
    String? signature,
    String? localAvatarPath,
    bool clearLocalAvatarPath = false,
    bool? isLoading,
    String? error,
  }) {
    return UserProfileState(
      profile: profile ?? this.profile,
      nickname: nickname ?? this.nickname,
      alias: alias ?? this.alias,
      signature: signature ?? this.signature,
      localAvatarPath: clearLocalAvatarPath
          ? null
          : (localAvatarPath ?? this.localAvatarPath),
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  /// 由服务端资料构造展示状态；本地头像路径作为覆盖值叠加。
  factory UserProfileState.fromServerProfile(
    UserProfile profile, {
    String? localAvatarPath,
  }) {
    final exData = parseEx(profile.remark);
    return UserProfileState(
      profile: profile,
      nickname: profile.nickname.trim(),
      alias: exData['alias'] ?? '',
      signature: exData['signature'] ?? '',
      localAvatarPath: localAvatarPath,
      isLoading: false,
      error: null,
    );
  }

  /// 从 ex 字段解析别名和签名
  static Map<String, String> parseEx(String? rawEx) {
    if (rawEx == null || rawEx.trim().isEmpty) {
      return {'alias': '', 'signature': ''};
    }
    try {
      final decoded = jsonDecode(rawEx);
      if (decoded is Map<String, dynamic>) {
        return {
          'alias': (decoded['alias'] as String?)?.trim() ?? '',
          'signature': (decoded['signature'] as String?)?.trim() ?? '',
        };
      }
    } catch (_) {}
    return {'alias': '', 'signature': ''};
  }

  /// 构建 ex 字段
  static String buildEx({
    required String currentEx,
    String? alias,
    String? signature,
  }) {
    Map<String, dynamic> map;
    try {
      final decoded = jsonDecode(currentEx);
      map = decoded is Map<String, dynamic>
          ? Map<String, dynamic>.from(decoded)
          : <String, dynamic>{};
    } catch (_) {
      map = <String, dynamic>{};
    }
    if (alias != null) map['alias'] = alias;
    if (signature != null) map['signature'] = signature;
    return jsonEncode(map);
  }
}

/// 用户资料的本地编辑状态：头像覆盖、加载与错误。
/// 服务端资料由 [loginUserProfileProvider] 单一来源派生，避免 listen 复制。
class UserProfileLocalState {
  const UserProfileLocalState({
    this.localAvatarPath,
    this.localAvatarUrl,
    this.isLoading = false,
    this.error,
  });

  final String? localAvatarPath;
  final String? localAvatarUrl;
  final bool isLoading;
  final String? error;

  UserProfileLocalState copyWith({
    String? localAvatarPath,
    String? localAvatarUrl,
    bool clearLocalAvatarPath = false,
    bool clearLocalAvatarUrl = false,
    bool? isLoading,
    String? error,
  }) {
    return UserProfileLocalState(
      localAvatarPath: clearLocalAvatarPath
          ? null
          : (localAvatarPath ?? this.localAvatarPath),
      localAvatarUrl: clearLocalAvatarUrl
          ? null
          : (localAvatarUrl ?? this.localAvatarUrl),
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// 用户资料 Notifier：只管理本地编辑状态，不再复制全局登录资料。
class UserProfileNotifier extends Notifier<UserProfileLocalState> {
  final UserAvatarStore _avatarStore = UserAvatarStore();

  @override
  UserProfileLocalState build() {
    Future.microtask(_loadLocalAvatarPathSync);
    return const UserProfileLocalState();
  }

  UserProfile? get _serverProfile => ref.read(loginUserProfileProvider);

  /// 同步加载本地头像路径（使用 cachedValue 避免重复读取）
  void _loadLocalAvatarPathSync() {
    if (state.localAvatarPath != null && state.localAvatarPath!.isNotEmpty) {
      return;
    }
    loadLocalAvatarPath();
  }

  /// 从本地存储加载头像路径并更新状态。
  Future<void> loadLocalAvatarPath() async {
    final path = await _avatarStore.loadLocalAvatarPath();
    if (path != null && path.isNotEmpty) {
      state = state.copyWith(localAvatarPath: path);
    }
  }

  /// 获取用于显示的头像 URL：本地路径 > 本地覆盖 URL > 服务器 URL。
  String? getDisplayAvatarUrl() => _avatarStore.resolveDisplayUrl(
    localAvatarPath: state.localAvatarPath,
    faceUrl: state.localAvatarUrl ?? _serverProfile?.faceUrl,
  );

  /// 获取指定用户资料（从 MessageService 缓存）
  UserProfile? getUserProfile(String userId) =>
      ref.read(messageServiceProvider.notifier).getUserProfile(userId);

  /// 加载当前登录用户资料：保证服务端资料存在并刷新本地头像路径。
  Future<void> loadProfile() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final localPath = await _avatarStore.loadLocalAvatarPath();
      if (localPath != null && localPath.isNotEmpty) {
        state = state.copyWith(localAvatarPath: localPath);
      }

      final messageService = ref.read(messageServiceProvider);
      if (messageService.loginUserProfile == null) {
        final refreshed = await ref
            .read(messageServiceProvider.notifier)
            .refreshLoginUserProfile();
        if (refreshed == null) {
          state = state.copyWith(isLoading: false, error: '加载用户资料失败');
          return;
        }
      }
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '加载用户资料失败: $e');
    }
  }

  /// 更新昵称
  Future<bool> updateNickname(String nickname) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final updated = await ref
          .read(messageServiceProvider.notifier)
          .updateLoginUserProfile(nickname: nickname);
      if (updated != null) {
        state = state.copyWith(isLoading: false);
        return true;
      }
      state = state.copyWith(isLoading: false, error: '更新昵称失败');
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '更新昵称失败: $e');
      return false;
    }
  }

  /// 更新别名
  Future<bool> updateAlias(String alias) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final currentEx = _serverProfile?.remark ?? '';
      final newEx = UserProfileState.buildEx(
        currentEx: currentEx,
        alias: alias,
      );
      final updated = await ref
          .read(messageServiceProvider.notifier)
          .updateLoginUserProfile(ex: newEx);
      if (updated != null) {
        state = state.copyWith(isLoading: false);
        return true;
      }
      state = state.copyWith(isLoading: false, error: '更新别名失败');
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '更新别名失败: $e');
      return false;
    }
  }

  /// 更新个性签名
  Future<bool> updateSignature(String signature) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final currentEx = _serverProfile?.remark ?? '';
      final newEx = UserProfileState.buildEx(
        currentEx: currentEx,
        signature: signature,
      );
      final updated = await ref
          .read(messageServiceProvider.notifier)
          .updateLoginUserProfile(ex: newEx);
      if (updated != null) {
        state = state.copyWith(isLoading: false);
        return true;
      }
      state = state.copyWith(isLoading: false, error: '更新个性签名失败');
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '更新个性签名失败: $e');
      return false;
    }
  }

  /// 更新头像
  Future<bool> updateAvatar(String imageUrl) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final updated = await ref
          .read(messageServiceProvider.notifier)
          .updateLoginUserProfile(faceUrl: imageUrl);
      if (updated != null) {
        final serverUrlUpdated =
            updated.faceUrl.isNotEmpty &&
            _avatarStore.isValidAvatarUrl(updated.faceUrl) &&
            (updated.faceUrl.contains(imageUrl) ||
                imageUrl.contains(
                  _avatarStore.extractFileName(updated.faceUrl),
                ));

        appLog.i(
          '[UserProfile] updateAvatar: 发送的URL=$imageUrl, 服务器返回的URL=${updated.faceUrl}, 服务器已更新=$serverUrlUpdated',
        );

        // 给头像 URL 添加时间戳参数，绕过缓存确保立即生效
        final cacheBustedUrl = _avatarStore.addCacheBuster(updated.faceUrl);
        state = state.copyWith(
          isLoading: false,
          localAvatarUrl: cacheBustedUrl,
        );

        if (serverUrlUpdated) {
          appLog.i('[UserProfile] updateAvatar: 服务器已确认更新，保留本地路径作为兜底');
        } else {
          appLog.w('[UserProfile] updateAvatar: 服务器未确认更新或 URL 无效，保留本地路径');
        }

        return serverUrlUpdated;
      }
      state = state.copyWith(isLoading: false, error: '更新头像失败');
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '更新头像失败: $e');
      return false;
    }
  }

  /// 上传头像文件，返回服务器 URL
  Future<String> uploadAvatar(String filePath) {
    final service = ref.read(mediaUploadServiceProvider);
    return service.uploadFile(filePath: filePath, fileName: 'avatar.jpg');
  }

  /// 设置本地头像路径（用于临时显示和持久化）
  Future<String?> setLocalAvatarPath(String path) async {
    appLog.i('[UserProfile] setLocalAvatarPath 被调用，path=$path');
    final savedPath = await _avatarStore.persistLocalAvatar(path);
    await _avatarStore.saveLocalAvatarPath(savedPath);
    state = state.copyWith(localAvatarPath: savedPath);
    appLog.i('[UserProfile] setLocalAvatarPath 完成，savedPath=$savedPath');
    return savedPath;
  }

  /// 清除本地头像路径
  Future<void> clearLocalAvatarPath() async {
    appLog.i('[UserProfile] clearLocalAvatarPath 被调用');
    await _avatarStore.saveLocalAvatarPath(null);
    state = state.copyWith(clearLocalAvatarPath: true);
  }

  /// 清除错误
  void clearError() {
    state = state.copyWith(error: null);
  }
}
