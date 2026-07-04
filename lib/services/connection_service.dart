import 'dart:async';

import '../src/rust/domain/event/types.dart' show SdkEvent;
import '../utils/app_logger.dart';
import 'im_client.dart';

/// 连接状态枚举
enum ConnectionStatus {
  /// 未连接
  disconnected,
  /// 连接中
  connecting,
  /// 已连接
  connected,
  /// 连接失败
  failed,
  /// 被踢下线
  kickedOffline,
  /// Token 过期
  tokenExpired,
}

/// 连接服务 - 管理 IM 连接状态
///
/// 职责：
/// 1. 监听连接状态变化
/// 2. 提供连接状态查询
/// 3. 处理连接事件回调
class ConnectionService {
  static final ConnectionService _instance = ConnectionService._internal();

  /// 全局单例实例
  static ConnectionService get instance => _instance;

  final _statusController = StreamController<ConnectionStatus>.broadcast();
  ConnectionStatus _status = ConnectionStatus.disconnected;
  StreamSubscription<dynamic>? _subscription;
  bool _isDisposed = false;

  ConnectionService._internal();

  /// 连接状态流
  Stream<ConnectionStatus> get statusStream => _statusController.stream;

  /// 当前连接状态
  ConnectionStatus get status => _status;

  /// 是否已连接
  bool get isConnected => _status == ConnectionStatus.connected;

  /// 是否正在连接
  bool get isConnecting => _status == ConnectionStatus.connecting;

  /// 开始监听连接状态
  void startListening() {
    if (_subscription != null) return;

    try {
      _subscription = ImClient.instance.connectionStream.listen(
        _handleEvent,
        onError: (error) {
          appLog.e('[ConnectionService] 事件流错误: $error');
          _updateStatus(ConnectionStatus.failed);
        },
      );
      appLog.i('[ConnectionService] 开始监听连接状态');
    } catch (e) {
      appLog.e('[ConnectionService] 监听连接状态失败: $e');
    }
  }

  /// 停止监听
  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
    appLog.i('[ConnectionService] 停止监听连接状态');
  }

  /// 处理统一事件
  void _handleEvent(SdkEvent event) {
    event.maybeWhen(
      connected: () {
        _updateStatus(ConnectionStatus.connected);
      },
      connecting: () {
        _updateStatus(ConnectionStatus.connecting);
      },
      disconnected: (reason) {
        _updateStatus(ConnectionStatus.disconnected);
      },
      connectFailed: (error) {
        _updateStatus(ConnectionStatus.failed);
      },
      reconnecting: (attempt, maxAttempts) {
        _updateStatus(ConnectionStatus.connecting);
      },
      kickedOffline: (reason) {
        _updateStatus(ConnectionStatus.kickedOffline);
      },
      tokenExpired: () {
        _updateStatus(ConnectionStatus.tokenExpired);
      },
      orElse: () {},
    );
  }

  /// 更新状态并通知监听者
  void _updateStatus(ConnectionStatus newStatus) {
    if (_status == newStatus) return;

    _status = newStatus;
    appLog.i('[ConnectionService] 连接状态变化: ${newStatus.name}');

    if (!_isDisposed && !_statusController.isClosed) {
      _statusController.add(newStatus);
    }
  }

  /// 手动设置连接状态（用于初始化等场景）
  void setConnected(bool connected) {
    _updateStatus(connected ? ConnectionStatus.connected : ConnectionStatus.disconnected);
  }

  /// 重置状态
  void reset() {
    _status = ConnectionStatus.disconnected;
    stopListening();
  }

  /// 释放资源
  void dispose() {
    _isDisposed = true;
    stopListening();
    _statusController.close();
  }
}
