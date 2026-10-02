import 'dart:async';

import '../../../generated/rust/event/events/connection.dart';
import '../../../data/services/connection_service.dart';
import '../../../data/services/login_storage.dart';
import '../../../data/services/navigation_service.dart';
import '../../../data/services/online_status_service.dart';
import '../../../data/services/im_client.dart';
import '../../../core/utils/app_logger.dart';
import 'message_service_notifier.dart';

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

  /// 创建客户端（Rust 建库 + 登录握手）的超时。
  ///
  /// Rust 侧对 WS 升级和认证帧各有 10s 超时，这里留出余量做兜底：服务重启期间
  /// 网关"接了连接但不回认证帧"时，不能让外层一直 awaiting。
  static const Duration _clientCreateTimeout = Duration(seconds: 25);

  /// 取消事件流订阅的超时。
  ///
  /// frb 的事件流底层是 ReceivePort：Rust 侧静默（登出后不再推事件）且未关闭 port 时，
  /// `StreamSubscription.cancel()` 返回的 future 不会完成——只有再来一条事件或 port 被
  /// 关闭才会返回。登出后正好是这个状态，所以必须限时等待，否则登出清理会永久挂起，
  /// 下一个账号登录时又卡在"关闭已有客户端"这同一处。
  /// 回归用例见 test/application/chat/message_service_connection_controller_test.dart。
  static const Duration _subscriptionCancelTimeout = Duration(milliseconds: 300);

  /// 进行中的初始化：并发调用复用同一次结果，避免拿到"假成功"。
  Future<void>? _initializeInFlight;

  Future<void> initialize({
    String? wsUrl,
    String? apiBaseUrl,
    String? userId,
    String? imToken,
  }) {
    final inFlight = _initializeInFlight;
    if (inFlight != null) {
      appLog.w('⚠️ 初始化正在进行中，复用同一次初始化结果');
      return inFlight;
    }
    final future = _doInitialize(
      wsUrl: wsUrl,
      apiBaseUrl: apiBaseUrl,
      userId: userId,
      imToken: imToken,
    );
    _initializeInFlight = future;
    return future.whenComplete(() {
      if (identical(_initializeInFlight, future)) _initializeInFlight = null;
    });
  }

  Future<void> _doInitialize({
    String? wsUrl,
    String? apiBaseUrl,
    String? userId,
    String? imToken,
  }) async {
    // 仅当仍是同一用户且已连接时才跳过（热更新场景）；切换账号必须重新初始化
    final sameUser =
        userId == null ||
        service.currentState.currentUserId.isEmpty ||
        service.currentState.currentUserId == userId;
    if (imClient.isInitialized &&
        service.currentState.isConnected &&
        sameUser) {
      onlineStatusService.setClient(imClient.client);
      appLog.i('ℹ️ 客户端已连接，跳过重复初始化（热更新场景）');
      return;
    }

    service.updateState(service.currentState.copyWith(isInitializing: true));
    connectionService.updateStatus(ConnectionStatus.connecting);
    appLog.i('[MessageService] initialize 开始');
    try {
      if (imClient.isInitialized) {
        appLog.i('[MessageService] 关闭已有客户端，重新初始化');
        await _cancelSubscriptions();
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

      await imClient
          .createClient(
            userId: resolvedUserId,
            token: resolvedImToken,
            wsUrl: wsUrl,
            apiBaseUrl: apiBaseUrl!,
          )
          .timeout(
            _clientCreateTimeout,
            onTimeout: () => throw TimeoutException(
              'IM 客户端初始化超时（${_clientCreateTimeout.inSeconds} 秒），请确认服务已启动后重试',
            ),
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
      logout: () {
        connectionService.updateStatus(ConnectionStatus.disconnected);
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
    await _cancelSubscriptions();
    await imClient.close();
    onlineStatusService.setClient(null);
    connectionService.updateStatus(ConnectionStatus.disconnected);
    service.resetState();
  }

  /// 取消全部事件流订阅（先摘引用，再限时等待，超时即放弃）。
  ///
  /// 详见 `_subscriptionCancelTimeout`：绝不能直接 `await s.cancel()`，
  /// 静默的 frb 事件流会让它永不返回，进而拖死登出与重登。
  Future<void> _cancelSubscriptions() async {
    final pending = List<StreamSubscription<dynamic>>.of(
      service.subscriptions,
    );
    service.subscriptions.clear();
    if (pending.isEmpty) return;
    await Future.wait(
      pending.map(_cancelSubscriptionSafely),
    ).timeout(_subscriptionCancelTimeout, onTimeout: () => const <void>[]);
  }

  Future<void> _cancelSubscriptionSafely(
    StreamSubscription<dynamic> subscription,
  ) async {
    try {
      await subscription.cancel();
    } catch (e) {
      appLog.w('[MessageService] 取消事件流订阅失败: $e');
    }
  }
}
