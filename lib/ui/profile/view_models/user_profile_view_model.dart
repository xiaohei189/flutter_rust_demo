import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../domain/models/user_profile.dart';

import '../../../providers/im_providers.dart';
import '../../../core/utils/app_logger.dart';
import '../../chat/providers/message_service_provider.dart';

/// 用户资料状态
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

/// SharedPreferences key for local avatar
const _kLocalAvatarPathKey = 'user_local_avatar_path';

/// 用户资料 Notifier
class UserProfileNotifier extends Notifier<UserProfileState> {
  @override
  UserProfileState build() {
    final profile = ref.watch(
      messageServiceProvider.select((s) => s.loginUserProfile),
    );
    _applyLoginProfile(profile);
    Future.microtask(_loadLocalAvatarPathSync);
    return state;
  }

  void _applyLoginProfile(UserProfile? profile) {
    if (profile == null) return;
    final current = state.profile;
    if (current?.userId == profile.userId &&
        current?.nickname == profile.nickname &&
        current?.faceUrl == profile.faceUrl) {
      return;
    }

    final exData = UserProfileState.parseEx(profile.remark);
    appLog.i(
      '[UserProfile] 登录资料更新: faceUrl=${profile.faceUrl}, 当前 localAvatarPath=${state.localAvatarPath}',
    );
    // 已有本地头像路径时保留，避免覆盖本地预览
    state = state.copyWith(
      profile: profile,
      nickname: profile.nickname.trim(),
      alias: exData['alias'] ?? '',
      signature: exData['signature'] ?? '',
      localAvatarPath: state.localAvatarPath,
      isLoading: false,
      error: null,
    );
  }

  /// 同步加载本地头像路径（使用 cachedValue 避免重复读取）
  void _loadLocalAvatarPathSync() {
    // 如果已经有值，不再重复加载
    if (state.localAvatarPath != null && state.localAvatarPath!.isNotEmpty) {
      return;
    }
    // 异步加载，但触发后会更新 state
    // 监听器会立即触发（fireImmediately），此时 state.localAvatarPath 可能还是 null
    // 这是正常的，因为稍后 loadLocalAvatarPath 完成时会更新 state
    loadLocalAvatarPath();
  }

