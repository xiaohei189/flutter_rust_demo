import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_rust_demo/data/repositories/settings_repository.dart';
import 'package:flutter_rust_demo/providers/settings_provider.dart';
import 'package:flutter_rust_demo/ui/profile/providers/account_settings_provider.dart';
import 'package:flutter_rust_demo/ui/profile/view_models/account_settings_view_model.dart';

class FakeSettingsRepository implements SettingsRepository {
  FakeSettingsRepository({
    this.appLockEnabled = false,
    this.biometricEnabled = false,
    this.notificationsEnabled = true,
    this.localeCode = 'zh',
    this.canUseBiometricsResult = true,
    this.authenticateResult = true,
    this.shouldFail = false,
  });

  bool appLockEnabled;
  bool biometricEnabled;
  bool notificationsEnabled;
  String localeCode;
  bool canUseBiometricsResult;
  bool authenticateResult;
  bool shouldFail;
  String? savedPin;

  void _maybeFail() {
    if (shouldFail) throw Exception('设置失败');
  }

  @override
  Future<bool> isAppLockEnabled() async => appLockEnabled;

  @override
  Future<bool> isBiometricEnabled() async => biometricEnabled;

  @override
  Future<bool> isNotificationsEnabled() async => notificationsEnabled;

  @override
  Future<String> getLocaleCode() async => localeCode;

  @override
  Future<void> savePin(String pin) async {
    _maybeFail();
    savedPin = pin;
  }

  @override
  Future<void> setAppLockEnabled(bool enabled) async {
    _maybeFail();
    appLockEnabled = enabled;
  }

  @override
  Future<bool> canUseBiometrics() async => canUseBiometricsResult;

  @override
  Future<bool> authenticateWithBiometrics() async => authenticateResult;

  @override
  Future<void> setBiometricEnabled(bool enabled) async {
    _maybeFail();
    biometricEnabled = enabled;
  }

  @override
  Future<void> setNotificationsEnabled(bool enabled) async {
    _maybeFail();
    notificationsEnabled = enabled;
  }

  @override
  Future<void> setLocale(String code) async {
    _maybeFail();
    localeCode = code;
  }

  @override
  Future<bool> verifyPin(String pin) async => true;
}

AccountSettingsViewModel buildViewModel(FakeSettingsRepository repository) {
  final container = ProviderContainer(
    overrides: [settingsRepositoryProvider.overrideWithValue(repository)],
  );
  addTearDown(container.dispose);
  return container.read(accountSettingsViewModelProvider.notifier);
}

void main() {
  group('AccountSettingsViewModel', () {
    test('load 读取应用锁、生物识别、通知和语言设置', () async {
      final repository = FakeSettingsRepository(
        appLockEnabled: true,
        biometricEnabled: true,
        notificationsEnabled: false,
        localeCode: 'en',
      );
      final viewModel = buildViewModel(repository);

      await viewModel.load();

      expect(viewModel.currentState.appLockEnabled, isTrue);
      expect(viewModel.currentState.biometricEnabled, isTrue);
      expect(viewModel.currentState.notificationsEnabled, isFalse);
      expect(viewModel.currentState.localeCode, 'en');
    });

    test('setNotificationsEnabled 成功时更新状态并写入仓库', () async {
      final repository = FakeSettingsRepository();
      final viewModel = buildViewModel(repository);

      final ok = await viewModel.setNotificationsEnabled(false);

      expect(ok, isTrue);
      expect(repository.notificationsEnabled, isFalse);
      expect(viewModel.currentState.notificationsEnabled, isFalse);
    });

    test('enableAppLock 保存 PIN 并开启应用锁', () async {
      final repository = FakeSettingsRepository();
      final viewModel = buildViewModel(repository);

      final ok = await viewModel.enableAppLock('1234');

      expect(ok, isTrue);
      expect(repository.savedPin, '1234');
      expect(repository.appLockEnabled, isTrue);
      expect(viewModel.currentState.appLockEnabled, isTrue);
    });

    test('enableAppLock 校验 PIN 长度', () async {
      final repository = FakeSettingsRepository();
      final viewModel = buildViewModel(repository);

      final ok = await viewModel.enableAppLock('12');

      expect(ok, isFalse);
      expect(viewModel.currentState.error, contains('PIN 长度'));
      expect(repository.appLockEnabled, isFalse);
    });

    test('disableAppLock 关闭应用锁并重置生物识别', () async {
      final repository = FakeSettingsRepository(
        appLockEnabled: true,
        biometricEnabled: true,
      );
      final viewModel = buildViewModel(repository);

      final ok = await viewModel.disableAppLock();

      expect(ok, isTrue);
      expect(repository.appLockEnabled, isFalse);
      expect(repository.biometricEnabled, isFalse);
      expect(viewModel.currentState.biometricEnabled, isFalse);
    });

    test('enableBiometric 成功时开启生物识别', () async {
      final repository = FakeSettingsRepository();
      final viewModel = buildViewModel(repository);

      final ok = await viewModel.enableBiometric();

      expect(ok, isTrue);
      expect(repository.biometricEnabled, isTrue);
      expect(viewModel.currentState.biometricEnabled, isTrue);
    });

    test('enableBiometric 设备不支持时写入错误', () async {
      final repository = FakeSettingsRepository(canUseBiometricsResult: false);
      final viewModel = buildViewModel(repository);

      final ok = await viewModel.enableBiometric();

      expect(ok, isFalse);
      expect(viewModel.currentState.error, contains('不支持生物识别'));
    });

    test('setLocale 更新语言设置', () async {
      final repository = FakeSettingsRepository();
      final viewModel = buildViewModel(repository);

      final ok = await viewModel.setLocale('en');

      expect(ok, isTrue);
      expect(repository.localeCode, 'en');
      expect(viewModel.currentState.localeCode, 'en');
    });
  });
}
