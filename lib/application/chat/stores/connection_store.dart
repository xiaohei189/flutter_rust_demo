class ConnectionStore {
  final bool isConnected;
  final bool isInitializing;

  const ConnectionStore({
    this.isConnected = false,
    this.isInitializing = false,
  });

  ConnectionStore copyWith({bool? isConnected, bool? isInitializing}) {
    return ConnectionStore(
      isConnected: isConnected ?? this.isConnected,
      isInitializing: isInitializing ?? this.isInitializing,
    );
  }
}