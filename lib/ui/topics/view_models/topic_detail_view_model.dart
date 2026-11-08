import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/topic_repository.dart';
import '../../../domain/models/chat_message.dart';
import '../../../domain/models/topic.dart';
import '../providers/topic_provider.dart';

class TopicDetailState {
  final Topic? topic;
  final ChatMessage? rootMessage;
  final List<TopicReply> replies;
  final List<TopicTask> tasks;
  final int nextBeforeSeq;
  final bool hasMore;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final String? taskError;

  const TopicDetailState({
    this.topic,
    this.rootMessage,
    this.replies = const [],
    this.tasks = const [],
    this.nextBeforeSeq = 0,
    this.hasMore = true,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.taskError,
  });

  TopicDetailState copyWith({
    Topic? topic,
    ChatMessage? rootMessage,
    List<TopicReply>? replies,
    List<TopicTask>? tasks,
    int? nextBeforeSeq,
    bool? hasMore,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    String? taskError,
    bool clearError = false,
    bool clearTaskError = false,
  }) {
    return TopicDetailState(
      topic: topic ?? this.topic,
      rootMessage: rootMessage ?? this.rootMessage,
      replies: replies ?? this.replies,
      tasks: tasks ?? this.tasks,
      nextBeforeSeq: nextBeforeSeq ?? this.nextBeforeSeq,
      hasMore: hasMore ?? this.hasMore,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: clearError ? null : (error ?? this.error),
      taskError: clearTaskError ? null : (taskError ?? this.taskError),
    );
  }
}

