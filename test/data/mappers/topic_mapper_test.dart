import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_rust_demo/data/mappers/topic_mapper.dart';
import 'package:flutter_rust_demo/domain/models/chat_message.dart';
import 'package:flutter_rust_demo/domain/models/group_mode.dart';
import 'package:flutter_rust_demo/domain/models/topic.dart';
import 'package:flutter_rust_demo/ui/chat/mappers/message_media.dart';

void main() {
  group('topic mapper', () {
    test('话题消息保留 topicID 并解码 Base64 content', () {
      final content = base64Encode(utf8.encode('{"content":"根消息"}'));
      final message = chatMessageFromTopicJson({
        'clientMsgID': 'topic_1',
        'sendID': 'u1',
        'groupID': 'g1',
        'sessionType': 3,
        'contentType': 101,
        'content': content,
        'seq': 12,
        'sendTime': 1700000000000,
        'topicID': 'topic_1',
      });

      expect(message.clientMsgId, 'topic_1');
      expect(message.topicId, 'topic_1');
      expect(message.content, '{"content":"根消息"}');
    });

    test('Feed 区分话题卡片和系统事件', () {
      final page = topicFeedPageFromJson({
        'items': [
          {
            'type': 1,
            'sortTime': 100,
            'topic': {
              'topicID': 't1',
              'groupID': 'g1',
              'replyCount': 2,
              'state': 1,
              'userState': {'subscribed': true},
            },
          },
          {
            'type': 2,
            'sortTime': 90,
            'systemEventID': 'event_1',
            'systemEventText': '成员加入',
          },
        ],
        'nextCursor': 'next',
        'hasMore': true,
      });

      expect(page.items, hasLength(2));
      expect(page.items.first.type, TopicFeedItemType.topic);
      expect(page.items.first.topic?.subscribed, isTrue);
      expect(page.items.last.type, TopicFeedItemType.system);
      expect(page.items.last.systemEventText, '成员加入');
      expect(page.nextCursor, 'next');
      expect(page.hasMore, isTrue);
    });

    test('枚举 wire value 与服务端 int32 编码一致', () {
      expect(TopicState.open.wireValue, 1);
      expect(TopicState.closed.wireValue, 2);
      expect(TopicState.revoked.wireValue, 3);
      expect(TopicTab.all.wireValue, 0);
      expect(TopicTab.subscribed.wireValue, 1);
      expect(GroupMode.topic.wireValue, 2);
      expect(GroupMode.chat.wireValue, 1);
    });

    test('会话话题汇总保留未读数和最新活动摘要', () {
      final summary = TopicGroupSummary.fromJson({
        'groupID': 'g1',
        'topicCount': 4,
        'unreadTopicCount': 2,
        'latestTopicID': 't4',
        'latestActivityAt': 1700000000000,
        'latestActivityPreview': '今晚发布',
        'latestActivityType': 2,
        'latestSenderName': '小萌',
      });

      expect(summary.topicCount, 4);
      expect(summary.unreadTopicCount, 2);
      expect(summary.latestTopicId, 't4');
      expect(summary.displayPreview, '小萌: 今晚发布');
    });

    test('自定义消息中的话题分享卡片可被识别', () {
      final payload = jsonEncode({
        'data': jsonEncode({
          'type': TopicShareCard.type,
          'groupID': 'g1',
          'topicID': 't1',
          'groupName': '项目群',
          'title': '发布计划',
          'creatorName': '张三',
          'replyCount': 3,
          'link': 'flutterrustdemo:///topic/t1?groupID=g1',
        }),
        'extension': 'openim_topic',
        'description': '项目群: 发布计划',
      });
      final message = ChatMessage(
        clientMsgId: 'm1',
        serverMsgId: 's1',
        sendId: 'u1',
        recvId: '',
        groupId: 'g1',
        senderPlatformId: 1,
        senderNickname: '张三',
        senderFaceUrl: '',
        sessionType: 3,
        msgFrom: 100,
        contentType: 110,
        content: payload,
        seq: 1,
        sendTime: 1,
        createTime: 1,
        status: 2,
        isRead: false,
        attachedInfo: '',
        ex: '',
      );

      expect(message.topicShareCard?.topicId, 't1');
      expect(message.topicShareCard?.groupName, '项目群');
      expect(message.topicShareCard?.replyCount, 3);
    });

    test('话题任务保留负责人、截止时间、优先级和状态', () {
      final task = TopicTask.fromJson({
        'taskID': 'task1',
        'topicID': 'topic1',
        'groupID': 'g1',
        'title': '确认发布包',
        'description': '完成真机验证',
        'creatorID': 'u1',
        'creatorNickname': '张三',
        'assigneeID': 'u2',
        'assigneeNickname': '李四',
        'dueAt': 1800000000000,
        'priority': 3,
        'status': 2,
        'createdAt': 1,
        'updatedAt': 2,
        'version': 2,
      });

      expect(task.assigneeNickname, '李四');
      expect(task.priority, TopicTaskPriority.high);
      expect(task.status, TopicTaskStatus.done);
      expect(task.version, 2);
    });
  });
}
