// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart';

Future<void> _shot(FlutterDriver driver, String name) async {
  final bytes = await driver.screenshot();
  await File('build/group_send_$name.png').writeAsBytes(bytes);
}

Future<bool> _exists(FlutterDriver driver, SerializableFinder finder) async {
  try {
    await driver.waitFor(finder, timeout: const Duration(seconds: 1));
    return true;
  } catch (_) {
    return false;
  }
}

/// 在指定群里发一条消息（需 `GROUP_ID`），用于让群成员侧生成会话。
Future<void> main() async {
  final groupId = Platform.environment['GROUP_ID'] ?? '';
  final text = Platform.environment['TEXT'] ?? '群主转让后消息验证';
  if (groupId.isEmpty) {
    print('GROUP_SEND_FAILED: 缺少 GROUP_ID');
    return;
  }
  final driver = await FlutterDriver.connect(
    dartVmServiceUrl: Platform.environment['VM_SERVICE_URL'],
    timeout: const Duration(seconds: 30),
  );
  try {
    await driver.setTextEntryEmulation(enabled: true);
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
    await driver.tap(find.byType('TextField'));
    await driver.enterText(text);
    await Future<void>.delayed(const Duration(seconds: 1));
    await driver.tap(find.byTooltip('发送'));
    await Future<void>.delayed(const Duration(seconds: 4));
    await _shot(driver, 'sent');

    print('GROUP_SEND_OK');
  } catch (e, st) {
    print('GROUP_SEND_FAILED: $e');
    print(st);
    await _shot(driver, 'error');
    exitCode = 1;
  } finally {
    await driver.close();
  }
}
