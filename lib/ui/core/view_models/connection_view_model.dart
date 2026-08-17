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
