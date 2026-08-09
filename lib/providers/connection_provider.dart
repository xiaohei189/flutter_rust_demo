import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ui/core/view_models/connection_view_model.dart';

/// 连接状态 Provider
final connectionProvider = StateNotifierProvider<ConnectionNotifier, AppConnectionState>((ref) {
  return ConnectionNotifier(ref);
});

/// 是否已连接 Provider（便捷访问）
final isConnectedProvider = Provider<bool>((ref) {
  return ref.watch(connectionProvider).isConnected;
});
