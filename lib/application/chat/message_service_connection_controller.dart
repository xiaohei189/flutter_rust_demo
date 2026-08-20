import 'dart:async';

import '../../../generated/rust/event/events/connection.dart';
import '../../../data/services/connection_service.dart';
import '../../../data/services/login_storage.dart';
import '../../../data/services/navigation_service.dart';
import '../../../data/services/online_status_service.dart';
import '../../../data/services/im_client.dart';
import '../../../core/utils/app_logger.dart';
import 'message_service_notifier.dart';
import 'message_service_state.dart';

/// 连接初始化、事件订阅与断开。
class MessageServiceConnectionController {
  MessageServiceConnectionController(
    this.service,
    this.connectionService,
    this.onlineStatusService,
    this.imClient,
    this.navigationService,
  );

  final ConnectionService connectionService;
  final OnlineStatusService onlineStatusService;
  final ImClient imClient;
  final NavigationService navigationService;

  final MessageServiceNotifier service;

  Future<void> initialize({
    String? wsUrl,
    String? apiBaseUrl,
    String? userId,
    String? imToken,
  }) async {
    if (imClient.isInitialized && service.currentState.isConnected) {
      onlineStatusService.setClient(imClient.client);
      appLog.i('ℹ️ 客户端已连接，跳过重复初始化（热更新场景）');
      return;
    }

    if (service.currentState.isInitializing) {
      appLog.w('⚠️ 初始化正在进行中，跳过重复调用');
      return;
    }

    service.updateState(service.currentState.copyWith(isInitializing: true));
    connectionService.updateStatus(ConnectionStatus.connecting);
    appLog.i('[MessageService] initialize 开始');
    try {
      if (imClient.isInitialized) {
        appLog.i('[MessageService] 关闭已有客户端，重新初始化');
        for (final s in service.subscriptions) {
          await s.cancel();
        }
        service.subscriptions.clear();
        try {
          await imClient.close();
        } catch (e) {
          appLog.w('[MessageService] 关闭旧客户端失败: $e');
        }
        onlineStatusService.setClient(null);
      }

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

      await imClient.createClient(
        userId: resolvedUserId,
        token: resolvedImToken,
        wsUrl: wsUrl,
        apiBaseUrl: apiBaseUrl!,
      );
      onlineStatusService.setClient(imClient.client);
      unawaited(service.loadConversations());

      service.subscriptions.add(
        imClient.connectionStream.listen(service.onConnectionEvent),
      );
      service.subscriptions.add(
        imClient.conversationStream.listen(
          service.onConversationEvent,
        ),
      );
      service.subscriptions.add(
        imClient.friendStream.listen(service.onFriendEvent),
      );
      service.subscriptions.add(
        imClient.groupStream.listen(service.onGroupEvent),
      );
      service.subscriptions.add(
        imClient.messageStream.listen(service.onMessageEvent),
      );
      service.subscriptions.add(
        imClient.userStream.listen(service.onUserEvent),
      );
      appLog.i('[MessageService] 6 模块事件流已注册');

      service.updateState(service.currentState.copyWith(isConnected: true));
      connectionService.updateStatus(ConnectionStatus.connected);
      appLog.i('✅ 客户端连接成功');

      unawaited(service.refreshLoginUserProfile());
      unawaited(service.loadConversations());
    } catch (e) {
      appLog.e('❌ 初始化失败: $e');
      service.updateState(service.currentState.copyWith(isConnected: false));
      connectionService.updateStatus(ConnectionStatus.failed);
      rethrow;
    } finally {
      service.updateState(service.currentState.copyWith(isInitializing: false));
    }
  }

  void handleEvent(ConnectionEvent event) {
    appLog.i('[MsgSvc] _onConnectionEvent: ${event.runtimeType}');
    event.maybeWhen(
      connected: () {
        connectionService.updateStatus(ConnectionStatus.connected);
        appLog.i('[MsgSvc] connected!');
        service.updateState(service.currentState.copyWith(isConnected: true));
        unawaited(service.loadConversations());
      },
      connecting: () =>
          connectionService.updateStatus(ConnectionStatus.connecting),
      disconnected: (_) =>
          connectionService.updateStatus(ConnectionStatus.disconnected),
      connectFailed: (_, _) =>
          connectionService.updateStatus(ConnectionStatus.failed),
      reconnecting: (_, _) =>
          connectionService.updateStatus(ConnectionStatus.connecting),
      kickedOffline: (_) {
        connectionService.updateStatus(ConnectionStatus.kickedOffline);
        service.updateState(service.currentState.copyWith(isConnected: false));
      },
      tokenExpired: () {
        connectionService.updateStatus(ConnectionStatus.tokenExpired);
        service.updateState(service.currentState.copyWith(isConnected: false));
        LoginStorage.clearCredentials().catchError((_) {});
        navigationService.goToLogin();
      },
      orElse: () {},
    );
  }

  Future<void> disconnect() async {
    for (final s in service.subscriptions) {
      await s.cancel();
    }
    service.subscriptions.clear();
    await imClient.close();
    onlineStatusService.setClient(null);
    connectionService.updateStatus(ConnectionStatus.disconnected);
    service.updateState(MessageServiceState());
  }
}
