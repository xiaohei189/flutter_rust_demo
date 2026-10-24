// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart';

Future<void> _shot(FlutterDriver driver, String name) async {
  final bytes = await driver.screenshot();
  await File('build/group_kick_$name.png').writeAsBytes(bytes);
}

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

/// 踢出成员回归：可从会话列表 / 群设置页 / 群信息页任一处进入。
Future<void> main() async {
  final driver = await FlutterDriver.connect(
    dartVmServiceUrl: Platform.environment['VM_SERVICE_URL'],
    timeout: const Duration(seconds: 30),
  );
  try {
    // 导航到群设置页
    if (await _exists(driver, find.byValueKey('sg_658698100'))) {
      await driver.tap(find.byValueKey('sg_658698100'));
      await driver.tap(find.byTooltip('更多设置'));
    }

    // 导航到群信息页
    if (!await _exists(driver, find.byValueKey('group_info_name'))) {
      await driver.scrollUntilVisible(
        find.byType('ListView'),
        find.byValueKey('chat_settings_group_info'),
        dyScroll: 300,
        timeout: const Duration(seconds: 20),
      );
      await driver.tap(find.byValueKey('chat_settings_group_info'));
      await driver.waitFor(
        find.byValueKey('group_info_name'),
        timeout: const Duration(seconds: 15),
      );
    }

    // 群资料应从服务端刷新（此前恒为「暂无描述」）
    await Future<void>.delayed(const Duration(seconds: 2));
    await _shot(driver, '1_info');

    // 踢出杨帆
    await driver.scrollUntilVisible(
      find.byType('ListView'),
      find.byValueKey('group_member_4508967079'),
      dyScroll: -300,
      timeout: const Duration(seconds: 20),
    );
    await _shot(driver, '2_member_list');
    await driver.tap(find.byValueKey('group_member_4508967079'));
    await driver.waitFor(
      find.byValueKey('group_member_action_kick'),
      timeout: const Duration(seconds: 10),
    );
    await driver.tap(find.byValueKey('group_member_action_kick'));
    await driver.waitFor(
      find.text('踢出'),
      timeout: const Duration(seconds: 10),
    );
    await _shot(driver, '3_kick_dialog');
    await driver.tap(find.text('踢出'));
    await Future<void>.delayed(const Duration(seconds: 5));
    await _shot(driver, '4_kicked');

    print('GROUP_KICK_OK');
  } catch (e, st) {
    print('GROUP_KICK_FAILED: $e');
    print(st);
    await _shot(driver, 'error');
    exitCode = 1;
  } finally {
    await driver.close();
  }
}
