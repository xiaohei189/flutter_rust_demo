import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/message_service.dart';
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
  ConnectionNotifier(this._messageService) : super(const AppConnectionState()) {
    _init();
  }

  final MessageService _messageService;

  void _init() {
    // 监听 MessageService 的变化
    _messageService.addListener(_onServiceChanged);
    _syncState();
  }

  void _onServiceChanged() {
    _syncState();
  }

  void _syncState() {
    state = state.copyWith(
      isConnected: _messageService.isConnected,
    );
  }

  @override
  void dispose() {
    _messageService.removeListener(_onServiceChanged);
    super.dispose();
  }
}

/// 连接状态 Provider
final connectionProvider = StateNotifierProvider<ConnectionNotifier, AppConnectionState>((ref) {
  return ConnectionNotifier(ref.read(messageServiceProvider));
});

/// 是否已连接 Provider（便捷访问）
final isConnectedProvider = Provider<bool>((ref) {
  return ref.watch(connectionProvider).isConnected;
});
