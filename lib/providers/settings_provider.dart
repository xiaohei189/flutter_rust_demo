import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/settings_repository.dart';
import '../data/services/app_lock_service.dart';
import '../data/services/local_notification_service.dart';
import '../data/services/locale_service.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepositoryImpl(
    appLockService: AppLockService.instance,
    notificationService: LocalNotificationService.instance,
    localeService: LocaleService.instance,
  );
});
