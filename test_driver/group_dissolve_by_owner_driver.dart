// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart';

Future<void> _shot(FlutterDriver driver, String name) async {
  final bytes = await driver.screenshot();
  await File('build/group_dissolve_$name.png').writeAsBytes(bytes);
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

/// 由新群主（第二账号）解散群，用于验证转让后的权限与双方列表清理。
///
/// 需传 `GROUP_ID`（会话 ID 优先）与可选 `GROUP_NAME`，进入时停留在会话列表。
Future<void> main() async {
  final groupId = Platform.environment['GROUP_ID'] ?? '';
  final groupName = Platform.environment['GROUP_NAME'] ?? '';
  if (groupId.isEmpty && groupName.isEmpty) {
    print('GROUP_DISSOLVE_FAILED: 缺少 GROUP_ID/GROUP_NAME');
    return;
  }
  final driver = await FlutterDriver.connect(
    dartVmServiceUrl: Platform.environment['VM_SERVICE_URL'],
    timeout: const Duration(seconds: 30),
  );
  try {
    // 回到会话列表：群内/群信息页同样能复用本脚本。
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

    // 优先直接点会话；新群未产生消息时成员侧可能还没有会话，退回「通讯录 → 我的群组」。
    if (groupId.isNotEmpty &&
        await _exists(driver, find.byValueKey('sg_$groupId'))) {
      await driver.tap(find.byValueKey('sg_$groupId'));
    } else {
      await driver.tap(find.text('通讯录'));
      await driver.waitFor(
        find.text('我的群组'),
        timeout: const Duration(seconds: 15),
      );
      await driver.tap(find.text('我的群组'));
      await driver.waitFor(
        find.text(groupName),
        timeout: const Duration(seconds: 15),
      );
      await driver.tap(find.text(groupName));
    }
    await driver.tap(find.byTooltip('更多设置'));
    await driver.tap(find.byValueKey('chat_settings_group_info'));
    await driver.waitFor(
      find.byValueKey('group_info_name'),
      timeout: const Duration(seconds: 15),
    );
    await Future<void>.delayed(const Duration(seconds: 2));
    await _shot(driver, '1_new_owner_info');

    await _scrollTo(driver, find.byValueKey('group_info_manage'));
    await driver.tap(find.byValueKey('group_info_manage'));
    await driver.waitFor(
      find.byValueKey('group_manage_dismiss_action'),
      timeout: const Duration(seconds: 10),
    );
    // 大字/大缩放的设备上弹窗内容会滚动，「解散群组」可能在首屏之外，先滚到底。
    try {
      await driver.scroll(
        find.byType('SingleChildScrollView'),
        0,
        -200,
        const Duration(milliseconds: 300),
      );
      await Future<void>.delayed(const Duration(milliseconds: 500));
    } catch (_) {}
    await driver.tap(find.byValueKey('group_manage_dismiss_action'));
    await driver.waitFor(
      find.text('解散'),
      timeout: const Duration(seconds: 10),
    );
    await driver.tap(find.text('解散'));
    await Future<void>.delayed(const Duration(seconds: 6));
    await _shot(driver, '2_dissolved');

    print('GROUP_DISSOLVE_OK');
  } catch (e, st) {
    print('GROUP_DISSOLVE_FAILED: $e');
    print(st);
    await _shot(driver, 'error');
    exitCode = 1;
  } finally {
    await driver.close();
  }
}
