import 'dart:async';
import 'dart:typed_data';

import '../src/rust/ffi/client.dart' as fb;
import '../src/rust/http/online.dart' show OnlineStatus;
import '../utils/app_logger.dart';

class OnlineStatusService {
  static final OnlineStatusService instance = OnlineStatusService._internal();

  final _statusesController =
      StreamController<Map<String, OnlineStatus>>.broadcast();
  final Map<String, OnlineStatus> _statuses = {};
  final Map<String, int> _refCounts = {};
  fb.OpenImBridgeClient? _client;

  OnlineStatusService._internal();

  Stream<Map<String, OnlineStatus>> get statusesStream =>
      _statusesController.stream;

  Map<String, OnlineStatus> get statuses => Map.unmodifiable(_statuses);

  OnlineStatus? statusOf(String userId) => _statuses[userId];

  void setClient(fb.OpenImBridgeClient? client) {
    _client = client;
    if (client == null) {
      _statuses.clear();
      _refCounts.clear();
      _notify();
    }
  }

  Future<void> subscribe(List<String> userIds) async {
    final ids = userIds.where((id) => id.isNotEmpty).toSet().toList();
    if (ids.isEmpty) return;

    final newIds = <String>[];
    for (final id in ids) {
      final count = _refCounts[id] ?? 0;
      _refCounts[id] = count + 1;
      if (count == 0) newIds.add(id);
    }
    if (newIds.isEmpty) return;

    final client = _client;
    if (client == null) return;
    try {
      final statuses = await client.subscribeUsersStatus(userIds: newIds);
      for (final status in statuses) {
        _statuses[status.userId] = status;
      }
      _notify();
    } catch (e) {
      appLog.w('[OnlineStatus] 订阅失败: $e');
      for (final id in newIds) {
        final count = (_refCounts[id] ?? 0) - 1;
        if (count <= 0) {
          _refCounts.remove(id);
        } else {
          _refCounts[id] = count;
        }
      }
    }
  }

  Future<void> unsubscribe(List<String> userIds) async {
    final ids = userIds.where((id) => id.isNotEmpty).toSet().toList();
    if (ids.isEmpty) return;

    final releaseIds = <String>[];
    for (final id in ids) {
      final count = (_refCounts[id] ?? 1) - 1;
      if (count <= 0) {
        _refCounts.remove(id);
        releaseIds.add(id);
      } else {
        _refCounts[id] = count;
      }
    }
    if (releaseIds.isEmpty) return;

    final client = _client;
    if (client != null) {
      try {
        await client.unsubscribeUsersStatus(userIds: releaseIds);
      } catch (e) {
        appLog.w('[OnlineStatus] 退订失败: $e');
      }
    }
    for (final id in releaseIds) {
      _statuses.remove(id);
    }
    _notify();
  }

  void applyUserStatusChanged({
    required String userId,
    required int status,
    required List<int> platformIds,
  }) {
    _statuses[userId] = OnlineStatus(
      userId: userId,
      status: status,
      platformIds: Int32List.fromList(platformIds),
    );
    _notify();
  }

  void _notify() {
    if (!_statusesController.isClosed) {
      _statusesController.add(statuses);
    }
  }
}
