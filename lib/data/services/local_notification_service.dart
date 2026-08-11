import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalNotificationService {
  static final LocalNotificationService instance =
      LocalNotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  static const _enabledKey = 'local_notifications_enabled';

  LocalNotificationService._internal();

  Future<void> initialize() async {
    if (_initialized) return;
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      ),
      windows: WindowsInitializationSettings(
        appName: 'Flutter Rust Demo',
        appUserModelId: 'OpenIM.FlutterRustDemo',
        guid: '9B2B9A1A-9C3E-4C4A-9B7D-2A2B2C2D2E2F',
      ),
    );
    await _plugin.initialize(settings: settings);
    if (defaultTargetPlatform == TargetPlatform.android) {
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
    }
    _initialized = true;
  }

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? true;
  }

  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);
  }

  Future<void> showMessageNotification({
    required String title,
    required String body,
  }) async {
    if (!_initialized || !await isEnabled()) return;
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'openim_messages',
        '新消息通知',
        channelDescription: '收到新消息时显示本地通知',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
      windows: WindowsNotificationDetails(),
    );
    final id = DateTime.now().millisecondsSinceEpoch.remainder(1 << 30);
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: details,
    );
  }
}
