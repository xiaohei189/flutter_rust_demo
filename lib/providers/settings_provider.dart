import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/settings_repository.dart';
import '../services/app_lock_service.dart';
import '../services/local_notification_service.dart';
import '../services/locale_service.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepositoryImpl(
    appLockService: AppLockService.instance,
    notificationService: LocalNotificationService.instance,
    localeService: LocaleService.instance,
  );
});
