// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart';

Future<void> _shot(FlutterDriver driver, String name) async {
  final bytes = await driver.screenshot();
  await File('build/group_dismiss_$name.png').writeAsBytes(bytes);
}

Future<void> _scrollTo(FlutterDriver driver, SerializableFinder item) async {
  try {
    await driver.waitFor(item, timeout: const Duration(seconds: 2));
    return;
  } catch (_) {}
  await driver.scrollUntilVisible(
    find.byType('ListView'),
    item,
    dyScroll: -300,
    timeout: const Duration(seconds: 20),
  );
}

Future<bool> _exists(FlutterDriver driver, SerializableFinder finder) async {
  try {
    await driver.waitFor(finder, timeout: const Duration(seconds: 1));
    return true;
  } catch (_) {
    return false;
  }
}

/// 解散群回归：新建一次性群 → 解散（进入时需停留在会话列表）。
Future<void> main() async {
  final driver = await FlutterDriver.connect(
    dartVmServiceUrl: Platform.environment['VM_SERVICE_URL'],
    timeout: const Duration(seconds: 30),
  );
  try {
    await driver.setTextEntryEmulation(enabled: true);

    // 若从深层页面进入，先逐级回到会话列表
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

    // 新建一次性群（只带小萌）
    if (!await _exists(driver, find.byValueKey('chat_add_menu_create_group'))) {
      await driver.tap(
        find.byValueKey('chat_add_button'),
        timeout: const Duration(seconds: 10),
      );
    }
    await driver.waitFor(
      find.byValueKey('chat_add_menu_create_group'),
      timeout: const Duration(seconds: 10),
    );
    await driver.tap(find.byValueKey('chat_add_menu_create_group'));
    await driver.tap(find.byValueKey('create_group_friends_entry'));
    await driver.tap(find.byValueKey('contact_picker_friend_2772835353'));
    await driver.tap(find.text('确定'));
    await driver.tap(find.byValueKey('create_group_submit'));
    await driver.waitFor(
      find.byTooltip('更多设置'),
      timeout: const Duration(seconds: 25),
    );
    await Future<void>.delayed(const Duration(seconds: 2));
    await _shot(driver, '1_created');

    // 群信息 → 管理 → 解散群组
    await driver.tap(find.byTooltip('更多设置'));
    await driver.tap(find.byValueKey('chat_settings_group_info'));
    await driver.waitFor(
      find.byValueKey('group_info_name'),
      timeout: const Duration(seconds: 15),
    );
    await _scrollTo(driver, find.byValueKey('group_info_manage'));
    await driver.tap(find.byValueKey('group_info_manage'));
    await driver.waitFor(
      find.byValueKey('group_manage_dismiss_action'),
      timeout: const Duration(seconds: 10),
    );
    await driver.tap(find.byValueKey('group_manage_dismiss_action'));
    await driver.waitFor(
      find.text('解散'),
      timeout: const Duration(seconds: 10),
    );
    await _shot(driver, '2_dismiss_dialog');
    await driver.tap(find.text('解散'));
    await Future<void>.delayed(const Duration(seconds: 6));
    await _shot(driver, '3_dismissed');

    print('GROUP_DISMISS_OK');
  } catch (e, st) {
    print('GROUP_DISMISS_FAILED: $e');
    print(st);
    await _shot(driver, 'error');
    exitCode = 1;
  } finally {
    await driver.close();
  }
}
