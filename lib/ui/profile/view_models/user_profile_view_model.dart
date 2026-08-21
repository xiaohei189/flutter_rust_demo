import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/user_profile.dart';

import '../../../providers/im_providers.dart';
import 'user_avatar_store.dart';
import '../../../core/utils/app_logger.dart';
import '../../chat/providers/message_revision_provider.dart';
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

/// 用户资料 Notifier
class UserProfileNotifier extends Notifier<UserProfileState> {
  final UserAvatarStore _avatarStore = UserAvatarStore();

  @override
  UserProfileState build() {
    _init();
    return const UserProfileState();
  }

  void _init() {
    // 先加载本地头像路径（从 SharedPreferences 恢复）
    Future.microtask(_loadLocalAvatarPathSync);

    // 监听 messageServiceProvider 的状态变化
    ref.listen(loginUserProfileProvider, (previous, next) {
      if (next != null) {
        // 当 loginUserProfile 变化时直接更新状态
        if (previous?.userId != next.userId ||
            previous?.nickname != next.nickname ||
            previous?.faceUrl != next.faceUrl) {
          final profile = next;
          appLog.i(
            '[UserProfile] 监听器触发: faceUrl=${profile.faceUrl}, 当前 localAvatarPath=${state.localAvatarPath}',
          );

          // 重要：如果已经有本地路径了，保留它！
          // 只有本地路径为空，并且服务器 URL 有效时才使用服务器 URL
          final String? localAvatarPath = state.localAvatarPath;
          appLog.i('[UserProfile] 监听器: 保留 localAvatarPath=$localAvatarPath');

          state = UserProfileState.fromServerProfile(
            profile,
            localAvatarPath: localAvatarPath, // 保持本地路径不变
          );
        }
      }
    });
  }

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

  /// 获取用于显示的头像 URL：本地路径 > 服务器 URL（如果有效）。
  String? getDisplayAvatarUrl() => _avatarStore.resolveDisplayUrl(
    localAvatarPath: state.localAvatarPath,
    profile: state.profile,
  );

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
      // 从本地存储加载本地头像路径
      final localPath = await _avatarStore.loadLocalAvatarPath();

      // 直接从 messageServiceProvider 获取登录用户资料
      final messageService = ref.read(messageServiceProvider);
      final profile = _toUserProfile(messageService.loginUserProfile);

      if (profile != null) {
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

        state = UserProfileState.fromServerProfile(
          profile,
          localAvatarPath: finalLocalPath,
        );
      } else {
        // 如果 messageService 中没有登录用户资料，尝试从服务端获取
        final refreshedProfile = _toUserProfile(
          await ref
              .read(messageServiceProvider.notifier)
              .refreshLoginUserProfile(),
        );
        if (refreshedProfile != null) {
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
          state = UserProfileState.fromServerProfile(
            refreshedProfile,
            localAvatarPath: finalLocalPath,
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
            _avatarStore.isValidAvatarUrl(
              updated.faceUrl,
            ) && // 检查服务器返回的 URL 是否有效
            (updated.faceUrl.contains(imageUrl) ||
                imageUrl.contains(
                  _avatarStore.extractFileName(updated.faceUrl),
                ));

        appLog.i(
          '[UserProfile] updateAvatar: 发送的URL=$imageUrl, 服务器返回的URL=${updated.faceUrl}, 服务器已更新=$serverUrlUpdated',
        );

        // 给头像 URL 添加时间戳参数，绕过缓存确保立即生效
        final cacheBustedUrl = _avatarStore.addCacheBuster(updated.faceUrl);
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

/// 用户资料 Provider
