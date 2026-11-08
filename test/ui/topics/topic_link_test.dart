import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_rust_demo/domain/models/topic.dart';
import 'package:flutter_rust_demo/ui/topics/utils/topic_link.dart';

void main() {
  test('话题深链往返保留 groupID 和 topicID', () {
    final link = buildTopicLink(groupId: 'group 1', topicId: 'topic/1');
    final parsed = parseTopicLink(Uri.parse(link));

    expect(parsed, isNotNull);
    expect(parsed!.groupId, 'group 1');
    expect(parsed.topicId, 'topic/1');
  });

  test('非本应用或其他路径的链接不识别为话题', () {
    expect(parseTopicLink(Uri.parse('https://example.com/topic/t1')), isNull);
    expect(
      parseTopicLink(Uri.parse('flutterrustdemo:///chat/c1?message=m1')),
      isNull,
    );
  });

  test('分享卡片包含群名、摘要、作者、回复数和可打开链接', () {
    const topic = Topic(
      topicId: 't1',
      groupId: 'g1',
      rootClientMsgId: 't1',
      rootSeq: 2,
      creatorId: 'u1',
      creatorNickname: '张三',
      creatorFaceUrl: '',
      createdAt: 1,
      lastReplyAt: 2,
      lastReplySeq: 3,
      replyCount: 2,
      state: TopicState.open,
      pinned: false,
      pinnedAt: 0,
      pinnedBy: '',
      rootPreview: '发布计划',
      rootContentType: 101,
      recentReplies: [],
      userState: null,
      hasUnread: false,
      version: 1,
    );

    final card = buildTopicShareCard(topic: topic, groupName: '项目群');
    expect(card.groupId, 'g1');
    expect(card.topicId, 't1');
    expect(card.groupName, '项目群');
    expect(card.title, '发布计划');
    expect(card.creatorName, '张三');
    expect(card.replyCount, 2);
    expect(parseTopicLink(Uri.parse(card.link))?.topicId, 't1');

    final snapshot = buildTopicShareCard(
      topic: topic,
      groupName: '项目群',
      replies: const [
        TopicShareReply(seq: 3, senderName: '李四', content: '已确认', sendTime: 3),
      ],
      snapshotComplete: false,
    );
    final restored = TopicShareCard.fromJson(snapshot.toJson());
    expect(restored.replies.single.senderName, '李四');
    expect(restored.replies.single.content, '已确认');
    expect(restored.snapshotComplete, isFalse);
  });
}
