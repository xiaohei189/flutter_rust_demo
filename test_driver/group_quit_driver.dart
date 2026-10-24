// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart';

Future<void> _shot(FlutterDriver driver, String name) async {
  final bytes = await driver.screenshot();
  await File('build/group_quit_$name.png').writeAsBytes(bytes);
}

Future<bool> _exists(FlutterDriver driver, SerializableFinder finder) async {
  try {
    await driver.waitFor(finder, timeout: const Duration(seconds: 1));
    return true;
  } catch (_) {
    return false;
  }
}

/// 退出群组回归：需 `GROUP_ID`，账号在该群内且不是群主。
Future<void> main() async {
  final groupId = Platform.environment['GROUP_ID'] ?? '';
  if (groupId.isEmpty) {
    print('GROUP_QUIT_FAILED: 缺少 GROUP_ID');
    return;
  }
  final driver = await FlutterDriver.connect(
    dartVmServiceUrl: Platform.environment['VM_SERVICE_URL'],
    timeout: const Duration(seconds: 30),
  );
  try {
    // 回到会话列表
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

    await driver.tap(
      find.byValueKey('sg_$groupId'),
      timeout: const Duration(seconds: 15),
    );
    await driver.tap(find.byTooltip('更多设置'));
    await driver.scrollUntilVisible(
      find.byType('ListView'),
      find.text('退出群组'),
      dyScroll: -300,
      timeout: const Duration(seconds: 20),
    );
    await _shot(driver, '1_before');
    await driver.tap(find.text('退出群组'));
    await driver.waitFor(
      find.text('退出'),
      timeout: const Duration(seconds: 10),
    );
    await _shot(driver, '2_dialog');
    await driver.tap(find.text('退出'));
    await Future<void>.delayed(const Duration(seconds: 6));
    await _shot(driver, '3_after');

    print('GROUP_QUIT_OK');
  } catch (e, st) {
    print('GROUP_QUIT_FAILED: $e');
    print(st);
    await _shot(driver, 'error');
    exitCode = 1;
  } finally {
    await driver.close();
  }
}
