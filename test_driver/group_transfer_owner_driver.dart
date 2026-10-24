// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart';

Future<void> _shot(FlutterDriver driver, String name) async {
  final bytes = await driver.screenshot();
  await File('build/group_transfer_$name.png').writeAsBytes(bytes);
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

/// 转让群主回归（进入时需停留在会话列表，账号需为群主）。
///
/// 传 `GROUP_ID` 时直接在已有群上转让；否则新建一次性群后再转让。
/// 验证点：接口 200、我降为成员、对方成为群主。
Future<void> main() async {
  final existingGroupId = Platform.environment['GROUP_ID'] ?? '';
  // 新群主：默认小萌；传 NEW_OWNER_ID 可改（如 9850839580=黄磊，用于被动解散回归）。
  final newOwnerId = Platform.environment['NEW_OWNER_ID'] ?? '2772835353';
  final driver = await FlutterDriver.connect(
    dartVmServiceUrl: Platform.environment['VM_SERVICE_URL'],
    timeout: const Duration(seconds: 30),
  );
  try {
    await driver.setTextEntryEmulation(enabled: true);

    if (existingGroupId.isEmpty) {
      // 新建一次性群
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
      await driver.tap(find.byValueKey('contact_picker_friend_9850839580'));
      await driver.tap(find.text('确定'));
      await driver.tap(find.byValueKey('create_group_submit'));
      await driver.waitFor(
        find.byTooltip('更多设置'),
        timeout: const Duration(seconds: 25),
      );
      await Future<void>.delayed(const Duration(seconds: 2));
      await driver.tap(find.byTooltip('更多设置'));
    } else {
      // 进入已有群 → 更多设置
      await driver.tap(
        find.byValueKey('sg_$existingGroupId'),
        timeout: const Duration(seconds: 15),
      );
      await driver.tap(find.byTooltip('更多设置'));
    }

    // 群信息 → 转让群主
    await driver.tap(find.byValueKey('chat_settings_group_info'));
    await driver.waitFor(
      find.byValueKey('group_info_name'),
      timeout: const Duration(seconds: 15),
    );
    await _scrollTo(driver, find.byValueKey('group_info_transfer'));
    await _shot(driver, '1_before');
    await driver.tap(find.byValueKey('group_info_transfer'));
    await driver.waitFor(
      find.byValueKey('transfer_owner_$newOwnerId'),
      timeout: const Duration(seconds: 10),
    );
    await _shot(driver, '2_picker');
    await driver.tap(find.byValueKey('transfer_owner_$newOwnerId'));
    await Future<void>.delayed(const Duration(seconds: 6));
    await _shot(driver, '3_transferred');

    // 重新进入群信息，确认角色已切换（我=成员、小萌=群主）
    await driver.tap(find.byValueKey('group_info_back'));
    await Future<void>.delayed(const Duration(seconds: 2));
    await driver.tap(find.byValueKey('chat_settings_group_info'));
    await driver.waitFor(
      find.byValueKey('group_info_name'),
      timeout: const Duration(seconds: 15),
    );
    await Future<void>.delayed(const Duration(seconds: 3));
    await _shot(driver, '4_roles_after');

    print('GROUP_TRANSFER_OK');
  } catch (e, st) {
    print('GROUP_TRANSFER_FAILED: $e');
    print(st);
    await _shot(driver, 'error');
    exitCode = 1;
  } finally {
    await driver.close();
  }
}
