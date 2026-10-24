// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart';

Future<bool> _exists(FlutterDriver driver, SerializableFinder finder) async {
  try {
    await driver.waitFor(finder, timeout: const Duration(seconds: 1));
    return true;
  } catch (_) {
    return false;
  }
}

/// 打开指定群的群信息页并截图（需 `GROUP_ID`）。
Future<void> main() async {
  final groupId = Platform.environment['GROUP_ID'] ?? '';
  final tag = Platform.environment['TAG'] ?? 'info';
  if (groupId.isEmpty) {
    print('GROUP_INFO_FAILED: 缺少 GROUP_ID');
    return;
  }
  final driver = await FlutterDriver.connect(
    dartVmServiceUrl: Platform.environment['VM_SERVICE_URL'],
    timeout: const Duration(seconds: 30),
  );
  try {
    for (final key in <String>[
      'group_info_back',
      'chat_settings_back',
      'chat_detail_back',
    ]) {
      final finder = find.byValueKey(key);
      if (await _exists(driver, finder)) {
        await driver.tap(finder);
        await Future<void>.delayed(const Duration(seconds: 1));
      }
    }
    if (await _exists(driver, find.byValueKey('sg_$groupId'))) {
      await driver.tap(find.byValueKey('sg_$groupId'));
    }
    await driver.tap(find.byTooltip('更多设置'));
    await driver.tap(find.byValueKey('chat_settings_group_info'));
    await driver.waitFor(
      find.byValueKey('group_info_name'),
      timeout: const Duration(seconds: 15),
    );
    await Future<void>.delayed(const Duration(seconds: 3));
    final bytes = await driver.screenshot();
    await File('build/group_info_$tag.png').writeAsBytes(bytes);
    print('GROUP_INFO_OK');
  } catch (e, st) {
    print('GROUP_INFO_FAILED: $e');
    print(st);
    exitCode = 1;
  } finally {
    await driver.close();
  }
}
