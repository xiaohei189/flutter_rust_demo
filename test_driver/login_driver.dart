// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart';

Future<bool> _exists(
  FlutterDriver driver,
  SerializableFinder finder, {
  Duration timeout = const Duration(seconds: 2),
}) async {
  try {
    await driver.waitFor(finder, timeout: timeout);
    return true;
  } catch (_) {
    return false;
  }
}

/// 验证码登录辅助：本地测试环境验证码固定 `666666`。
///
/// 用法：`PHONE=2361018881 VM_SERVICE_URL=ws://127.0.0.1:xxxxx/ws dart run test_driver/login_driver.dart`
/// 可选 `AREA_CODE`（默认 `+86`）、`CODE`（默认 `666666`）。
/// 已登录时直接返回 `LOGIN_ALREADY`，不会重复点登录。
Future<void> main() async {
  final phone = Platform.environment['PHONE'] ?? '';
  if (phone.isEmpty) {
    print('LOGIN_FAILED: 缺少 PHONE');
    return;
  }
  final areaCode = Platform.environment['AREA_CODE'] ?? '+86';
  final code = Platform.environment['CODE'] ?? '666666';

  final driver = await FlutterDriver.connect(
    dartVmServiceUrl: Platform.environment['VM_SERVICE_URL'],
    timeout: const Duration(seconds: 30),
  );
  try {
    if (await _exists(driver, find.byValueKey('chat_add_button'))) {
      print('LOGIN_ALREADY: 已处于登录态');
      return;
    }

    await driver.tap(find.text('验证码登录'));
    await driver.setTextEntryEmulation(enabled: true);
    await driver.tap(
      find.byValueKey('login_phone'),
      timeout: const Duration(seconds: 10),
    );
    await driver.enterText(phone);
    await driver.tap(find.text('获取验证码'));
    await driver.tap(find.byValueKey('login_verify_code'));
    await driver.enterText(code);
    await Future<void>.delayed(const Duration(seconds: 1));
    // 登录按钮在小屏上位于首屏之外，需要先滚动到可见再点。
    await driver.scrollUntilVisible(
      find.byType('Scrollable'),
      find.byValueKey('login_submit'),
      dyScroll: -120,
      timeout: const Duration(seconds: 15),
    );
    await Future<void>.delayed(const Duration(milliseconds: 500));
    await driver.tap(find.byValueKey('login_submit'));

    await driver.waitFor(
      find.byValueKey('chat_add_button'),
      timeout: const Duration(seconds: 60),
    );
    print('LOGIN_OK: $areaCode$phone');
  } catch (e, st) {
    print('LOGIN_FAILED: $e');
    print(st);
    exitCode = 1;
  } finally {
    await driver.close();
  }
}
