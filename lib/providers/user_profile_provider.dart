import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../src/rust/api/bridge_client.dart';
import 'message_service_provider.dart';

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
    bool? isLoading,
    String? error,
  }) {
    return UserProfileState(
      profile: profile ?? this.profile,
      nickname: nickname ?? this.nickname,
      alias: alias ?? this.alias,
      signature: signature ?? this.signature,
      localAvatarPath: localAvatarPath ?? this.localAvatarPath,
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
class UserProfileNotifier extends StateNotifier<UserProfileState> {
  UserProfileNotifier(this._ref) : super(const UserProfileState()) {
    _init();
  }

  final Ref _ref;

  void _init() {
    // 监听 messageServiceProvider 的状态变化
    _ref.listen(
      messageServiceProvider,
      (previous, next) {
        if (next.isConnected && next.loginUserProfile != null) {
          // 当 loginUserProfile 变化时直接更新状态
          if (previous?.loginUserProfile?.userId != next.loginUserProfile?.userId ||
              previous?.loginUserProfile?.nickname != next.loginUserProfile?.nickname ||
              previous?.loginUserProfile?.faceUrl != next.loginUserProfile?.faceUrl) {
            final profile = next.loginUserProfile!;
            final exData = UserProfileState.parseEx(profile.ex);
            
            // 如果服务器头像URL有效，清除本地路径（使用服务器URL）
            String? localAvatarPath = state.localAvatarPath;
            if (_isValidAvatarUrl(profile.faceUrl)) {
              localAvatarPath = null;
              // 同时清除 SharedPreferences 中的本地路径
              _saveLocalAvatarPath(null);
            }
            
            state = state.copyWith(
              profile: profile,
              nickname: profile.nickname.trim(),
              alias: exData['alias'] ?? '',
              signature: exData['signature'] ?? '',
              localAvatarPath: localAvatarPath,
              isLoading: false,
              error: null,
            );
          }
        }
      },
      fireImmediately: true,
    );
  }

  /// 从 SharedPreferences 加载本地头像路径
  Future<void> loadLocalAvatarPath() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final path = prefs.getString(_kLocalAvatarPathKey);
      if (path != null) {
        state = state.copyWith(localAvatarPath: path);
      }
    } catch (e) {
      // 忽略错误
    }
  }

  /// 保存本地头像路径到 SharedPreferences
  Future<void> _saveLocalAvatarPath(String? path) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (path != null) {
        await prefs.setString(_kLocalAvatarPathKey, path);
      } else {
        await prefs.remove(_kLocalAvatarPathKey);
      }
    } catch (e) {
      // 忽略错误
    }
  }

  /// 检查 URL 是否为有效的头像 URL（不是模拟 URL）
  bool _isValidAvatarUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    // 排除模拟 URL
    if (url.contains('example.com')) return false;
    // 排除本地路径
    if (url.contains(':\\') || url.startsWith('/')) return false;
    return true;
  }

  /// 获取用于显示的头像 URL
  /// 优先级：本地路径 > 服务器 URL（如果有效）
  String? getDisplayAvatarUrl() {
    // 如果有本地路径，优先使用
    if (state.localAvatarPath != null && state.localAvatarPath!.isNotEmpty) {
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
    // 从 MessageService 缓存获取
    return _ref.read(messageServiceProvider.notifier).getUserProfile(userId);
  }

  /// 加载当前登录用户资料
  Future<void> loadProfile() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // 从 SharedPreferences 加载本地头像路径
      final prefs = await SharedPreferences.getInstance();
      final localPath = prefs.getString(_kLocalAvatarPathKey);

      // 直接从 messageServiceProvider 获取登录用户资料
      final messageService = _ref.read(messageServiceProvider);
      final profile = messageService.loginUserProfile;

      if (profile != null) {
        final exData = UserProfileState.parseEx(profile.ex);
        
        // 如果服务器头像URL有效，忽略本地路径（使用服务器URL）
        String? finalLocalPath = localPath;
        if (_isValidAvatarUrl(profile.faceUrl)) {
          finalLocalPath = null;
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
        final refreshedProfile = await _ref.read(messageServiceProvider.notifier).refreshLoginUserProfile();
        if (refreshedProfile != null) {
          final exData = UserProfileState.parseEx(refreshedProfile.ex);
          state = state.copyWith(
            profile: refreshedProfile,
            nickname: refreshedProfile.nickname.trim(),
            alias: exData['alias'] ?? '',
            signature: exData['signature'] ?? '',
            localAvatarPath: _isValidAvatarUrl(refreshedProfile.faceUrl) ? null : localPath,
            isLoading: false,
          );
        } else {
          state = state.copyWith(
            isLoading: false,
            error: '加载用户资料失败',
          );
        }
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: '加载用户资料失败: $e',
      );
    }
  }

  /// 更新昵称
  Future<bool> updateNickname(String nickname) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final updated = await _ref.read(messageServiceProvider.notifier).updateLoginUserProfile(
        nickname: nickname,
      );

      if (updated != null) {
        state = state.copyWith(
          profile: updated,
          nickname: updated.nickname.trim(),
          isLoading: false,
        );
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          error: '更新昵称失败',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: '更新昵称失败: $e',
      );
      return false;
    }
  }

  /// 更新别名
  Future<bool> updateAlias(String alias) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final currentEx = state.profile?.ex ?? '';
      final newEx = UserProfileState.buildEx(
        currentEx: currentEx,
        alias: alias,
      );

      final updated = await _ref.read(messageServiceProvider.notifier).updateLoginUserProfile(
        ex: newEx,
      );

      if (updated != null) {
        state = state.copyWith(
          profile: updated,
          alias: alias,
          isLoading: false,
        );
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          error: '更新别名失败',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: '更新别名失败: $e',
      );
      return false;
    }
  }

  /// 更新个性签名
  Future<bool> updateSignature(String signature) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final currentEx = state.profile?.ex ?? '';
      final newEx = UserProfileState.buildEx(
        currentEx: currentEx,
        signature: signature,
      );

      final updated = await _ref.read(messageServiceProvider.notifier).updateLoginUserProfile(
        ex: newEx,
      );

      if (updated != null) {
        state = state.copyWith(
          profile: updated,
          signature: signature,
          isLoading: false,
        );
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          error: '更新个性签名失败',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: '更新个性签名失败: $e',
      );
      return false;
    }
  }

  /// 更新头像
  Future<bool> updateAvatar(String imageUrl) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final updated = await _ref.read(messageServiceProvider.notifier).updateLoginUserProfile(
        faceUrl: imageUrl,
      );

      if (updated != null) {
        // 给头像 URL 添加时间戳参数，绕过缓存确保立即生效
        final cacheBustedUrl = _addCacheBuster(updated.faceUrl);
        final profileWithCacheBuster = UserProfile(
          userId: updated.userId,
          nickname: updated.nickname,
          faceUrl: cacheBustedUrl,
          ex: updated.ex,
          attachedInfo: updated.attachedInfo,
          globalRecvMsgOpt: updated.globalRecvMsgOpt,
          createTime: updated.createTime,
          appMangerLevel: updated.appMangerLevel,
        );
        state = state.copyWith(
          profile: profileWithCacheBuster,
          localAvatarPath: null, // 清除本地路径，使用服务器URL
          isLoading: false,
        );
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          error: '更新头像失败',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: '更新头像失败: $e',
      );
      return false;
    }
  }

  /// 设置本地头像路径（用于临时显示和持久化）
  Future<void> setLocalAvatarPath(String path) async {
    await _saveLocalAvatarPath(path);
    state = state.copyWith(localAvatarPath: path);
  }

  /// 清除本地头像路径
  Future<void> clearLocalAvatarPath() async {
    await _saveLocalAvatarPath(null);
    state = state.copyWith(localAvatarPath: null);
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
final userProfileProvider =
    StateNotifierProvider<UserProfileNotifier, UserProfileState>((ref) {
  return UserProfileNotifier(ref);
});

/// 当前用户资料 Provider（仅返回 profile）
final currentUserProfileProvider = Provider<UserProfile?>((ref) {
  return ref.watch(userProfileProvider).profile;
});

/// 当前用户昵称 Provider
final currentUserNicknameProvider = Provider<String>((ref) {
  return ref.watch(userProfileProvider).nickname;
});

/// 当前用户别名 Provider
final currentUserAliasProvider = Provider<String>((ref) {
  return ref.watch(userProfileProvider).alias;
});

/// 当前用户签名 Provider
final currentUserSignatureProvider = Provider<String>((ref) {
  return ref.watch(userProfileProvider).signature;
});

/// 用户资料加载状态 Provider
final userProfileLoadingProvider = Provider<bool>((ref) {
  return ref.watch(userProfileProvider).isLoading;
});

/// 用户资料错误 Provider
final userProfileErrorProvider = Provider<String?>((ref) {
  return ref.watch(userProfileProvider).error;
});
