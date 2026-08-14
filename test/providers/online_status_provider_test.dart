import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_rust_demo/data/services/online_status_service.dart';
import 'package:flutter_rust_demo/providers/online_status_provider.dart';

void main() {
  group('userOnlineStatusProvider', () {
    test('未收到状态流时为 null，收到后按状态更新 true/false', () async {
      final service = OnlineStatusService.forTesting();
      final container = ProviderContainer(
        overrides: [onlineStatusServiceProvider.overrideWithValue(service)],
      );
      addTearDown(container.dispose);

      final values = <bool?>[];
      final sub = container.listen<bool?>(
        userOnlineStatusProvider('u1'),
        (_, next) => values.add(next),
        fireImmediately: true,
      );

      expect(values, [null]);

      service.applyUserStatusChanged(userId: 'u1', status: 1, platformIds: [1]);
      await pumpEventQueue();
      expect(values, [null, true]);

      service.applyUserStatusChanged(
        userId: 'u1',
        status: 0,
        platformIds: const [],
      );
      await pumpEventQueue();
      expect(values, [null, true, false]);

      sub.close();
      service.dispose();
    });

    test('不同用户状态互不干扰', () async {
      final service = OnlineStatusService.forTesting();
      final container = ProviderContainer(
        overrides: [onlineStatusServiceProvider.overrideWithValue(service)],
      );
      addTearDown(container.dispose);

      final u1Values = <bool?>[];
      final u2Values = <bool?>[];
      final s1 = container.listen<bool?>(
        userOnlineStatusProvider('u1'),
        (_, next) => u1Values.add(next),
        fireImmediately: true,
      );
      final s2 = container.listen<bool?>(
        userOnlineStatusProvider('u2'),
        (_, next) => u2Values.add(next),
        fireImmediately: true,
      );

      service.applyUserStatusChanged(userId: 'u1', status: 1, platformIds: [1]);
      service.applyUserStatusChanged(
        userId: 'u2',
        status: 0,
        platformIds: const [],
      );
      await pumpEventQueue();

      expect(u1Values, [null, true]);
      expect(u2Values, [null, false]);
      expect(container.read(userOnlineStatusProvider('u3')), isNull);
      s1.close();
      s2.close();
      service.dispose();
    });
  });
}
