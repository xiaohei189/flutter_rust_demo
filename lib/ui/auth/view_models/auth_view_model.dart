import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/app_logger.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../domain/models/auth.dart';
import '../../../providers/current_user_provider.dart';
import '../../chat/providers/message_service_provider.dart';
import '../providers/auth_provider.dart';

/// 登录/注册流程状态
class AuthState {
  final bool isLoading;
  final int countdown;
  final String? errorText;

  const AuthState({this.isLoading = false, this.countdown = 0, this.errorText});

  AuthState copyWith({
    bool? isLoading,
    int? countdown,
    String? errorText,
    bool clearError = false,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      countdown: countdown ?? this.countdown,
      errorText: clearError ? null : (errorText ?? this.errorText),
    );
  }
}

/// 登录/注册 ViewModel：负责验证码倒计时、登录注册、凭证保存与 MessageService 初始化。
class AuthViewModel extends Notifier<AuthState> {
  Timer? _countdownTimer;

  /// 登录收尾阶段的兜底超时（凭证保存 + SDK 初始化）。
  ///
  /// Rust 握手或平台通道异常时（服务重启、网关半死），必须保证 UI 不会永久
  /// 停在 loading。测试可改小该值。
  @visibleForTesting
  static Duration initializeTimeout = const Duration(seconds: 30);

  AuthRepository get _authRepository => ref.read(authRepositoryProvider);

