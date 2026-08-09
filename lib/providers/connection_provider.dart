import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ui/features/chat/view_models/message_service_notifier.dart';
import 'message_service_provider.dart';

/// 连接状态（避免与 Flutter 的 ConnectionState 冲突）
class AppConnectionState {
  final bool isConnected;
  final bool isInitializing;
  final String? error;

  const AppConnectionState({
    this.isConnected = false,
    this.isInitializing = false,
    this.error,
  });

  AppConnectionState copyWith({
    bool? isConnected,
    bool? isInitializing,
    String? error,
  }) {
    return AppConnectionState(
      isConnected: isConnected ?? this.isConnected,
      isInitializing: isInitializing ?? this.isInitializing,
      error: error,
    );
  }
}

/// 连接状态 Notifier
class ConnectionNotifier extends StateNotifier<AppConnectionState> {
  ConnectionNotifier(this._ref) : super(const AppConnectionState()) {
    _init();
  }

  final Ref _ref;

  void _init() {
    // 监听 messageServiceProvider 的状态变化
    _ref.listen(
      messageServiceProvider,
      (_, next) {
        _syncState(next);
      },
      fireImmediately: true,
    );
  }

  void _syncState(MessageServiceState messageServiceState) {
    state = state.copyWith(
      isConnected: messageServiceState.isConnected,
      isInitializing: messageServiceState.isInitializing,
    );
  }
}

/// 连接状态 Provider
final connectionProvider = StateNotifierProvider<ConnectionNotifier, AppConnectionState>((ref) {
  return ConnectionNotifier(ref);
});

/// 是否已连接 Provider（便捷访问）
final isConnectedProvider = Provider<bool>((ref) {
  return ref.watch(connectionProvider).isConnected;
});