  /// 从 SharedPreferences 加载本地头像路径
  Future<void> loadLocalAvatarPath() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final path = prefs.getString(_kLocalAvatarPathKey);
      if (path != null && path.isNotEmpty) {
        state = state.copyWith(localAvatarPath: path);
      }
    } catch (e) {
      appLog.e('[UserProfile] loadLocalAvatarPath 失败: $e');
    }
  }

  /// 保存本地头像路径到 SharedPreferences
  Future<void> _saveLocalAvatarPath(String? path) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (path != null) {
        await prefs.setString(_kLocalAvatarPathKey, path);
        appLog.i('[UserProfile] _saveLocalAvatarPath: 已保存 path=$path');
      } else {
        await prefs.remove(_kLocalAvatarPathKey);
        appLog.i('[UserProfile] _saveLocalAvatarPath: 已清除路径');
      }
    } catch (e) {
      appLog.e('[UserProfile] _saveLocalAvatarPath 失败: $e');
    }
  }

  /// 检查 URL 是否为有效的头像 URL（不是模拟 URL）
  bool _isValidAvatarUrl(String? url) {
    if (url == null || url.isEmpty) {
      return false;
    }
    // 排除模拟 URL
    if (url.contains('example.com')) {
      return false;
    }
    // 有效的 HTTP/HTTPS URL（本地开发和远程服务器都允许）
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return true;
    }
    // 排除本地文件系统路径
    if (url.contains(':\\') || url.startsWith('/')) {
      return false;
    }
    return false;
  }

  /// 获取用于显示的头像 URL
  /// 优先级：本地路径 > 服务器 URL（如果有效）
  String? getDisplayAvatarUrl() {
    // 如果有本地路径，优先使用
    if (state.localAvatarPath != null &&
        state.localAvatarPath!.isNotEmpty &&
        File(state.localAvatarPath!).existsSync()) {
      return state.localAvatarPath;
    }
    // 如果服务器 URL 有效，使用服务器 URL
    if (_isValidAvatarUrl(state.profile?.faceUrl)) {
      return state.profile?.faceUrl;
    }
    return null;
  }

  /// 获取指定用户资料（从 MessageService 缓存）
  UserProfile? getUserProfile(String userId) {
    // 如果是当前登录用户，直接返回
    if (state.profile?.userId == userId) {
      return state.profile;
    }
    final raw = ref
        .read(messageServiceProvider.notifier)
        .getUserProfile(userId);
    return raw;
  }

  UserProfile? _toUserProfile(UserProfile? raw) {
    return raw;
  }

  /// 加载当前登录用户资料
  Future<void> loadProfile() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // 从 SharedPreferences 加载本地头像路径
      final prefs = await SharedPreferences.getInstance();
      final localPath = prefs.getString(_kLocalAvatarPathKey);

      // 直接从 messageServiceProvider 获取登录用户资料
      final messageService = ref.read(messageServiceProvider);
      final profile = _toUserProfile(messageService.loginUserProfile);

      if (profile != null) {
        final exData = UserProfileState.parseEx(profile.remark);

        // 保留本地路径的优先级：
        // 1. state 中已有本地路径（从 _init 的异步加载恢复的）
        // 2. SharedPreferences 中有本地路径（用户之前选择的头像）
        // 3. 服务器 URL（只有当没有本地路径时才使用）
        String? finalLocalPath;
        if (state.localAvatarPath != null &&
            state.localAvatarPath!.isNotEmpty) {
          // state 中已有本地路径，保留
          finalLocalPath = state.localAvatarPath;
          appLog.i('[UserProfile] loadProfile: 使用 state 中的本地路径');
        } else if (localPath != null && localPath.isNotEmpty) {
          // SharedPreferences 中有本地路径，使用
          finalLocalPath = localPath;
          appLog.i('[UserProfile] loadProfile: 使用 SharedPreferences 中的本地路径');
        } else {
          // 都没有，使用服务器 URL（不需要清除本地路径，因为本来就是 null）
          finalLocalPath = null;
          appLog.i('[UserProfile] loadProfile: 没有本地路径，使用服务器 URL');
        }

        state = state.copyWith(
          profile: profile,
          nickname: profile.nickname.trim(),
          alias: exData['alias'] ?? '',
          signature: exData['signature'] ?? '',
          localAvatarPath: finalLocalPath,
          isLoading: false,
        );
      } else {
        // 如果 messageService 中没有登录用户资料，尝试从服务端获取
        final refreshedProfile = _toUserProfile(
          await ref
              .read(messageServiceProvider.notifier)
              .refreshLoginUserProfile(),
        );
        if (refreshedProfile != null) {
          final exData = UserProfileState.parseEx(refreshedProfile.remark);
          // 同样的优先级：保留本地路径
          String? finalLocalPath;
          if (state.localAvatarPath != null &&
              state.localAvatarPath!.isNotEmpty) {
            finalLocalPath = state.localAvatarPath;
            appLog.i('[UserProfile] loadProfile(refresh): 使用 state 中的本地路径');
          } else if (localPath != null && localPath.isNotEmpty) {
            finalLocalPath = localPath;
            appLog.i(
              '[UserProfile] loadProfile(refresh): 使用 SharedPreferences 中的本地路径',
            );
          } else {
            finalLocalPath = null;
            appLog.i('[UserProfile] loadProfile(refresh): 没有本地路径，使用服务器 URL');
          }
          state = state.copyWith(
            profile: refreshedProfile,
            nickname: refreshedProfile.nickname.trim(),
            alias: exData['alias'] ?? '',
            signature: exData['signature'] ?? '',
            localAvatarPath: finalLocalPath,
            isLoading: false,
          );
        } else {
          state = state.copyWith(isLoading: false, error: '加载用户资料失败');
        }
      }
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
        state = state.copyWith(
          profile: _toUserProfile(updated),
          nickname: updated.nickname.trim(),
          isLoading: false,
        );
        return true;
      } else {
        state = state.copyWith(isLoading: false, error: '更新昵称失败');
        return false;
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '更新昵称失败: $e');
      return false;
    }
  }

  /// 更新别名
  Future<bool> updateAlias(String alias) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final currentEx = state.profile?.remark ?? '';
      final newEx = UserProfileState.buildEx(
        currentEx: currentEx,
        alias: alias,
      );

      final updated = await ref
          .read(messageServiceProvider.notifier)
          .updateLoginUserProfile(ex: newEx);

      if (updated != null) {
        state = state.copyWith(
          profile: _toUserProfile(updated),
          alias: alias,
          isLoading: false,
        );
        return true;
      } else {
        state = state.copyWith(isLoading: false, error: '更新别名失败');
        return false;
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '更新别名失败: $e');
      return false;
    }
  }

  /// 更新个性签名
  Future<bool> updateSignature(String signature) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final currentEx = state.profile?.remark ?? '';
      final newEx = UserProfileState.buildEx(
        currentEx: currentEx,
        signature: signature,
      );

      final updated = await ref
          .read(messageServiceProvider.notifier)
          .updateLoginUserProfile(ex: newEx);

      if (updated != null) {
        state = state.copyWith(
          profile: _toUserProfile(updated),
          signature: signature,
          isLoading: false,
        );
        return true;
      } else {
        state = state.copyWith(isLoading: false, error: '更新个性签名失败');
        return false;
      }
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
        // 检查服务器返回的 faceUrl 是否包含我们上传的 URL，并且是有效的外部 URL
        // 只有当服务器确认保存了新头像且 URL 有效时才清除本地路径
        final serverUrlUpdated =
            updated.faceUrl.isNotEmpty &&
            _isValidAvatarUrl(updated.faceUrl) && // 检查服务器返回的 URL 是否有效
            (updated.faceUrl.contains(imageUrl) ||
                imageUrl.contains(_extractFileName(updated.faceUrl)));

        appLog.i(
          '[UserProfile] updateAvatar: 发送的URL=$imageUrl, 服务器返回的URL=${updated.faceUrl}, 服务器已更新=$serverUrlUpdated',
        );

        // 给头像 URL 添加时间戳参数，绕过缓存确保立即生效
        final cacheBustedUrl = _addCacheBuster(updated.faceUrl);
        final profileWithCacheBuster = UserProfile(
          userId: updated.userId,
          nickname: updated.nickname,
          faceUrl: cacheBustedUrl,
          gender: updated.gender,
          telephone: updated.telephone,
          email: updated.email,
          remark: updated.remark,
          globalRecvMsgOpt: updated.globalRecvMsgOpt,
        );

        state = state.copyWith(
          profile: profileWithCacheBuster,
          localAvatarPath: state.localAvatarPath,
          isLoading: false,
        );

        if (serverUrlUpdated) {
          appLog.i('[UserProfile] updateAvatar: 服务器已确认更新，保留本地路径作为兜底');
        } else {
          appLog.w('[UserProfile] updateAvatar: 服务器未确认更新或 URL 无效，保留本地路径');
        }

        return serverUrlUpdated;
      } else {
        state = state.copyWith(isLoading: false, error: '更新头像失败');
        return false;
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '更新头像失败: $e');
      return false;
    }
  }

  /// 从 URL 中提取文件名
  String _extractFileName(String url) {
    if (url.isEmpty) return '';
    final uri = Uri.tryParse(url);
    if (uri == null) return '';
    final paths = uri.pathSegments;
    if (paths.isEmpty) return '';
    return paths.last;
  }

  /// 上传头像文件，返回服务器 URL
  Future<String> uploadAvatar(String filePath) {
    final service = ref.read(mediaUploadServiceProvider);
    return service.uploadFile(filePath: filePath, fileName: 'avatar.jpg');
  }

  /// 设置本地头像路径（用于临时显示和持久化）
  Future<String?> setLocalAvatarPath(String path) async {
    appLog.i('[UserProfile] setLocalAvatarPath 被调用，path=$path');
    String savedPath = path;
    final source = File(path);
    if (source.existsSync()) {
      try {
        final dir = await getApplicationDocumentsDirectory();
        savedPath =
            '${dir.path}/avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
        await source.copy(savedPath);
        appLog.i('[UserProfile] 已复制头像到持久目录: $savedPath');
      } catch (e) {
        appLog.e('[UserProfile] 复制头像失败，保留原路径: $e');
      }
    }
    await _saveLocalAvatarPath(savedPath);
    state = state.copyWith(localAvatarPath: savedPath);
    appLog.i('[UserProfile] setLocalAvatarPath 完成，savedPath=$savedPath');
    return savedPath;
  }

  /// 清除本地头像路径
  Future<void> clearLocalAvatarPath() async {
    appLog.i('[UserProfile] clearLocalAvatarPath 被调用');
    await _saveLocalAvatarPath(null);
    state = state.copyWith(clearLocalAvatarPath: true);
  }

  /// 为 URL 添加缓存清除参数
  String _addCacheBuster(String url) {
    if (url.isEmpty) return url;
    final separator = url.contains('?') ? '&' : '?';
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '$url${separator}_t=$timestamp';
  }

  /// 清除错误
  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// 用户资料 Provider
