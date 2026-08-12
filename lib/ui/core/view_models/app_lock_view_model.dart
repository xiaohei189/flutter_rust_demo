import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/settings_provider.dart';

/// 应用锁状态
class AppLockState {
  final bool? enabled;
  final bool unlocked;
  final bool biometricEnabled;
  final String? error;

  const AppLockState({
    this.enabled,
    this.unlocked = false,
    this.biometricEnabled = false,
    this.error,
  });

  AppLockState copyWith({
    bool? enabled,
    bool? unlocked,
    bool? biometricEnabled,
    String? error,
    bool clearError = false,
  }) {
    return AppLockState(
      enabled: enabled ?? this.enabled,
      unlocked: unlocked ?? this.unlocked,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      error: clearError ? null : (error ?? this.error),
    );
  }

  bool get shouldShowLock => enabled == true && !unlocked;
}

/// 应用锁 ViewModel：负责启用状态、PIN 与生物识别解锁。
class AppLockViewModel extends Notifier<AppLockState> {
  @override
  AppLockState build() => const AppLockState();

  AppLockState get currentState => state;

  Future<void> load() async {
    try {
      final settings = ref.read(settingsRepositoryProvider);
      final enabled = await settings.isAppLockEnabled();
      final biometricEnabled = await settings.isBiometricEnabled();
      state = state.copyWith(
        enabled: enabled,
        unlocked: !enabled,
        biometricEnabled: biometricEnabled,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(error: '加载应用锁状态失败: $e');
    }
  }

  void lock() {
    if (state.enabled == true) {
      state = state.copyWith(unlocked: false, clearError: true);
    }
  }

  Future<bool> unlockWithPin(String pin) async {
    if (pin.isEmpty) return false;
    final ok = await ref.read(settingsRepositoryProvider).verifyPin(pin);
    if (!ok) {
      state = state.copyWith(error: 'PIN 不正确');
      return false;
    }
    state = state.copyWith(unlocked: true, clearError: true);
    return true;
  }

  Future<bool> unlockWithBiometrics() async {
    final ok = await ref
        .read(settingsRepositoryProvider)
        .authenticateWithBiometrics();
    if (ok) {
      state = state.copyWith(unlocked: true, clearError: true);
    }
    return ok;
  }
}
