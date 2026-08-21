import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/settings_repository.dart';
import 'im_providers.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepositoryImpl(
    appLockService: ref.watch(appLockServiceProvider),
    notificationService: ref.watch(localNotificationServiceProvider),
    localeService: ref.watch(localeServiceProvider),
  );
});
