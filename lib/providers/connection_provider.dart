import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/services/connection_service.dart';
import '../ui/core/view_models/connection_view_model.dart';
import 'im_providers.dart';

/// 连接状态 Provider（唯一状态源为 ConnectionService）
final connectionProvider = Provider<AppConnectionState>((ref) {
  final status = ref.watch(connectionStatusProvider);
  return AppConnectionState(
    isConnected: status == ConnectionStatus.connected,
    isInitializing: status == ConnectionStatus.connecting,
    error: status == ConnectionStatus.failed ? '连接失败' : null,
  );
});

/// 是否已连接 Provider（便捷访问）
final isConnectedProvider = Provider<bool>((ref) {
  return ref.watch(isConnectedFromServiceProvider);
});
