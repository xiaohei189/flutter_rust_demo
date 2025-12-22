import 'package:flutter/material.dart';

import '../models/chat.dart';
import '../models/message.dart';
import '../src/rust/api/bridge_client.dart';

/// 消息服务 - 管理客户端连接
class MessageService extends ChangeNotifier {
  OpenImBridgeClient? _client;
  bool _isConnected = false;

  /// 是否已连接
  bool get isConnected => _isConnected;

  /// 获取客户端实例
  OpenImBridgeClient? get client => _client;

  /// 获取所有会话列表（空实现）
  List<Chat> get chats => [];

  /// 获取指定会话的消息列表（空实现）
  List<Message> getMessages(String conversationId) {
    return [];
  }

  /// 发送文本消息（空实现）
  Future<void> sendTextMessage({
    required String recvId,
    required String text,
    required int sessionType,
  }) async {
    // TODO: 实现消息发送功能
  }

  /// 初始化并连接服务
  Future<void> initialize({
    String? wsUrl,
  }) async {
    if (_client != null) {
      await disconnect();
    }

    try {
      // 先登录获取 token 信息（参考 openim-cli.rs 的实现）
      final loginResponse = await loginAsync(
        areaCode: '+86',
        phoneNumber: '17764008284',
        password: '284f3d09ea0695538e4ded1c1766d73a',
        platform: 5,
      );

      if (loginResponse.errCode() != 0) {
        throw Exception('登录失败: ${loginResponse.errMsg()}');
      }

      final userId = loginResponse.userId();
      final imToken = loginResponse.imToken();

      if (userId == null || imToken == null) {
        throw Exception('登录失败：服务器返回数据为空');
      }

      debugPrint('✅ 登录成功！用户ID: $userId');

      // 创建客户端实例
      _client = OpenImBridgeClient(
        userId: userId,
        token: imToken,
        platformId: 5,
        wsUrl: wsUrl,
      );

      // 连接到服务器
      await _client!.connect();
      _isConnected = true;
      notifyListeners();

      debugPrint('✅ 客户端连接成功');
    } catch (e) {
      debugPrint('❌ 初始化失败: $e');
      _isConnected = false;
      notifyListeners();
      rethrow;
    }
  }

  /// 断开连接
  Future<void> disconnect() async {
    _client = null;
    _isConnected = false;
    notifyListeners();
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
