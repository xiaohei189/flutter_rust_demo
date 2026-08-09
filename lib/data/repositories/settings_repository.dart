import '../../services/app_lock_service.dart';
import '../../services/local_notification_service.dart';
import '../../services/locale_service.dart';

abstract class SettingsRepository {
  Future<bool> isAppLockEnabled();
  Future<bool> isBiometricEnabled();
  Future<void> savePin(String pin);
  Future<void> setAppLockEnabled(bool enabled);
  Future<bool> canUseBiometrics();
  Future<bool> authenticateWithBiometrics();
  Future<void> setBiometricEnabled(bool enabled);
  Future<bool> isNotificationsEnabled();
  Future<void> setNotificationsEnabled(bool enabled);
  Future<String> getLocaleCode();
  Future<void> setLocale(String code);
}

class SettingsRepositoryImpl implements SettingsRepository {
  SettingsRepositoryImpl({
    required AppLockService appLockService,
    required LocalNotificationService notificationService,
    required LocaleService localeService,
  })  : _appLockService = appLockService,
        _notificationService = notificationService,
        _localeService = localeService;

  final AppLockService _appLockService;
  final LocalNotificationService _notificationService;
  final LocaleService _localeService;

  @override
  Future<bool> isAppLockEnabled() => _appLockService.isEnabled();

  @override
  Future<bool> isBiometricEnabled() => _appLockService.isBiometricEnabled();

  @override
  Future<void> savePin(String pin) => _appLockService.savePin(pin);

  @override
  Future<void> setAppLockEnabled(bool enabled) =>
      _appLockService.setEnabled(enabled);

  @override
  Future<bool> canUseBiometrics() => _appLockService.canUseBiometrics();

  @override
  Future<bool> authenticateWithBiometrics() =>
      _appLockService.authenticateWithBiometrics();

  @override
  Future<void> setBiometricEnabled(bool enabled) =>
      _appLockService.setBiometricEnabled(enabled);

  @override
  Future<bool> isNotificationsEnabled() =>
      _notificationService.isEnabled();

  @override
  Future<void> setNotificationsEnabled(bool enabled) =>
      _notificationService.setEnabled(enabled);

  @override
  Future<String> getLocaleCode() async {
    final languageCode = _localeService.locale.value?.languageCode;
    return languageCode == 'en' ? 'en' : 'zh';
  }

  @override
  Future<void> setLocale(String code) => _localeService.setLocale(code);
}
