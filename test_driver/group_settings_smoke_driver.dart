// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart';

Future<void> _shot(FlutterDriver driver, String name) async {
  final bytes = await driver.screenshot();
  await File('build/group_settings_$name.png').writeAsBytes(bytes);
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

Future<void> _scrollTo(
  FlutterDriver driver,
  SerializableFinder item, {
  double dyScroll = -300,
}) async {
  if (await _exists(driver, item)) return;
  await driver.scrollUntilVisible(
    find.byType('ListView'),
    item,
    dyScroll: dyScroll,
    timeout: const Duration(seconds: 20),
  );
}

/// 群设置冒烟：群公告编辑、群昵称修改、群二维码展示。
///
/// 需 `GROUP_ID`，进入时停留在会话列表，账号需在该群内。
Future<void> main() async {
  final groupId = Platform.environment['GROUP_ID'] ?? '658698100';
  final driver = await FlutterDriver.connect(
    dartVmServiceUrl: Platform.environment['VM_SERVICE_URL'],
    timeout: const Duration(seconds: 30),
  );
  try {
    await driver.setTextEntryEmulation(enabled: true);

    // 会话列表 → 群聊 → 设置页
    if (await _exists(driver, find.byValueKey('sg_$groupId'))) {
      await driver.tap(find.byValueKey('sg_$groupId'));
    }
    await driver.tap(
      find.byTooltip('更多设置'),
      timeout: const Duration(seconds: 10),
    );

    // 1) 群公告
    await _scrollTo(driver, find.text('群公告'), dyScroll: 200);
    await driver.tap(find.text('群公告'));
    await driver.waitFor(
      find.text('编辑群公告'),
      timeout: const Duration(seconds: 10),
    );
    await driver.tap(find.byType('TextField'));
    await driver.enterText('群公告验证：每周五 17:00 例会');
    await driver.tap(find.text('保存'));
    await Future<void>.delayed(const Duration(seconds: 5));
    await _shot(driver, '1_announcement');

    // 2) 群昵称
    await _scrollTo(driver, find.text('群昵称'));
    await driver.tap(find.text('群昵称'));
    await driver.waitFor(
      find.text('修改群昵称'),
      timeout: const Duration(seconds: 10),
    );
    await driver.tap(find.byType('TextField'));
    await driver.enterText('我-群昵称验证');
    await driver.tap(find.text('保存'));
    await Future<void>.delayed(const Duration(seconds: 5));
    await _shot(driver, '2_nickname');

    // 3) 群二维码
    await _scrollTo(driver, find.byValueKey('chat_settings_group_info'), dyScroll: 300);
    await driver.tap(find.byValueKey('chat_settings_group_info'));
    await driver.waitFor(
      find.byValueKey('group_info_name'),
      timeout: const Duration(seconds: 15),
    );
    await _scrollTo(driver, find.text('群二维码'));
    await driver.tap(find.text('群二维码'));
    await Future<void>.delayed(const Duration(seconds: 3));
    await _shot(driver, '3_qrcode');

    print('GROUP_SETTINGS_OK');
  } catch (e, st) {
    print('GROUP_SETTINGS_FAILED: $e');
    print(st);
    await _shot(driver, 'error');
    exitCode = 1;
  } finally {
    await driver.close();
  }
}