class TopicDetailViewModel
    extends FamilyNotifier<TopicDetailState, TopicDetailArgs> {
  TopicRepository get _repository => ref.read(topicRepositoryProvider);
  Future<void>? _loadInFlight;
  Future<void>? _loadMoreInFlight;

  @override
  TopicDetailState build(TopicDetailArgs args) {
    Future.microtask(load);
    return const TopicDetailState(isLoading: true);
  }

  Future<void> load() {
    final inFlight = _loadInFlight;
    if (inFlight != null) return inFlight;
    final future = _load();
    _loadInFlight = future.whenComplete(() => _loadInFlight = null);
    return _loadInFlight!;
  }

  Future<void> _load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final detail = await _repository.getTopic(
        groupId: arg.groupId,
        topicId: arg.topicId,
      );
      final replies = await _repository.getReplies(
        topicId: arg.topicId,
        beforeSeq: 0,
      );
      List<TopicTask> tasks = state.tasks;
      String? taskError;
      try {
        tasks = await _repository.getTopicTasks(arg.topicId);
      } catch (e) {
        taskError = '任务加载失败: $e';
      }
      state = state.copyWith(
        topic: detail.topic,
        rootMessage: detail.rootMessage,
        replies: replies.replies.reversed.toList(growable: false),
        tasks: _sortTasks(tasks),
        taskError: taskError,
        clearTaskError: taskError == null,
        nextBeforeSeq: replies.nextBeforeSeq,
        hasMore: replies.hasMore,
        isLoading: false,
      );
      if (detail.topic.lastReplySeq > 0) {
        await _repository.markRead(
          topicId: arg.topicId,
          lastReadSeq: detail.topic.lastReplySeq,
        );
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '加载话题失败: $e');
    }
  }

  Future<void> loadMore() {
    final inFlight = _loadMoreInFlight;
    if (inFlight != null) return inFlight;
    final future = _loadMore();
    _loadMoreInFlight = future.whenComplete(() => _loadMoreInFlight = null);
    return _loadMoreInFlight!;
  }

  Future<void> _loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;
    state = state.copyWith(isLoadingMore: true, clearError: true);
    try {
      final page = await _repository.getReplies(
        topicId: arg.topicId,
        beforeSeq: state.nextBeforeSeq,
      );
      final seen = state.replies
          .map((item) => item.message.clientMsgId)
          .toSet();
      final older = page.replies.reversed
          .where((item) => seen.add(item.message.clientMsgId))
          .toList(growable: false);
      state = state.copyWith(
        replies: [...older, ...state.replies],
        nextBeforeSeq: page.nextBeforeSeq,
        hasMore: page.hasMore,
        isLoadingMore: false,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false, error: '加载回复失败: $e');
    }
  }

  Future<void> toggleSubscription() async {
    final topic = state.topic;
    if (topic == null) return;
    final subscribed = await _repository.setSubscription(
      topicId: topic.topicId,
      subscribed: !topic.subscribed,
    );
    state = state.copyWith(topic: _copyTopic(topic, subscribed: subscribed));
  }

  Future<void> togglePinned() async {
    final topic = state.topic;
    if (topic == null) return;
    final updated = await _repository.setPinned(
      topicId: topic.topicId,
      pinned: !topic.pinned,
      expectedVersion: topic.version,
    );
    state = state.copyWith(topic: updated);
  }

  Future<void> toggleGroupPinned() async {
    final topic = state.topic;
    if (topic == null) return;
    final updated = await _repository.setGroupPinned(
      topicId: topic.topicId,
      pinned: !topic.groupPinned,
      expectedVersion: topic.version,
    );
    state = state.copyWith(topic: updated);
  }

  Future<void> closeOrReopen() async {
    final topic = state.topic;
    if (topic == null) return;
    final next = topic.state == TopicState.closed
        ? TopicState.open
        : TopicState.closed;
    final updated = await _repository.changeState(
      topicId: topic.topicId,
      state: next,
      expectedVersion: topic.version,
    );
    state = state.copyWith(topic: updated);
  }

  Future<void> revoke() async {
    final topic = state.topic;
    if (topic == null) return;
    final updated = await _repository.changeState(
      topicId: topic.topicId,
      state: TopicState.revoked,
      expectedVersion: topic.version,
    );
    state = state.copyWith(topic: updated);
  }

  Future<void> toggleReaction(String emoji) async {
    final topic = state.topic;
    if (topic == null) return;
    final reactions = await _repository.setReaction(
      topicId: topic.topicId,
      emoji: emoji,
      active: !topic.reactions.hasReaction(emoji),
    );
    state = state.copyWith(topic: _copyTopic(topic, reactions: reactions));
  }

  Future<void> markUnread() async {
    final topic = state.topic;
    if (topic == null) return;
    final seq = await _repository.markUnread(topic.topicId);
    state = state.copyWith(
      topic: _copyTopic(
        topic,
        lastReadSeq: seq,
        hasUnread: topic.lastReplySeq > seq,
      ),
    );
  }

  Future<TopicTask> createTask({
    required String title,
    required String description,
    required String assigneeId,
    required int dueAt,
    required TopicTaskPriority priority,
  }) async {
    final task = await _repository.createTopicTask(
      topicId: arg.topicId,
      title: title,
      description: description,
      assigneeId: assigneeId,
      dueAt: dueAt,
      priority: priority,
    );
    state = state.copyWith(tasks: _sortTasks([...state.tasks, task]));
    return task;
  }

  Future<void> changeTaskStatus(TopicTask task, TopicTaskStatus status) async {
    final updated = await _repository.changeTopicTaskStatus(
      taskId: task.taskId,
      status: status,
      expectedVersion: task.version,
    );
    state = state.copyWith(
      tasks: _sortTasks([
        for (final item in state.tasks)
          if (item.taskId == updated.taskId) updated else item,
      ]),
    );
  }

  Future<void> reloadTasks() async {
    try {
      final tasks = await _repository.getTopicTasks(arg.topicId);
      state = state.copyWith(tasks: _sortTasks(tasks), clearTaskError: true);
    } catch (e) {
      state = state.copyWith(taskError: '任务加载失败: $e');
    }
  }

  Future<void> editRoot(String text) async {
    final topic = state.topic;
    if (topic == null) return;
    final updated = await _repository.editTopic(
      topicId: topic.topicId,
      text: text,
      expectedVersion: topic.version,
    );
    state = state.copyWith(
      topic: updated,
      rootMessage: state.rootMessage?.copyWith(
        content: jsonEncode({'content': text}),
        contentType: 101,
      ),
    );
  }

  List<TopicTask> _sortTasks(Iterable<TopicTask> tasks) {
    final result = tasks.toList(growable: false);
    result.sort((a, b) {
      final status = a.status.index.compareTo(b.status.index);
      if (status != 0) return status;
      if (a.dueAt != b.dueAt) return a.dueAt.compareTo(b.dueAt);
      return b.createdAt.compareTo(a.createdAt);
    });
    return result;
  }

  Topic _copyTopic(
    Topic topic, {
    bool? subscribed,
    TopicReactionState? reactions,
    int? lastReadSeq,
    bool? hasUnread,
    bool? hasMention,
  }) {
    final current = topic.userState;
    return Topic(
      topicId: topic.topicId,
      groupId: topic.groupId,
      rootClientMsgId: topic.rootClientMsgId,
      rootSeq: topic.rootSeq,
      creatorId: topic.creatorId,
      creatorNickname: topic.creatorNickname,
      creatorFaceUrl: topic.creatorFaceUrl,
      createdAt: topic.createdAt,
      lastReplyAt: topic.lastReplyAt,
      lastReplySeq: topic.lastReplySeq,
      replyCount: topic.replyCount,
      state: topic.state,
      pinned: topic.pinned,
      pinnedAt: topic.pinnedAt,
      pinnedBy: topic.pinnedBy,
      groupPinned: topic.groupPinned,
      groupPinnedAt: topic.groupPinnedAt,
      groupPinnedBy: topic.groupPinnedBy,
      rootPreview: topic.rootPreview,
      rootContentType: topic.rootContentType,
      recentReplies: topic.recentReplies,
      userState: TopicUserState(
        userId: current?.userId ?? '',
        subscribed: subscribed ?? current?.subscribed ?? false,
        lastReadSeq: lastReadSeq ?? current?.lastReadSeq ?? 0,
        groupPinnedHidden: current?.groupPinnedHidden ?? false,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
      hasUnread: hasUnread ?? topic.hasUnread,
      hasMention: hasMention ?? topic.hasMention,
      version: topic.version,
      reactions: reactions ?? topic.reactions,
      editedAt: topic.editedAt,
      editedBy: topic.editedBy,
    );
  }
}
