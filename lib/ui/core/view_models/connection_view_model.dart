import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../chat/providers/message_service_provider.dart';
import '../../chat/view_models/message_service_notifier.dart';

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

/// 连接状态 ViewModel
class ConnectionNotifier extends Notifier<AppConnectionState> {
  @override
  AppConnectionState build() {
    ref.listen(messageServiceProvider, (_, next) {
      _syncState(next);
    });
    Future.microtask(() => _syncState(ref.read(messageServiceProvider)));
    return const AppConnectionState();
  }

  void _syncState(MessageServiceState messageServiceState) {
    state = state.copyWith(
      isConnected: messageServiceState.isConnected,
      isInitializing: messageServiceState.isInitializing,
    );
  }
}
