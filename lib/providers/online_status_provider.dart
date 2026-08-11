import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/services/online_status_service.dart';
import '../generated/rust/http/online.dart' show OnlineStatus;

final onlineStatusStreamProvider = StreamProvider<Map<String, OnlineStatus>>(
  (ref) => OnlineStatusService.instance.statusesStream,
);

final userOnlineStatusProvider = Provider.family<bool?, String>((ref, userId) {
  final status = OnlineStatusService.instance.statusOf(userId);
  return status?.status == 1;
});
