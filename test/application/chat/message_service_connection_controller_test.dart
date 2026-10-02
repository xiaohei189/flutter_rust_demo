import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_rust_demo/application/chat/message_service_connection_controller.dart';
import 'package:flutter_rust_demo/data/services/im_client.dart';
import 'package:flutter_rust_demo/providers/im_providers.dart';
import 'package:flutter_rust_demo/providers/online_status_provider.dart';
import 'package:flutter_rust_demo/ui/chat/providers/message_service_provider.dart';

void main() {
  test('登出清理不会卡在永不完成的订阅 cancel 上（frb 事件流静默时）', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    // 本用例不涉及真实 Rust 客户端：close() 只做本地清理后立即返回。
    ImClient.instance.setClient(null);

    final service = container.read(messageServiceProvider.notifier);
    final controller = MessageServiceConnectionController(
      service,
      container.read(connectionServiceProvider),
      container.read(onlineStatusServiceProvider),
      container.read(imClientProvider),
      container.read(navigationServiceProvider),
    );

    // 复刻 frb 事件流的取消语义：底层 ReceivePort 静默（登出后 Rust 不再推事件）
    // 且未关闭时，cancel() 返回的 future 不会完成，只有新事件或 port.close 才返回。
    // 本用例故意不 close 这个 StreamController——"port 一直开着"正是死锁的前提。
    // ignore: close_sinks
    final hanging = StreamController<int>();
    hanging.onCancel = () => Completer<void>().future;
    service.subscriptions.add(hanging.stream.listen((_) {}));

    final stopwatch = Stopwatch()..start();
    await controller.disconnect().timeout(const Duration(seconds: 3));
    stopwatch.stop();

    expect(
      service.subscriptions,
      isEmpty,
      reason: '订阅引用必须被摘掉，否则下一次初始化会再次卡在"关闭已有客户端"',
    );
    expect(
      stopwatch.elapsed,
      lessThan(const Duration(seconds: 1)),
      reason: '取消订阅必须限时等待，不能死等 frb 事件流的 cancel',
    );
  });
}
