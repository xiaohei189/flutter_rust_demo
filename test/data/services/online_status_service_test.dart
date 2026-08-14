import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_rust_demo/data/services/online_status_service.dart';
import 'package:flutter_rust_demo/generated/rust/http/online.dart';

class FakeOnlineStatusClient implements OnlineStatusClient {
  FakeOnlineStatusClient({
    this.failSubscribe = false,
    this.failUnsubscribe = false,
  });

  bool failSubscribe;
  bool failUnsubscribe;
  int subscribeCalls = 0;
  int unsubscribeCalls = 0;
  List<String> lastSubscribeUserIds = [];
  List<String> lastUnsubscribeUserIds = [];

  @override
  Future<List<OnlineStatus>> subscribeUsersStatus({
    required List<String> userIds,
  }) async {
    subscribeCalls++;
    lastSubscribeUserIds = List.of(userIds);
    if (failSubscribe) {
      throw Exception('subscribe failed');
    }
    return userIds
        .map(
          (id) => OnlineStatus(
            userId: id,
            status: 1,
            platformIds: Int32List.fromList([1]),
          ),
        )
        .toList();
  }

  @override
  Future<void> unsubscribeUsersStatus({required List<String> userIds}) async {
    unsubscribeCalls++;
    lastUnsubscribeUserIds = List.of(userIds);
    if (failUnsubscribe) {
      throw Exception('unsubscribe failed');
    }
  }
}

void main() {
  group('OnlineStatusService', () {
    test('相同用户重复 subscribe 只调用一次客户端并保存状态', () async {
      final service = OnlineStatusService.forTesting();
      final client = FakeOnlineStatusClient();
      service.setClientForTest(client);

      await service.subscribe(['u1']);
      await service.subscribe(['u1']);

      expect(client.subscribeCalls, 1);
      expect(client.lastSubscribeUserIds, ['u1']);
      expect(service.statusOf('u1')?.status, 1);
      service.dispose();
    });

    test('subscribe 失败时回滚引用计数且不写入状态', () async {
      final service = OnlineStatusService.forTesting();
      final client = FakeOnlineStatusClient(failSubscribe: true);
      service.setClientForTest(client);

      await service.subscribe(['u1']);

      expect(client.subscribeCalls, 1);
      expect(service.statusOf('u1'), isNull);

      // 恢复后重新订阅应再次发起客户端调用
      client.failSubscribe = false;
      await service.subscribe(['u1']);
      expect(client.subscribeCalls, 2);
      expect(service.statusOf('u1')?.status, 1);
      service.dispose();
    });

    test('unsubscribe 释放引用、移除状态并通知客户端', () async {
      final service = OnlineStatusService.forTesting();
      final client = FakeOnlineStatusClient();
      service.setClientForTest(client);

      await service.subscribe(['u1', 'u2']);
      await service.unsubscribe(['u1']);

      expect(client.unsubscribeCalls, 1);
      expect(client.lastUnsubscribeUserIds, ['u1']);
      expect(service.statusOf('u1'), isNull);
      expect(service.statusOf('u2')?.status, 1);
      service.dispose();
    });

    test('unsubscribe 失败仍清理本地引用和状态', () async {
      final service = OnlineStatusService.forTesting();
      final client = FakeOnlineStatusClient(failUnsubscribe: true);
      service.setClientForTest(client);

      await service.subscribe(['u1']);
      await service.unsubscribe(['u1']);

      expect(service.statusOf('u1'), isNull);
      service.dispose();
    });

    test('清空客户端会清除缓存并通知流', () async {
      final service = OnlineStatusService.forTesting();
      service.setClientForTest(FakeOnlineStatusClient());
      await service.subscribe(['u1']);
      expect(service.statuses, isNotEmpty);

      service.setClientForTest(null);

      expect(service.statuses, isEmpty);
      service.dispose();
    });
  });
}
