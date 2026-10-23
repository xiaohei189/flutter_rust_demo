// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart';

Future<void> _shot(FlutterDriver driver, String name) async {
  final bytes = await driver.screenshot();
  await File('build/group_manage_$name.png').writeAsBytes(bytes);
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

Future<void> main() async {
  final driver = await FlutterDriver.connect(
    dartVmServiceUrl: Platform.environment['VM_SERVICE_URL'],
    timeout: const Duration(seconds: 30),
  );
  try {
    await driver.setTextEntryEmulation(enabled: true);

    // 进入测试群 → 更多设置 → 群信息
    await driver.tap(find.byValueKey('sg_658698100'));
    await driver.tap(find.byTooltip('更多设置'));
    await driver.tap(find.byValueKey('chat_settings_group_info'));
    await driver.waitFor(
      find.byValueKey('group_info_name'),
      timeout: const Duration(seconds: 15),
    );
    await _shot(driver, '1_info');

    // 修改群名
    await driver.tap(find.byValueKey('group_info_name'));
    await driver.tap(find.byType('TextField'));
    await driver.enterText('小萌、黄磊-管理验证');
    await driver.tap(find.text('保存'));
    await Future<void>.delayed(const Duration(seconds: 2));
    await _shot(driver, '2_renamed');

    // 修改群描述
    await driver.tap(find.byValueKey('group_info_description'));
    await driver.tap(find.byType('TextField'));
    await driver.enterText('群管理回归验证');
    await driver.tap(find.text('保存'));
    // 等 SnackBar 消失，避免它盖住底部“全员禁言”行。
    await Future<void>.delayed(const Duration(seconds: 5));

    // 全员禁言 / 解除
    await _scrollTo(driver, find.byValueKey('group_info_manage'));
    await driver.tap(find.byValueKey('group_info_manage'));
    await driver.tap(find.text('全员禁言'));
    await Future<void>.delayed(const Duration(seconds: 2));
    await _shot(driver, '3_mute_all');
    await _scrollTo(driver, find.byValueKey('group_info_manage'));
    await driver.tap(find.byValueKey('group_info_manage'));
    await driver.tap(find.text('解除全员禁言'));
    await Future<void>.delayed(const Duration(seconds: 5));

    // 回设置页邀请杨帆
    await driver.tap(find.pageBack());
    await driver.waitFor(
      find.byValueKey('chat_settings_add_member'),
      timeout: const Duration(seconds: 15),
    );
    await driver.tap(find.byValueKey('chat_settings_add_member'));
    await driver.waitFor(
      find.byValueKey('invite_member_4508967079'),
      timeout: const Duration(seconds: 15),
    );
    await driver.tap(find.byValueKey('invite_member_4508967079'));
    await driver.tap(find.text('确定 (1)'));
    await Future<void>.delayed(const Duration(seconds: 5));
    await _shot(driver, '4_invited');

    // 再进群信息，踢出杨帆
    await driver.tap(find.byValueKey('chat_settings_group_info'));
    await driver.waitFor(
      find.byValueKey('group_info_name'),
      timeout: const Duration(seconds: 15),
    );
    await _scrollTo(driver, find.byValueKey('group_member_4508967079'));
    await driver.tap(find.byValueKey('group_member_4508967079'));
    await driver.waitFor(
      find.text('踢出群聊'),
      timeout: const Duration(seconds: 10),
    );
    await driver.tap(find.text('踢出群聊'));
    await driver.waitFor(
      find.text('踢出'),
      timeout: const Duration(seconds: 10),
    );
    await driver.tap(find.text('踢出'));
    await Future<void>.delayed(const Duration(seconds: 3));
    await _shot(driver, '5_kicked');

    print('GROUP_MANAGE_OK');
  } catch (e, st) {
    print('GROUP_MANAGE_FAILED: $e');
    print(st);
    await _shot(driver, 'error');
    exitCode = 1;
  } finally {
    await driver.close();
  }
}
