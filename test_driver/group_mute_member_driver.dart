// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart';

Future<void> _shot(FlutterDriver driver, String name) async {
  final bytes = await driver.screenshot();
  await File('build/group_mute_$name.png').writeAsBytes(bytes);
}

/// 单人禁言 / 取消禁言回归（进入时需停留在会话列表）。
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
    await driver.tap(find.byTooltip('更多设置'));
    await driver.tap(find.byValueKey('chat_settings_group_info'));
    await driver.waitFor(
      find.byValueKey('group_info_name'),
      timeout: const Duration(seconds: 15),
    );

    // 禁言黄磊 1 分钟
    await driver.tap(find.byValueKey('group_member_9850839580'));
    await driver.tap(find.byValueKey('group_member_action_mute'));
    await driver.waitFor(
      find.text('1 分钟'),
      timeout: const Duration(seconds: 10),
    );
    await driver.tap(find.text('1 分钟'));
    await Future<void>.delayed(const Duration(seconds: 6));
    await _shot(driver, '1_muted');

    // 取消禁言
    await driver.tap(find.byValueKey('group_member_9850839580'));
    await driver.tap(find.byValueKey('group_member_action_unmute'));
    await Future<void>.delayed(const Duration(seconds: 6));
    await _shot(driver, '2_unmuted');

    print('GROUP_MUTE_MEMBER_OK');
  } catch (e, st) {
    print('GROUP_MUTE_MEMBER_FAILED: $e');
    print(st);
    await _shot(driver, 'error');
    exitCode = 1;
  } finally {
    await driver.close();
  }
}
