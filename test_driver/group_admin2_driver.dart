// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart';

Future<void> _shot(FlutterDriver driver, String name) async {
  final bytes = await driver.screenshot();
  await File('build/group_admin2_$name.png').writeAsBytes(bytes);
}

Future<void> main() async {
  final driver = await FlutterDriver.connect(
    dartVmServiceUrl: Platform.environment['VM_SERVICE_URL'],
    timeout: const Duration(seconds: 30),
  );
  try {
    await driver.tap(
      find.byValueKey('sg_658698100'),
      timeout: const Duration(seconds: 10),
    );
    await driver.tap(
      find.byTooltip('更多设置'),
      timeout: const Duration(seconds: 10),
    );
    await driver.tap(
      find.byValueKey('chat_settings_group_info'),
      timeout: const Duration(seconds: 10),
    );
    await driver.waitFor(
      find.byValueKey('group_member_9850839580'),
      timeout: const Duration(seconds: 15),
    );
    await driver.tap(
      find.byValueKey('group_member_9850839580'),
      timeout: const Duration(seconds: 10),
    );
    await driver.tap(
      find.byValueKey('group_member_action_admin'),
      timeout: const Duration(seconds: 10),
    );
    await Future<void>.delayed(const Duration(seconds: 3));
    await _shot(driver, '1_set');

    await driver.tap(
      find.byValueKey('group_member_9850839580'),
      timeout: const Duration(seconds: 10),
    );
    await driver.tap(
      find.byValueKey('group_member_action_admin'),
      timeout: const Duration(seconds: 10),
    );
    await Future<void>.delayed(const Duration(seconds: 3));
    await _shot(driver, '2_unset');
    print('GROUP_ADMIN2_OK');
  } catch (e, st) {
    print('GROUP_ADMIN2_FAILED: $e');
    print(st);
    await _shot(driver, 'error');
    exitCode = 1;
  } finally {
    await driver.close();
  }
}
