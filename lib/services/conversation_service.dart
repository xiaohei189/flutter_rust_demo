import 'dart:async';

import '../src/rust/event/listener/conversation.dart';
import '../src/rust/domain/model/local.dart' show LocalConversation;
import '../utils/app_logger.dart';
import 'im_client.dart';

/// 会话同步状态
enum ConversationSyncStatus {
  /// 空闲
  idle,
  /// 同步中
  syncing,
  /// 同步完成
  completed,
  /// 同步失败
  failed,
}

/// 会话服务 - 管理会话列表
///
/// 职责：
/// 1. 加载和管理会话列表
/// 2. 监听会话变化事件
/// 3. 提供会话查询和排序
/// 4. 处理会话同步状态
class ConversationService {
  static final ConversationService _instance = ConversationService._internal();

  /// 全局单例实例
  static ConversationService get instance => _instance;

  // 会话列表
  final List<LocalConversation> _conversations = [];

  // 同步状态
  ConversationSyncStatus _syncStatus = ConversationSyncStatus.idle;
  int _syncProgress = 0;

  // 流控制器
  final _conversationsController =
      StreamController<List<LocalConversation>>.broadcast();
  final _syncStatusController =
      StreamController<ConversationSyncStatus>.broadcast();
  final _syncProgressController = StreamController<int>.broadcast();

  StreamSubscription<dynamic>? _subscription;
  bool _isDisposed = false;

  ConversationService._internal();

  /// 会话列表流
  Stream<List<LocalConversation>> get conversationsStream =>
      _conversationsController.stream;

  /// 同步状态流
  Stream<ConversationSyncStatus> get syncStatusStream =>
      _syncStatusController.stream;

  /// 同步进度流（0-100）
  Stream<int> get syncProgressStream => _syncProgressController.stream;

  /// 当前会话列表（不可变）
  List<LocalConversation> get conversations =>
      List.unmodifiable(_conversations);

  /// 当前同步状态
  ConversationSyncStatus get syncStatus => _syncStatus;

  /// 当前同步进度（0-100）
  int get syncProgress => _syncProgress;

  /// 是否正在同步
  bool get isSyncing => _syncStatus == ConversationSyncStatus.syncing;

  /// 获取指定会话
  LocalConversation? getConversation(String conversationId) {
    try {
      return _conversations.firstWhere(
        (c) => c.conversationId == conversationId,
      );
    } catch (_) {
      return null;
    }
  }

  /// 开始监听会话事件
  void startListening() {
    if (_subscription != null) return;

    try {
      _subscription = ImClient.instance.conversationStream.listen(
        _handleEvent,
        onError: (error) {
          appLog.e('[ConversationService] 事件流错误: $error');
        },
      );
      appLog.i('[ConversationService] 开始监听会话事件');
    } catch (e) {
      appLog.e('[ConversationService] 监听会话事件失败: $e');
    }
  }

  /// 停止监听
  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
    appLog.i('[ConversationService] 停止监听会话事件');
  }

  /// 处理统一事件
  void _handleEvent(ConversationEvent event) {
    event.maybeWhen(
      syncStarted: () {
        _updateSyncStatus(ConversationSyncStatus.syncing);
        _updateSyncProgress(0);
      },
      syncFinished: () {
        _updateSyncStatus(ConversationSyncStatus.completed);
        _updateSyncProgress(100);
        loadConversations();
      },
      syncProgress: (progress, _) {
        _updateSyncStatus(ConversationSyncStatus.syncing);
        _updateSyncProgress(progress);
      },
      syncFailed: (_) {
        _updateSyncStatus(ConversationSyncStatus.failed);
      },
      new_: (_) {
        loadConversations();
      },
      changed: (_) {
        loadConversations();
      },
      deleted: (ids) {
        for (final id in ids) {
          _conversations.removeWhere((c) => c.conversationId == id);
        }
        _notifyConversationsChanged();
      },
      totalUnreadCountChanged: (_) {
        _notifyConversationsChanged();
      },
      orElse: () {},
    );
  }

  /// 更新或添加会话
  void _updateOrAddConversation(LocalConversation conv) {
    final index = _conversations.indexWhere(
      (c) => c.conversationId == conv.conversationId,
    );

    if (index >= 0) {
      _conversations[index] = conv;
    } else {
      _conversations.add(conv);
    }
  }

  /// 加载会话列表
  Future<void> loadConversations() async {
    final client = ImClient.instance.client;
    if (client == null) {
      appLog.w('[ConversationService] 客户端为空，无法加载会话');
      return;
    }

    try {
      appLog.i('[ConversationService] 开始加载会话列表');
      final conversations = await client.getConversations();
      appLog.i('[ConversationService] 加载到 ${conversations.length} 个会话');

      _conversations.clear();
      for (final conv in conversations) {
        _updateOrAddConversation(conv);
      }

      _sortConversations();
      _notifyConversationsChanged();
    } catch (e) {
      appLog.e('[ConversationService] 加载会话列表失败: $e');
    }
  }

  /// 刷新会话列表
  Future<void> refreshConversations() async {
    await loadConversations();
  }

  /// 排序会话列表（置顶优先，然后按最后消息时间倒序）
  void _sortConversations() {
    _conversations.sort((a, b) {
      // 置顶的排在前面
      if (a.isPinned != b.isPinned) {
        return a.isPinned == 1 ? -1 : 1;
      }
      // 按最后消息时间倒序
      final aTime = a.latestMsgSendTime.toInt();
      final bTime = b.latestMsgSendTime.toInt();
      return bTime.compareTo(aTime);
    });
  }

  /// 从本地列表移除会话
  void removeConversation(String conversationId) {
    _conversations.removeWhere((c) => c.conversationId == conversationId);
    _notifyConversationsChanged();
  }

  /// 更新同步状态
  void _updateSyncStatus(ConversationSyncStatus status) {
    _syncStatus = status;
    if (!_isDisposed && !_syncStatusController.isClosed) {
      _syncStatusController.add(status);
    }
  }

  /// 更新同步进度
  void _updateSyncProgress(int progress) {
    _syncProgress = progress.clamp(0, 100);
    if (!_isDisposed && !_syncProgressController.isClosed) {
      _syncProgressController.add(_syncProgress);
    }
  }

  /// 通知会话列表变化
  void _notifyConversationsChanged() {
    _sortConversations();
    if (!_isDisposed && !_conversationsController.isClosed) {
      _conversationsController.add(List.unmodifiable(_conversations));
    }
  }

  /// 重置状态
  void reset() {
    _conversations.clear();
    _syncStatus = ConversationSyncStatus.idle;
    _syncProgress = 0;
    stopListening();
  }

  /// 释放资源
  void dispose() {
    _isDisposed = true;
    reset();
    _conversationsController.close();
    _syncStatusController.close();
    _syncProgressController.close();
  }
}
