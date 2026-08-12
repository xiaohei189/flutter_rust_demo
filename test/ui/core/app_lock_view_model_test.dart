import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_rust_demo/data/repositories/settings_repository.dart';
import 'package:flutter_rust_demo/providers/settings_provider.dart';
import 'package:flutter_rust_demo/ui/core/providers/app_lock_provider.dart';
import 'package:flutter_rust_demo/ui/core/view_models/app_lock_view_model.dart';

class FakeSettingsRepository implements SettingsRepository {
  FakeSettingsRepository({
    this.appLockEnabled = false,
    this.biometricEnabled = false,
    this.verifyResult = true,
    this.authenticateResult = true,
  });

  bool appLockEnabled;
  bool biometricEnabled;
  bool verifyResult;
  bool authenticateResult;

  @override
  Future<bool> isAppLockEnabled() async => appLockEnabled;

  @override
  Future<bool> isBiometricEnabled() async => biometricEnabled;

  @override
  Future<bool> verifyPin(String pin) async => verifyResult;

  @override
  Future<bool> authenticateWithBiometrics() async => authenticateResult;

  @override
  Future<bool> canUseBiometrics() async => true;

  @override
  Future<bool> isNotificationsEnabled() async => true;

  @override
  Future<void> setNotificationsEnabled(bool enabled) async {}

  @override
  Future<String> getLocaleCode() async => 'zh';

  @override
  Future<void> setLocale(String code) async {}

  @override
  Future<void> savePin(String pin) async {}

  @override
  Future<void> setAppLockEnabled(bool enabled) async {
    appLockEnabled = enabled;
  }

  @override
  Future<void> setBiometricEnabled(bool enabled) async {
    biometricEnabled = enabled;
  }
}

AppLockViewModel buildViewModel(FakeSettingsRepository repository) {
  final container = ProviderContainer(
    overrides: [settingsRepositoryProvider.overrideWithValue(repository)],
  );
  addTearDown(container.dispose);
  return container.read(appLockViewModelProvider.notifier);
}

void main() {
  group('AppLockViewModel', () {
    test('load 未启用时不展示锁屏', () async {
      final viewModel = buildViewModel(FakeSettingsRepository());

      await viewModel.load();

      expect(viewModel.currentState.shouldShowLock, isFalse);
    });

    test('load 启用后展示锁屏', () async {
      final viewModel = buildViewModel(
        FakeSettingsRepository(appLockEnabled: true),
      );

      await viewModel.load();

      expect(viewModel.currentState.enabled, isTrue);
      expect(viewModel.currentState.shouldShowLock, isTrue);
    });

    test('lock 在后台重新锁定', () async {
      final viewModel = buildViewModel(
        FakeSettingsRepository(appLockEnabled: true),
      );
      await viewModel.load();
      await viewModel.unlockWithPin('1234');

      viewModel.lock();

      expect(viewModel.currentState.shouldShowLock, isTrue);
    });

    test('unlockWithPin 成功时解锁', () async {
      final viewModel = buildViewModel(
        FakeSettingsRepository(appLockEnabled: true),
      );
      await viewModel.load();

      final ok = await viewModel.unlockWithPin('1234');

      expect(ok, isTrue);
      expect(viewModel.currentState.shouldShowLock, isFalse);
    });

    test('unlockWithPin 失败时写入错误', () async {
      final viewModel = buildViewModel(
        FakeSettingsRepository(appLockEnabled: true, verifyResult: false),
      );
      await viewModel.load();

      final ok = await viewModel.unlockWithPin('0000');

      expect(ok, isFalse);
      expect(viewModel.currentState.error, 'PIN 不正确');
    });

    test('unlockWithBiometrics 成功时解锁', () async {
      final viewModel = buildViewModel(
        FakeSettingsRepository(appLockEnabled: true, biometricEnabled: true),
      );
      await viewModel.load();

      final ok = await viewModel.unlockWithBiometrics();

      expect(ok, isTrue);
      expect(viewModel.currentState.shouldShowLock, isFalse);
    });
  });
}
