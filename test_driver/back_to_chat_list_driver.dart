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

/// 逐级返回会话列表并截图，用于验证列表状态（如死群是否已清理）。
Future<void> main() async {
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
        await Future<void>.delayed(const Duration(seconds: 2));
      }
    }
    await Future<void>.delayed(const Duration(seconds: 2));
    final bytes = await driver.screenshot();
    await File('build/back_to_list.png').writeAsBytes(bytes);
    print('BACK_TO_LIST_OK');
  } catch (e, st) {
    print('BACK_TO_LIST_FAILED: $e');
    print(st);
    exitCode = 1;
  } finally {
    await driver.close();
  }
}
