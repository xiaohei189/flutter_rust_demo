import '../../domain/models/group_mode.dart';
import '../../domain/models/topic.dart';
import '../../domain/models/topic_index_job.dart';
import '../services/topic_api.dart';

abstract class TopicRepository {
  Future<TopicFeedPage> getTopics({
    required String groupId,
    required TopicTab tab,
    String cursor = '',
    int count = 30,
  });

  Future<TopicGroupSummary?> getGroupSummary(String groupId);

  Future<TopicDetail> getTopic({
    required String groupId,
    required String topicId,
  });

  Future<TopicReplyPage> getReplies({
    required String topicId,
    required int beforeSeq,
    int count = 30,
  });

  Future<bool> setSubscription({
    required String topicId,
    required bool subscribed,
  });

  Future<int> markRead({required String topicId, required int lastReadSeq});

  Future<int> markUnread(String topicId);

  Future<int> markGroupRead(String groupId);

  Future<Topic> setPinned({
    required String topicId,
    required bool pinned,
    required int expectedVersion,
  });

  Future<Topic> setGroupPinned({
    required String topicId,
    required bool pinned,
    required int expectedVersion,
  });

  Future<Topic> changeState({
    required String topicId,
    required TopicState state,
    required int expectedVersion,
  });

  Future<Topic> editTopic({
    required String topicId,
    required String text,
    required int expectedVersion,
  });

  Future<TopicReactionState> setReaction({
    required String topicId,
    required String emoji,
    required bool active,
  });

  Future<TopicGroupModeProfile> setGroupMode({
    required String groupId,
    required GroupMode mode,
    int expectedVersion = 0,
  });

  Future<TopicGroupSettingsProfile> getGroupSettings(String groupId);

  Future<TopicGroupSettingsProfile> setGroupSettings({
    required String groupId,
    required TopicGroupSettings settings,
    required int expectedVersion,
  });

  Future<TopicSearchPage> searchTopics({
    required String groupId,
    required String keyword,
    TopicTab tab = TopicTab.all,
    TopicSearchFilter filter = const TopicSearchFilter(),
    String cursor = '',
    int count = 30,
  });

  Future<List<TopicTask>> getTopicTasks(String topicId);

  Future<TopicTask> createTopicTask({
    required String topicId,
    required String title,
    required String description,
    required String assigneeId,
    required int dueAt,
    required TopicTaskPriority priority,
  });

  Future<TopicTask> changeTopicTaskStatus({
    required String taskId,
    required TopicTaskStatus status,
    required int expectedVersion,
  });

  Future<TopicIndexJobPage> getIndexJobs({
    String groupId = '',
    String status = '',
    String cursor = '',
    int count = 50,
  });

  Future<TopicIndexJob> retryIndexJob(String jobId);

  Future<bool> deleteIndexJob(String jobId);
}

class TopicRepositoryImpl implements TopicRepository {
  TopicRepositoryImpl({required TopicApi api}) : _api = api;

  final TopicApi _api;

  @override
  Future<TopicFeedPage> getTopics({
    required String groupId,
    required TopicTab tab,
    String cursor = '',
    int count = 30,
  }) =>
      _api.getTopics(groupId: groupId, tab: tab, cursor: cursor, count: count);

  @override
  Future<TopicGroupSummary?> getGroupSummary(String groupId) =>
      _api.getGroupSummary(groupId);

  @override
  Future<TopicDetail> getTopic({
    required String groupId,
    required String topicId,
  }) => _api.getTopic(groupId: groupId, topicId: topicId);

  @override
  Future<TopicReplyPage> getReplies({
    required String topicId,
    required int beforeSeq,
    int count = 30,
  }) => _api.getReplies(topicId: topicId, beforeSeq: beforeSeq, count: count);

  @override
  Future<bool> setSubscription({
    required String topicId,
    required bool subscribed,
  }) => _api.setSubscription(topicId: topicId, subscribed: subscribed);

