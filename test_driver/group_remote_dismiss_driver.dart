// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart';

Future<void> _shot(FlutterDriver driver, String name) async {
  final bytes = await driver.screenshot();
  await File('build/group_remote_dismiss_$name.png').writeAsBytes(bytes);
}

Future<bool> _exists(FlutterDriver driver, SerializableFinder finder) async {
  try {
    await driver.waitFor(finder, timeout: const Duration(seconds: 1));
    return true;
  } catch (_) {
    return false;
  }
}

/// 被动解散回归（观察端）：另一端解散群后，本端**不重启**应把该群会话从列表移除。
///
/// 用法：在「被解散」的账号上运行，需 `GROUP_ID`（被解散群的群 ID）。
/// 可选 `WAIT_SECONDS`（默认 60）：服务端通知缺失时，等待重连/增量同步兜底的时间上限。
/// 断言：列表项 `sg_<groupId>` 在等待窗口内消失，并截取前后截图。
Future<void> main() async {
  final groupId = Platform.environment['GROUP_ID'] ?? '';
  if (groupId.isEmpty) {
    print('GROUP_REMOTE_DISMISS_FAILED: 缺少 GROUP_ID');
    return;
  }
  final waitSeconds =
      int.tryParse(Platform.environment['WAIT_SECONDS'] ?? '') ?? 60;

  final driver = await FlutterDriver.connect(
    dartVmServiceUrl: Platform.environment['VM_SERVICE_URL'],
    timeout: const Duration(seconds: 30),
  );
  try {
    // 从会话列表发起观察：若停在深层页面先逐级返回
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

    final item = find.byValueKey('sg_$groupId');
    if (!await _exists(driver, item)) {
      print('GROUP_REMOTE_DISMISS_FAILED: 会话列表未找到 sg_$groupId');
      exitCode = 1;
      return;
    }
    await _shot(driver, '1_before');
    print('GROUP_REMOTE_DISMISS: 已定位 sg_$groupId，等待被动清理（最多 ${waitSeconds}s）');

    final deadline = DateTime.now().add(Duration(seconds: waitSeconds));
    var cleared = false;
    while (DateTime.now().isBefore(deadline)) {
      if (!await _exists(driver, item)) {
        cleared = true;
        break;
      }
      await Future<void>.delayed(const Duration(seconds: 2));
    }

    await Future<void>.delayed(const Duration(seconds: 1));
    await _shot(driver, '2_after');

    if (cleared) {
      print('GROUP_REMOTE_DISMISS_OK: 无需重启已清理 sg_$groupId');
    } else {
      print(
        'GROUP_REMOTE_DISMISS_FAILED: ${waitSeconds}s 内 sg_$groupId 仍残留在会话列表',
      );
      exitCode = 1;
    }
  } catch (e, st) {
    print('GROUP_REMOTE_DISMISS_FAILED: $e');
    print(st);
    await _shot(driver, 'error');
    exitCode = 1;
  } finally {
    await driver.close();
  }
}
