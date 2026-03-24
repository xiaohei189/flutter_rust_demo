import 'dart:async';

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
        _handleConnectionEvent,
        onError: (error) {
          appLog.e('[ConnectionService] 连接流错误: $error');
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

  /// 处理连接事件
  void _handleConnectionEvent(dynamic event) {
    if (event == null) return;

    final name = event.runtimeType.toString();
    appLog.d('[ConnectionService] 收到连接事件: $name');

    if (name.contains('ConnectSuccess') || name == 'ConnEvent_ConnectSuccess') {
      _updateStatus(ConnectionStatus.connected);
    } else if (name.contains('Connecting') || name == 'ConnEvent_Connecting') {
      _updateStatus(ConnectionStatus.connecting);
    } else if (name.contains('ConnectFailed') ||
        name == 'ConnEvent_ConnectFailed') {
      _updateStatus(ConnectionStatus.failed);
    } else if (name.contains('KickedOffline') ||
        name == 'ConnEvent_KickedOffline') {
      _updateStatus(ConnectionStatus.kickedOffline);
    } else if (name.contains('UserTokenExpired') ||
        name == 'ConnEvent_UserTokenExpired') {
      _updateStatus(ConnectionStatus.tokenExpired);
    } else if (name.contains('UserTokenInvalid') ||
        name == 'ConnEvent_UserTokenInvalid') {
      _updateStatus(ConnectionStatus.tokenExpired);
    }
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
