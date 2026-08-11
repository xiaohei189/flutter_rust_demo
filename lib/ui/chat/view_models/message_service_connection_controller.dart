import 'dart:async';

import 'package:path_provider/path_provider.dart';

import '../../../generated/rust/client/config.dart';
import '../../../generated/rust/event/events/connection.dart';
import '../../../generated/rust/ffi/client.dart' as fb;
import '../../../generated/rust/ffi/ffi_init.dart' show initLogger;
import '../../../data/services/login_storage.dart';
import '../../../data/services/navigation_service.dart';
import '../../../data/services/online_status_service.dart';
import '../../core/utils/app_logger.dart';
import 'message_service_notifier.dart';
import 'message_service_state.dart';

/// 连接初始化、事件订阅与断开。
class MessageServiceConnectionController {
  MessageServiceConnectionController(this.service);

  final MessageServiceNotifier service;

  Future<void> initialize({
    String? wsUrl,
    String? apiBaseUrl,
    String? userId,
    String? imToken,
  }) async {
    if (service.client != null && service.currentState.isConnected) {
      appLog.i('ℹ️ 客户端已连接，跳过重复初始化（热更新场景）');
      return;
    }

    if (service.currentState.isInitializing) {
      appLog.w('⚠️ 初始化正在进行中，跳过重复调用');
      return;
    }

    service.updateState(service.currentState.copyWith(isInitializing: true));
    appLog.i('[MessageService] initialize 开始');
    try {
      if (service.client != null) {
        appLog.i('[MessageService] 关闭已有客户端，重新初始化');
        for (final s in service.subscriptions) {
          await s.cancel();
        }
        service.subscriptions.clear();
        try {
          await service.client!.disconnect();
        } catch (e) {
          appLog.w('[MessageService] 关闭旧客户端失败: $e');
        }
        service.client = null;
        OnlineStatusService.instance.setClient(null);
      }

      appLog.i('[MessageService] 初始化日志和 SDK 客户端...');
      await initLogger(logLevel: 'info,rust_lib_flutter_rust_demo=debug');

      final String resolvedUserId;
      final String resolvedImToken;
      if (userId != null &&
          userId.isNotEmpty &&
          imToken != null &&
          imToken.isNotEmpty) {
        resolvedUserId = userId;
        resolvedImToken = imToken;
        appLog.i('[MessageService] 用户ID: $resolvedUserId');
      } else {
        throw StateError('缺少 userId 或 imToken，请先登录');
      }

      service.updateState(
        service.currentState.copyWith(currentUserId: resolvedUserId),
      );

      final docDir = await getApplicationDocumentsDirectory();
      final dataDir = '${docDir.path}/openim_data';
      service.client = await fb.OpenImBridgeClient.newInstance(
        config: ClientConfig(
          userId: resolvedUserId,
          token: resolvedImToken,
          platformId: 5,
          wsUrl: wsUrl,
          apiBaseUrl: apiBaseUrl!,
          dataDir: dataDir,
        ),
      );
      OnlineStatusService.instance.setClient(service.client);
      unawaited(service.loadConversations());

      service.subscriptions.add(
        service.client!.connectionStream().listen(service.onConnectionEvent),
      );
      service.subscriptions.add(
        service.client!.conversationStream().listen(
          service.onConversationEvent,
        ),
      );
      service.subscriptions.add(
        service.client!.friendStream().listen(service.onFriendEvent),
      );
      service.subscriptions.add(
        service.client!.groupStream().listen(service.onGroupEvent),
      );
      service.subscriptions.add(
        service.client!.messageStream().listen(service.onMessageEvent),
      );
      service.subscriptions.add(
        service.client!.userStream().listen(service.onUserEvent),
      );
      appLog.i('[MessageService] 6 模块事件流已注册');

      service.updateState(service.currentState.copyWith(isConnected: true));
      appLog.i('✅ 客户端连接成功');

      unawaited(service.refreshLoginUserProfile());
      unawaited(service.loadConversations());
    } catch (e) {
      appLog.e('❌ 初始化失败: $e');
      service.updateState(service.currentState.copyWith(isConnected: false));
      rethrow;
    } finally {
      service.updateState(service.currentState.copyWith(isInitializing: false));
    }
  }

  void handleEvent(ConnectionEvent event) {
    appLog.i('[MsgSvc] _onConnectionEvent: ${event.runtimeType}');
    event.maybeWhen(
      connected: () {
        appLog.i('[MsgSvc] connected!');
        service.updateState(service.currentState.copyWith(isConnected: true));
        unawaited(service.loadConversations());
      },
      kickedOffline: (_) => service.updateState(
        service.currentState.copyWith(isConnected: false),
      ),
      tokenExpired: () {
        service.updateState(service.currentState.copyWith(isConnected: false));
        LoginStorage.clearCredentials().catchError((_) {});
        NavigationService.instance.goToLogin();
      },
      orElse: () {},
    );
  }

  Future<void> disconnect() async {
    for (final s in service.subscriptions) {
      await s.cancel();
    }
    service.subscriptions.clear();
    await service.client?.disconnect();
    service.client = null;
    OnlineStatusService.instance.setClient(null);
    service.updateState(const MessageServiceState());
  }
}
