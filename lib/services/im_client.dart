import 'dart:async';

import 'package:path_provider/path_provider.dart';

import '../src/rust/api/bridge_client.dart';
import '../src/rust/api/simple.dart';
import '../src/rust/domain/event/types.dart' show SdkEvent;
import '../src/rust/domain/config.dart';
import '../utils/app_logger.dart';

/// IM 客户端管理 - 负责 OpenImBridgeClient 的创建和管理
/// 
/// 职责：
/// 1. 管理 OpenImBridgeClient 实例生命周期
/// 2. 提供客户端实例访问
/// 3. 初始化日志和基础配置
class ImClient {
  static final ImClient _instance = ImClient._internal();

  /// 全局单例实例
  static ImClient get instance => _instance;
  
  OpenImBridgeClient? _client;
  bool _isInitializing = false;
  
  ImClient._internal();
  
  /// 获取客户端实例
  OpenImBridgeClient? get client => _client;
  
  /// 是否已初始化
  bool get isInitialized => _client != null;
  
  /// 是否正在初始化
  bool get isInitializing => _isInitializing;
  
  /// 创建客户端实例
  /// 
  /// [userId] 用户ID
  /// [token] IM Token
  /// [platformId] 平台ID（5 表示 Flutter）
  /// [wsUrl] WebSocket 地址
  /// [apiBaseUrl] HTTP API 基础地址
  Future<OpenImBridgeClient> createClient({
    required String userId,
    required String token,
    int platformId = 5,
    String? wsUrl,
    String? apiBaseUrl,
  }) async {
    // 防止并发初始化
    if (_isInitializing) {
      appLog.w('⚠️ IM 客户端初始化正在进行中');
      // 等待当前初始化完成
      while (_isInitializing) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
      if (_client != null) {
        return _client!;
      }
    }
    
    // 如果已存在客户端，先关闭
    if (_client != null) {
      appLog.i('ℹ️ 关闭现有客户端，重新创建');
      await close();
    }
    
    _isInitializing = true;
    
    try {
      // 初始化日志
      appLog.i('[ImClient] 初始化日志');
      await initLogger(logLevel: 'info,rust_lib_flutter_rust_demo=debug');
      
      // 创建客户端实例
      appLog.i('[ImClient] 创建客户端实例，用户ID: $userId');
      final docDir = await getApplicationDocumentsDirectory();
      final dataDir = '${docDir.path}/openim_data';
      appLog.i('[ImClient] 数据目录: $dataDir');
      _client = await OpenImBridgeClient.newInstance(
        config: ClientConfig(
          userId: userId,
          token: token,
          platformId: platformId,
          wsUrl: wsUrl,
          apiBaseUrl: apiBaseUrl!,
          dataDir: dataDir,
        ),
      );
      
      appLog.i('[ImClient] 客户端创建成功');
      return _client!;
    } catch (e) {
      appLog.e('❌ IM 客户端创建失败: $e');
      rethrow;
    } finally {
      _isInitializing = false;
    }
  }
  
  /// 关闭客户端
  Future<void> close() async {
    if (_client != null) {
      appLog.i('[ImClient] 关闭客户端');
      await _client!.disconnect();
      _client = null;
    }
    _isInitializing = false;
  }
  
  /// 获取统一事件流
  Stream<SdkEvent> get eventStream {
    if (_client == null) {
      throw StateError('客户端未创建');
    }
    return _client!.eventStream();
  }
}
