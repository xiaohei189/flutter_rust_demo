import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/message_service_notifier.dart';
import '../src/rust/api/bridge_client.dart';
import 'message_service_provider.dart';

/// 用户资料状态
class UserProfileState {
  final UserProfile? profile;
  final String nickname;
  final String alias;
  final String signature;
  final bool isLoading;
  final String? error;

  const UserProfileState({
    this.profile,
    this.nickname = '',
    this.alias = '',
    this.signature = '',
    this.isLoading = false,
    this.error,
  });

  UserProfileState copyWith({
    UserProfile? profile,
    String? nickname,
    String? alias,
    String? signature,
    bool? isLoading,
    String? error,
  }) {
    return UserProfileState(
      profile: profile ?? this.profile,
      nickname: nickname ?? this.nickname,
      alias: alias ?? this.alias,
      signature: signature ?? this.signature,
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

/// 用户资料 Notifier
class UserProfileNotifier extends StateNotifier<UserProfileState> {
  UserProfileNotifier(this._messageService) : super(const UserProfileState());

  final MessageServiceNotifier _messageService;

  /// 获取指定用户资料（从 MessageService 缓存）
  UserProfile? getUserProfile(String userId) {
    // 如果是当前登录用户，直接返回
    if (state.profile?.userId == userId) {
      return state.profile;
    }
    // 从 MessageService 缓存获取
    return _messageService.getUserProfile(userId);
  }

  /// 加载当前登录用户资料
  Future<void> loadProfile() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final profile = await _messageService.refreshLoginUserProfile();

      if (profile != null) {
        final exData = UserProfileState.parseEx(profile.ex);
        state = state.copyWith(
          profile: profile,
          nickname: profile.nickname.trim(),
          alias: exData['alias'] ?? '',
          signature: exData['signature'] ?? '',
          isLoading: false,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: '加载用户资料失败',
        );
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
      final updated = await _messageService.updateLoginUserProfile(
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

      final updated = await _messageService.updateLoginUserProfile(
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

      final updated = await _messageService.updateLoginUserProfile(
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

  /// 清除错误
  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// 用户资料 Provider
final userProfileProvider =
    StateNotifierProvider<UserProfileNotifier, UserProfileState>((ref) {
  return UserProfileNotifier(ref.read(messageServiceProvider.notifier));
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
