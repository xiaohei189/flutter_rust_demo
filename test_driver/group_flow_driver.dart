// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart';

Future<void> _shot(FlutterDriver driver, String name) async {
  final bytes = await driver.screenshot();
  await File('build/group_verify_$name.png').writeAsBytes(bytes);
}

Future<void> main() async {
  final driver = await FlutterDriver.connect();
  try {
    await driver.setTextEntryEmulation(enabled: true);

    // 1. 从会话列表进入创建群
    await driver.tap(find.byValueKey('chat_add_button'));
    await driver.tap(find.byValueKey('chat_add_menu_create_group'));
    await driver.tap(find.byValueKey('create_group_friends_entry'));

    // 2. 选择两个好友：小萌、黄磊
    await driver.tap(find.byValueKey('contact_picker_friend_2772835353'));
    await driver.tap(find.byValueKey('contact_picker_friend_9850839580'));
    await driver.tap(find.text('确定'));

    // 3. 创建群（成功后应自动进入新群聊）
    await driver.tap(find.byValueKey('create_group_submit'));
    await driver.waitFor(find.byTooltip('展开编辑'), timeout: const Duration(seconds: 20));
    await _shot(driver, '1_group_chat');

    // 4. 群内发一条消息
    await driver.tap(find.byType('TextField'));
    await driver.enterText('群创建与群内消息验证');
    await Future<void>.delayed(const Duration(seconds: 1));
    await driver.tap(find.byTooltip('发送'));
    await driver.waitFor(find.text('群创建与群内消息验证'), timeout: const Duration(seconds: 10));
    await _shot(driver, '2_message_sent');

    // 5. 验证群内 @所有人 入口
    await driver.tap(find.byTooltip('@ 提及'));
    await driver.waitFor(find.text('所有人'), timeout: const Duration(seconds: 10));
    await _shot(driver, '3_at_all');

    print('GROUP_FLOW_OK');
  } catch (e, st) {
    print('GROUP_FLOW_FAILED: $e');
    print(st);
    await _shot(driver, 'error');
    exitCode = 1;
  } finally {
    await driver.close();
  }
}