  @override
  AuthState build() {
    ref.onDispose(() => _countdownTimer?.cancel());
    return const AuthState();
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  Future<void> sendCode({
    required String areaCode,
    required String phoneNumber,
    required VerificationCodeUsage usedFor,
  }) async {
    if (phoneNumber.trim().isEmpty) {
      state = state.copyWith(errorText: '请先输入手机号');
      return;
    }
    if (state.countdown > 0) return;

    _countdownTimer?.cancel();
    state = state.copyWith(errorText: null, countdown: 60);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.countdown <= 1) {
        timer.cancel();
        state = state.copyWith(countdown: 0);
      } else {
        state = state.copyWith(countdown: state.countdown - 1);
      }
    });

    try {
      await _authRepository.sendVerificationCode(
        areaCode: areaCode,
        phoneNumber: phoneNumber,
        usedFor: usedFor,
      );
      state = state.copyWith(errorText: null);
    } catch (e, st) {
      appLog.e('发送验证码失败', e, st);
      _countdownTimer?.cancel();
      state = state.copyWith(countdown: 0, errorText: _cleanError(e));
    }
  }

  Future<bool> loginWithPassword({
    required String areaCode,
    required String phoneNumber,
    required String password,
    required String wsUrl,
    required String apiBaseUrl,
  }) async {
    if (phoneNumber.trim().isEmpty || password.trim().isEmpty) {
      state = state.copyWith(errorText: '请输入手机号和密码');
      return false;
    }

    state = state.copyWith(isLoading: true, errorText: null);
    try {
      appLog.i('[登录] 密码登录开始');
      final session = await _authRepository.loginWithPassword(
        areaCode: areaCode,
        phoneNumber: phoneNumber,
        password: password,
        platform: 5,
      );
      return await _completeAuth(
        userId: session.userId,
        imToken: session.imToken,
        areaCode: areaCode,
        phoneNumber: phoneNumber,
        wsUrl: wsUrl,
        apiBaseUrl: apiBaseUrl,
      );
    } catch (e, st) {
      appLog.e('[登录] 密码登录失败', e, st);
      _setLoginError(e);
      return false;
    }
  }

  Future<bool> loginWithVerifyCode({
    required String areaCode,
    required String phoneNumber,
    required String verifyCode,
    required String wsUrl,
    required String apiBaseUrl,
  }) async {
    if (phoneNumber.trim().isEmpty || verifyCode.trim().isEmpty) {
      state = state.copyWith(errorText: '请输入手机号和验证码');
      return false;
    }

    state = state.copyWith(isLoading: true, errorText: null);
    try {
      appLog.i('[登录] 验证码登录开始');
      final session = await _authRepository
          .loginWithVerifyCode(
            areaCode: areaCode,
            phoneNumber: phoneNumber,
            verifyCode: verifyCode,
            platform: 5,
          );
      return await _completeAuth(
        userId: session.userId,
        imToken: session.imToken,
        areaCode: areaCode,
        phoneNumber: phoneNumber,
        wsUrl: wsUrl,
        apiBaseUrl: apiBaseUrl,
      );
    } catch (e, st) {
      appLog.e('[登录] 验证码登录失败', e, st);
      _setLoginError(e);
      return false;
    }
  }

  Future<bool> register({
    required String areaCode,
    required String phoneNumber,
    required String nickname,
    required String verifyCode,
    required String wsUrl,
    required String apiBaseUrl,
  }) async {
    if (phoneNumber.trim().isEmpty ||
        verifyCode.trim().isEmpty ||
        nickname.trim().isEmpty) {
      state = state.copyWith(errorText: '请填写手机号、验证码和昵称');
      return false;
    }

    state = state.copyWith(isLoading: true, errorText: null);
    try {
      appLog.i('[Register] 注册开始');
      final session = await _authRepository.registerWithVerifyCode(
        areaCode: areaCode,
        phoneNumber: phoneNumber,
        nickname: nickname,
        verifyCode: verifyCode,
        platform: 5,
      );
      return await _completeAuth(
        userId: session.userId,
        imToken: session.imToken,
        areaCode: areaCode,
        phoneNumber: phoneNumber,
        wsUrl: wsUrl,
        apiBaseUrl: apiBaseUrl,
      );
    } catch (e) {
      appLog.e('[Register] 注册失败', e);
      state = state.copyWith(isLoading: false, errorText: _cleanError(e));
      return false;
    }
  }

  /// 使用本地凭证自动登录，成功返回 true，失败清理凭证并返回 false。
  Future<bool> autoLogin({
    required String wsUrl,
    required String apiBaseUrl,
  }) async {
    final credentials = await _authRepository.loadCredentials();
    if (credentials == null) return false;
    ref.read(currentUserIdProvider.notifier).setUserId(credentials.userId);
    try {
      await _initializeWithTimeout(
        wsUrl: wsUrl,
        apiBaseUrl: apiBaseUrl,
        userId: credentials.userId,
        imToken: credentials.imToken,
      );
      return true;
    } catch (e) {
      appLog.w('自动登录失败，跳转登录页: $e');
      await _authRepository.clearCredentials();
      return false;
    }
  }

  Future<void> logout() async {
    await _bestEffortLogout();
    ref.read(currentUserIdProvider.notifier).clear();
    await _authRepository.clearCredentials();
  }

  /// 初始化 SDK，并在超时后清理半成品客户端后抛出可读错误。
  ///
  /// 这里是最外层兜底：`MessageService` 内部还有更精确的超时，
  /// 覆盖平台通道等其它可能卡住的等待。
  Future<void> _initializeWithTimeout({
    required String wsUrl,
    required String apiBaseUrl,
    required String userId,
    required String imToken,
  }) async {
    appLog.i('[LoginMeasure] T5 SDK 初始化开始');
    await ref
        .read(messageServiceProvider.notifier)
        .initialize(
          wsUrl: wsUrl,
          apiBaseUrl: apiBaseUrl,
          userId: userId,
          imToken: imToken,
        )
        .timeout(
          initializeTimeout,
          onTimeout: () async {
            appLog.w(
              '[LoginMeasure] T5 SDK 初始化超时（${initializeTimeout.inSeconds}s），清理半成品客户端',
            );
            await _bestEffortLogout();
            throw TimeoutException(
              'IM 初始化超时（${initializeTimeout.inSeconds} 秒），请确认服务已启动后重试',
            );
          },
        );
    appLog.i('[LoginMeasure] T6 SDK 初始化完成');
  }

  /// 尽力清理 SDK，失败或超时都不阻塞调用方（登出/超时兜底共用）。
  Future<void> _bestEffortLogout() async {
    try {
      // 带超时兜底：SDK 断开/关库即使卡住，也保证 5 秒内继续清理并允许跳转登录页
      await ref
          .read(messageServiceProvider.notifier)
          .logout()
          .timeout(const Duration(seconds: 5), onTimeout: () {});
    } catch (e) {
      appLog.w('[Auth] 退出登录 SDK 失败: $e');
    }
  }

  Future<bool> _completeAuth({
    required String userId,
    required String imToken,
    required String areaCode,
    required String phoneNumber,
    required String wsUrl,
    required String apiBaseUrl,
  }) async {
    try {
      await _authRepository.saveCredentials(
        userId: userId,
        imToken: imToken,
        areaCode: areaCode,
        phoneNumber: phoneNumber,
      );
      appLog.i('[LoginMeasure] T4 凭证已保存');
      ref.read(currentUserIdProvider.notifier).setUserId(userId);
      await _initializeWithTimeout(
        wsUrl: wsUrl,
        apiBaseUrl: apiBaseUrl,
        userId: userId,
        imToken: imToken,
      );
      state = state.copyWith(isLoading: false, errorText: null);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorText: '初始化失败: ${_cleanError(e)}',
      );
      return false;
    }
  }

  void _setLoginError(Object e) {
    final msg = _cleanError(e);
    state = state.copyWith(
      isLoading: false,
      errorText: '$msg\n请求地址: ${_authRepository.authBaseUrl}/account/login',
    );
  }

  String _cleanError(Object e) => e.toString().replaceFirst(
    RegExp(r'^(Exception|TimeoutException|StateError):?\s*'),
    '',
  );
}
