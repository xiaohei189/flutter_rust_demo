class ConnectionStore {
  final bool isConnected;
  final bool isInitializing;

  const ConnectionStore({
    this.isConnected = false,
    this.isInitializing = false,
  });

  ConnectionStore copyWith({bool? isConnected, bool? isInitializing}) {
    if (isConnected == null && isInitializing == null) return this;
    return ConnectionStore(
      isConnected: isConnected ?? this.isConnected,
      isInitializing: isInitializing ?? this.isInitializing,
    );
  }
}
