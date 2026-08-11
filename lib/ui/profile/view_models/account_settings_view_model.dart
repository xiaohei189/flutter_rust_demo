import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/settings_repository.dart';
import '../../../providers/settings_provider.dart';
import '../../chat/providers/message_service_provider.dart';

/// 账号设置页状态
class AccountSettingsState {
  final bool isLoading;
  final bool appLockEnabled;
  final bool biometricEnabled;
  final bool notificationsEnabled;
  final String localeCode;
  final String? error;

  const AccountSettingsState({
    this.isLoading = false,
    this.appLockEnabled = false,
    this.biometricEnabled = false,
    this.notificationsEnabled = true,
    this.localeCode = 'zh',
    this.error,
  });

  AccountSettingsState copyWith({
    bool? isLoading,
    bool? appLockEnabled,
    bool? biometricEnabled,
    bool? notificationsEnabled,
    String? localeCode,
    String? error,
    bool clearError = false,
  }) {
    return AccountSettingsState(
      isLoading: isLoading ?? this.isLoading,
      appLockEnabled: appLockEnabled ?? this.appLockEnabled,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      localeCode: localeCode ?? this.localeCode,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// 账号设置 ViewModel：负责应用锁、生物识别、通知、语言与全局免打扰。
class AccountSettingsViewModel extends Notifier<AccountSettingsState> {
  @override
  AccountSettingsState build() {
    return const AccountSettingsState();
  }

  AccountSettingsState get currentState => state;

  SettingsRepository get _settings => ref.read(settingsRepositoryProvider);

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final appLockEnabled = await _settings.isAppLockEnabled();
      final biometricEnabled = await _settings.isBiometricEnabled();
      final notificationsEnabled = await _settings.isNotificationsEnabled();
      final localeCode = await _settings.getLocaleCode();
      state = state.copyWith(
        isLoading: false,
        appLockEnabled: appLockEnabled,
        biometricEnabled: biometricEnabled,
        notificationsEnabled: notificationsEnabled,
        localeCode: localeCode,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '加载设置失败: $e');
    }
  }

  Future<bool> setGlobalMute(bool value) async {
    state = state.copyWith(clearError: true);
    try {
      await ref
          .read(messageRepositoryProvider)
          .setGlobalMsgRecvOpt(globalRecvOpt: value ? 1 : 0);
      await ref.read(messageServiceProvider.notifier).refreshLoginUserProfile();
      return true;
    } catch (e) {
      state = state.copyWith(error: '设置失败: $e');
      return false;
    }
  }

  Future<bool> setNotificationsEnabled(bool value) async {
    state = state.copyWith(notificationsEnabled: value, clearError: true);
    try {
      await _settings.setNotificationsEnabled(value);
      return true;
    } catch (e) {
      state = state.copyWith(error: '设置失败: $e');
      return false;
    }
  }

  Future<bool> enableAppLock(String pin) async {
    if (pin.length < 4 || pin.length > 6) {
      state = state.copyWith(error: 'PIN 长度需要 4-6 位');
      return false;
    }
    state = state.copyWith(clearError: true);
    try {
      await _settings.savePin(pin);
      await _settings.setAppLockEnabled(true);
      state = state.copyWith(appLockEnabled: true);
      return true;
    } catch (e) {
      state = state.copyWith(error: '开启应用锁失败: $e');
      return false;
    }
  }

  Future<bool> disableAppLock() async {
    state = state.copyWith(clearError: true);
    try {
      await _settings.setAppLockEnabled(false);
      await _settings.setBiometricEnabled(false);
      state = state.copyWith(appLockEnabled: false, biometricEnabled: false);
      return true;
    } catch (e) {
      state = state.copyWith(error: '关闭应用锁失败: $e');
      return false;
    }
  }

  Future<bool> enableBiometric() async {
    state = state.copyWith(clearError: true);
    if (!await _settings.canUseBiometrics()) {
      state = state.copyWith(error: '当前设备不支持生物识别');
      return false;
    }
    final authenticated = await _settings.authenticateWithBiometrics();
    if (!authenticated) return false;
    try {
      await _settings.setBiometricEnabled(true);
      state = state.copyWith(biometricEnabled: true);
      return true;
    } catch (e) {
      state = state.copyWith(error: '开启生物识别失败: $e');
      return false;
    }
  }

  Future<bool> disableBiometric() async {
    state = state.copyWith(clearError: true);
    try {
      await _settings.setBiometricEnabled(false);
      state = state.copyWith(biometricEnabled: false);
      return true;
    } catch (e) {
      state = state.copyWith(error: '关闭生物识别失败: $e');
      return false;
    }
  }

  Future<bool> setLocale(String code) async {
    state = state.copyWith(clearError: true);
    try {
      await _settings.setLocale(code);
      state = state.copyWith(localeCode: code);
      return true;
    } catch (e) {
      state = state.copyWith(error: '切换语言失败: $e');
      return false;
    }
  }
}
