import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/services/online_status_service.dart';
import '../generated/rust/http/online.dart' show OnlineStatus;

final onlineStatusServiceProvider = Provider<OnlineStatusService>(
  (ref) => OnlineStatusService.instance,
);

final onlineStatusStreamProvider = StreamProvider<Map<String, OnlineStatus>>(
  (ref) => ref.watch(onlineStatusServiceProvider).statusesStream,
);

/// 用户在线状态。watch 状态流以保持响应式：
/// - `null`:未知(尚未订阅/订阅未完成),UI 不应显示"离线"
/// - `false`/`true`:离线/在线
final userOnlineStatusProvider = Provider.family<bool?, String>((ref, userId) {
  final statuses = ref.watch(onlineStatusStreamProvider).value;
  final status = statuses?[userId];
  return status == null ? null : status.status == 1;
});
