// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart';

Future<void> _shot(FlutterDriver driver, String name) async {
  final bytes = await driver.screenshot();
  await File('build/group_rename_$name.png').writeAsBytes(bytes);
}

/// 群改名 → 返回设置页/会话列表，验证群名是否同步（进入时需停留在会话列表）。
Future<void> main() async {
  final driver = await FlutterDriver.connect(
    dartVmServiceUrl: Platform.environment['VM_SERVICE_URL'],
    timeout: const Duration(seconds: 30),
  );
  try {
    await driver.setTextEntryEmulation(enabled: true);
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
      find.byValueKey('group_info_name'),
      timeout: const Duration(seconds: 15),
    );

    // 改名
    await driver.tap(find.byValueKey('group_info_name'));
    await driver.tap(find.byType('TextField'));
    await driver.enterText('小萌、黄磊-改名同步验证');
    await driver.tap(find.text('保存'));
    await Future<void>.delayed(const Duration(seconds: 8));
    await _shot(driver, '1_renamed');

    // 返回设置页 → 会话 → 会话列表
    await driver.tap(find.byValueKey('group_info_back'));
    await Future<void>.delayed(const Duration(seconds: 3));
    await _shot(driver, '2_settings');
    await driver.tap(find.byValueKey('chat_settings_back'));
    await Future<void>.delayed(const Duration(seconds: 2));
    await driver.tap(find.byValueKey('chat_detail_back'));
    await Future<void>.delayed(const Duration(seconds: 3));
    await _shot(driver, '3_list');

    print('GROUP_RENAME_OK');
  } catch (e, st) {
    print('GROUP_RENAME_FAILED: $e');
    print(st);
    await _shot(driver, 'error');
    exitCode = 1;
  } finally {
    await driver.close();
  }
}
