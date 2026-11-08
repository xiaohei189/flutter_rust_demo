import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_rust_demo/data/repositories/topic_repository.dart';
import 'package:flutter_rust_demo/domain/models/chat_message.dart';
import 'package:flutter_rust_demo/domain/models/group_mode.dart';
import 'package:flutter_rust_demo/domain/models/topic.dart';
import 'package:flutter_rust_demo/domain/models/topic_index_job.dart';
import 'package:flutter_rust_demo/ui/topics/providers/topic_provider.dart';

class _FakeTopicRepository implements TopicRepository {
  _FakeTopicRepository(this.pages);

  final List<TopicReplyPage> pages;
  int _pageIndex = 0;

  @override
  Future<TopicDetail> getTopic({
    required String groupId,
    required String topicId,
  }) async => TopicDetail(
    topic: Topic(
      topicId: topicId,
      groupId: groupId,
      rootClientMsgId: topicId,
      rootSeq: 1,
      creatorId: 'u1',
      creatorNickname: '作者',
      creatorFaceUrl: '',
      createdAt: 1,
      lastReplyAt: 3,
      lastReplySeq: 3,
      replyCount: 3,
      state: TopicState.open,
      pinned: false,
      pinnedAt: 0,
      pinnedBy: '',
      rootPreview: '根话题',
      rootContentType: 101,
      recentReplies: const [],
      userState: null,
      hasUnread: false,
      version: 1,
    ),
    rootMessage: _message('root', 1),
  );

  @override
  Future<TopicGroupSummary?> getGroupSummary(String groupId) async => null;

  @override
  Future<TopicReplyPage> getReplies({
    required String topicId,
    required int beforeSeq,
    int count = 30,
  }) async => pages[_pageIndex++];

  @override
  Future<int> markRead({
    required String topicId,
    required int lastReadSeq,
  }) async => lastReadSeq;

  @override
  Future<int> markUnread(String topicId) async => 0;

  @override
  Future<int> markGroupRead(String groupId) async => 0;

  @override
  Future<Topic> changeState({
    required String topicId,
    required TopicState state,
    required int expectedVersion,
  }) => throw UnimplementedError();

  @override
  Future<Topic> editTopic({
    required String topicId,
    required String text,
    required int expectedVersion,
  }) => throw UnimplementedError();

  @override
  Future<TopicReactionState> setReaction({
    required String topicId,
    required String emoji,
    required bool active,
  }) => throw UnimplementedError();

  @override
  Future<TopicFeedPage> getTopics({
    required String groupId,
    required TopicTab tab,
    String cursor = '',
    int count = 30,
  }) => throw UnimplementedError();

  @override
  Future<TopicSearchPage> searchTopics({
    required String groupId,
    required String keyword,
    TopicTab tab = TopicTab.all,
    TopicSearchFilter filter = const TopicSearchFilter(),
    String cursor = '',
    int count = 30,
  }) => throw UnimplementedError();

  @override
  Future<List<TopicTask>> getTopicTasks(String topicId) async => const [];

  @override
  Future<TopicTask> createTopicTask({
    required String topicId,
    required String title,
    required String description,
    required String assigneeId,
    required int dueAt,
    required TopicTaskPriority priority,
  }) => throw UnimplementedError();

  @override
  Future<TopicTask> changeTopicTaskStatus({
    required String taskId,
    required TopicTaskStatus status,
    required int expectedVersion,
  }) => throw UnimplementedError();

  @override
  Future<TopicGroupModeProfile> setGroupMode({
    required String groupId,
    required GroupMode mode,
    int expectedVersion = 0,
  }) => throw UnimplementedError();

  @override
  Future<TopicGroupSettingsProfile> getGroupSettings(String groupId) =>
      throw UnimplementedError();

  @override
  Future<TopicGroupSettingsProfile> setGroupSettings({
    required String groupId,
    required TopicGroupSettings settings,
    required int expectedVersion,
  }) => throw UnimplementedError();

  @override
  Future<Topic> setPinned({
    required String topicId,
    required bool pinned,
    required int expectedVersion,
  }) => throw UnimplementedError();

  @override
  Future<Topic> setGroupPinned({
    required String topicId,
    required bool pinned,
    required int expectedVersion,
  }) => throw UnimplementedError();

  @override
  Future<bool> setSubscription({
    required String topicId,
    required bool subscribed,
  }) => throw UnimplementedError();

  @override
  Future<TopicIndexJobPage> getIndexJobs({
    String groupId = '',
    String status = '',
    String cursor = '',
    int count = 50,
  }) => throw UnimplementedError();

  @override
  Future<TopicIndexJob> retryIndexJob(String jobId) =>
      throw UnimplementedError();

  @override
  Future<bool> deleteIndexJob(String jobId) => throw UnimplementedError();
}

ChatMessage _message(String id, int seq) => ChatMessage(
  clientMsgId: id,
  serverMsgId: '',
  sendId: 'u1',
  recvId: '',
  groupId: 'g1',
  senderPlatformId: 1,
  senderNickname: '作者',
  senderFaceUrl: '',
  sessionType: 3,
  msgFrom: 100,
  contentType: 101,
  content: '{"content":"$id"}',
  seq: seq,
  sendTime: seq,
  createTime: seq,
  status: 2,
  isRead: true,
  attachedInfo: '',
  ex: '',
  topicId: 't1',
);

TopicReply _reply(String id, int seq) =>
    TopicReply(message: _message(id, seq), revoked: false);

void main() {
  const args = (groupId: 'g1', topicId: 't1');

  ProviderContainer buildContainer(_FakeTopicRepository repository) {
    final container = ProviderContainer(
      overrides: [topicRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('初次加载把最新在前的回复转换为时间正序', () async {
    final repository = _FakeTopicRepository([
      TopicReplyPage(
        replies: [_reply('r3', 4), _reply('r2', 3)],
        nextBeforeSeq: 3,
        hasMore: true,
      ),
    ]);
    final notifier = buildContainer(
      repository,
    ).read(topicDetailProvider(args).notifier);

    await notifier.load();

    expect(notifier.state.replies.map((item) => item.message.clientMsgId), [
      'r2',
      'r3',
    ]);
  });

  test('加载更早回复时正序前插到现有时间线', () async {
    final repository = _FakeTopicRepository([
      TopicReplyPage(
        replies: [_reply('r3', 4), _reply('r2', 3)],
        nextBeforeSeq: 3,
        hasMore: true,
      ),
      TopicReplyPage(
        replies: [_reply('r1', 2), _reply('r0', 1)],
        nextBeforeSeq: 1,
        hasMore: false,
      ),
    ]);
    final notifier = buildContainer(
      repository,
    ).read(topicDetailProvider(args).notifier);

    await notifier.load();
    await notifier.loadMore();

    expect(notifier.state.replies.map((item) => item.message.clientMsgId), [
      'r0',
      'r1',
      'r2',
      'r3',
    ]);
    expect(notifier.state.hasMore, isFalse);
  });
}