  @override
  Future<int> markRead({required String topicId, required int lastReadSeq}) =>
      _api.markRead(topicId: topicId, lastReadSeq: lastReadSeq);

  @override
  Future<int> markUnread(String topicId) => _api.markUnread(topicId);

  @override
  Future<int> markGroupRead(String groupId) => _api.markGroupRead(groupId);

  @override
  Future<Topic> setPinned({
    required String topicId,
    required bool pinned,
    required int expectedVersion,
  }) => _api.setPinned(
    topicId: topicId,
    pinned: pinned,
    expectedVersion: expectedVersion,
  );

  @override
  Future<Topic> setGroupPinned({
    required String topicId,
    required bool pinned,
    required int expectedVersion,
  }) => _api.setGroupPinned(
    topicId: topicId,
    pinned: pinned,
    expectedVersion: expectedVersion,
  );

  @override
  Future<Topic> changeState({
    required String topicId,
    required TopicState state,
    required int expectedVersion,
  }) => _api.changeState(
    topicId: topicId,
    state: state,
    expectedVersion: expectedVersion,
  );

  @override
  Future<Topic> editTopic({
    required String topicId,
    required String text,
    required int expectedVersion,
  }) => _api.editTopic(
    topicId: topicId,
    text: text,
    expectedVersion: expectedVersion,
  );

  @override
  Future<TopicReactionState> setReaction({
    required String topicId,
    required String emoji,
    required bool active,
  }) => _api.setReaction(topicId: topicId, emoji: emoji, active: active);

  @override
  Future<TopicGroupModeProfile> setGroupMode({
    required String groupId,
    required GroupMode mode,
    int expectedVersion = 0,
  }) => _api.setGroupMode(
    groupId: groupId,
    mode: mode,
    expectedVersion: expectedVersion,
  );

  @override
  Future<TopicGroupSettingsProfile> getGroupSettings(String groupId) =>
      _api.getGroupSettings(groupId);

  @override
  Future<TopicGroupSettingsProfile> setGroupSettings({
    required String groupId,
    required TopicGroupSettings settings,
    required int expectedVersion,
  }) => _api.setGroupSettings(
    groupId: groupId,
    settings: settings,
    expectedVersion: expectedVersion,
  );

  @override
  Future<TopicSearchPage> searchTopics({
    required String groupId,
    required String keyword,
    TopicTab tab = TopicTab.all,
    TopicSearchFilter filter = const TopicSearchFilter(),
    String cursor = '',
    int count = 30,
  }) => _api.searchTopics(
    groupId: groupId,
    keyword: keyword,
    tab: tab,
    filter: filter,
    cursor: cursor,
    count: count,
  );

  @override
  Future<List<TopicTask>> getTopicTasks(String topicId) =>
      _api.getTopicTasks(topicId);

  @override
  Future<TopicTask> createTopicTask({
    required String topicId,
    required String title,
    required String description,
    required String assigneeId,
    required int dueAt,
    required TopicTaskPriority priority,
  }) => _api.createTopicTask(
    topicId: topicId,
    title: title,
    description: description,
    assigneeId: assigneeId,
    dueAt: dueAt,
    priority: priority,
  );

  @override
  Future<TopicTask> changeTopicTaskStatus({
    required String taskId,
    required TopicTaskStatus status,
    required int expectedVersion,
  }) => _api.changeTopicTaskStatus(
    taskId: taskId,
    status: status,
    expectedVersion: expectedVersion,
  );

  @override
  Future<TopicIndexJobPage> getIndexJobs({
    String groupId = '',
    String status = '',
    String cursor = '',
    int count = 50,
  }) => _api.getIndexJobs(
    groupId: groupId,
    status: status,
    cursor: cursor,
    count: count,
  );

  @override
  Future<TopicIndexJob> retryIndexJob(String jobId) =>
      _api.retryIndexJob(jobId);

  @override
  Future<bool> deleteIndexJob(String jobId) => _api.deleteIndexJob(jobId);
}
