import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_rust_demo/models/message.dart';
import 'package:flutter_rust_demo/models/message_ext.dart';
import 'package:flutter_rust_demo/src/rust/model/message.dart'
    show MessageInfo;

void main() {
  group('messageTypeFromContentType', () {
    test('101 → text', () {
      expect(messageTypeFromContentType(101), MessageType.text);
    });
    test('102 → image', () {
      expect(messageTypeFromContentType(102), MessageType.image);
    });
    test('103 → video', () {
      expect(messageTypeFromContentType(103), MessageType.video);
    });
    test('104 → audio', () {
      expect(messageTypeFromContentType(104), MessageType.audio);
    });
    test('105 → file', () {
      expect(messageTypeFromContentType(105), MessageType.file);
    });
    test('106 → location', () {
      expect(messageTypeFromContentType(106), MessageType.location);
    });
    test('107 → merge', () {
      expect(messageTypeFromContentType(107), MessageType.merge);
    });
    test('108 → card', () {
      expect(messageTypeFromContentType(108), MessageType.card);
    });
    test('114 → quote', () {
      expect(messageTypeFromContentType(114), MessageType.quote);
    });
    test('115 → face', () {
      expect(messageTypeFromContentType(115), MessageType.face);
    });
    test('10000 → system', () {
      expect(messageTypeFromContentType(10000), MessageType.system);
    });
    test('未知类型 → text（默认）', () {
      expect(messageTypeFromContentType(9999), MessageType.text);
    });
  });

  group('MessageSendStatus', () {
    test('fromValue 1 → sending', () {
      expect(MessageSendStatus.fromValue(1), MessageSendStatus.sending);
    });
    test('fromValue 2 → sendSuccess', () {
      expect(MessageSendStatus.fromValue(2), MessageSendStatus.sendSuccess);
    });
    test('fromValue 3 → sendFailed', () {
      expect(MessageSendStatus.fromValue(3), MessageSendStatus.sendFailed);
    });
    test('fromValue 4 → hasDeleted', () {
      expect(MessageSendStatus.fromValue(4), MessageSendStatus.hasDeleted);
    });
    test('未知值 → sending（默认）', () {
      expect(MessageSendStatus.fromValue(99), MessageSendStatus.sending);
    });
  });

  group('MessageInfoExt.parsedContent', () {
    MessageInfo msg0(String content) => MessageInfo(
          clientMsgId: 'id1',
          serverMsgId: 'sid1',
          sendId: 'user1',
          recvId: 'user2',
          groupId: '',
          senderPlatformId: 0,
          senderNickname: 'test',
          senderFaceUrl: '',
          sessionType: 1,
          msgFrom: 0,
          contentType: 101,
          content: content,
          seq: 0,
          sendTime: 1000,
          createTime: 1000,
          status: 0,
          isRead: false,
          attachedInfo: '',
          ex: '',
        );

    test('空 content 返回空 Map', () {
      expect(msg0('').parsedContent, isEmpty);
    });

    test('非 JSON content 返回空 Map', () {
      expect(msg0('plain text').parsedContent, isEmpty);
    });

    test('有效 JSON 解析', () {
      final m = msg0(jsonEncode({'content': 'hello', 'msgTips': 'yes'}));
      expect(m.parsedContent['content'], 'hello');
      expect(m.parsedContent['msgTips'], 'yes');
    });
  });

  group('MessageInfoExt.displayText', () {
    MessageInfo msg0(int contentType, String content) => MessageInfo(
          clientMsgId: 'id1',
          serverMsgId: 'sid1',
          sendId: 'user1',
          recvId: 'user2',
          groupId: '',
          senderPlatformId: 0,
          senderNickname: 'test',
          senderFaceUrl: '',
          sessionType: 1,
          msgFrom: 0,
          contentType: contentType,
          content: content,
          seq: 0,
          sendTime: 1000,
          createTime: 1000,
          status: 0,
          isRead: false,
          attachedInfo: '',
          ex: '',
        );

    test('文本消息取 content.content', () {
      final m = msg0(101, jsonEncode({'content': '你好'}));
      expect(m.displayText, '你好');
    });

    test('文本消息无 content key 回退到原始 content', () {
      final m = msg0(101, jsonEncode({'msgTips': 'yes'}));
      expect(m.displayText, contains('msgTips'));
    });

    test('Markdown 消息取 content.content', () {
      final m = msg0(118, jsonEncode({'content': '# 标题'}));
      expect(m.displayText, '# 标题');
    });

    test('引用消息取 text', () {
      final m = msg0(114, jsonEncode({'text': '引用内容'}));
      expect(m.displayText, '引用内容');
    });

    test('合并转发消息', () {
      final m = msg0(107, jsonEncode({
        'multiMessage': List.generate(5, (i) => {'text': 'm$i'}),
      }));
      expect(m.displayText, contains('5条消息'));
    });

    test('系统消息返回原始 content', () {
      final m = msg0(10000, '系统提示');
      expect(m.displayText, '系统提示');
    });
  });

  group('MessageInfoExt.sendDateTime', () {
    test('sendTime 为毫秒时间戳', () {
      final m = const MessageInfo(
        clientMsgId: 'id1',
        serverMsgId: 'sid1',
        sendId: 'user1',
        recvId: 'user2',
        groupId: '',
        senderPlatformId: 0,
        senderNickname: '',
        senderFaceUrl: '',
        sessionType: 1,
        msgFrom: 0,
        contentType: 101,
        content: '{}',
        seq: 0,
        sendTime: 1700000000000,
        createTime: 1700000000000,
        status: 0,
        isRead: false,
        attachedInfo: '',
        ex: '',
      );
      final dt = m.sendDateTime;
      expect(dt.year, 2023);
      expect(dt.month, 11);
    });

    test('sendTime 为 0 时使用 createTime', () {
      final m = const MessageInfo(
        clientMsgId: 'id1',
        serverMsgId: 'sid1',
        sendId: 'user1',
        recvId: 'user2',
        groupId: '',
        senderPlatformId: 0,
        senderNickname: '',
        senderFaceUrl: '',
        sessionType: 1,
        msgFrom: 0,
        contentType: 101,
        content: '{}',
        seq: 0,
        sendTime: 0,
        createTime: 1700000000000,
        status: 0,
        isRead: false,
        attachedInfo: '',
        ex: '',
      );
      final dt = m.sendDateTime;
      expect(dt.year, 2023);
    });
  });

  group('messageSentToInfo', () {
    test('正确构造 MessageInfo', () {
      final msg = messageSentToInfo(
        clientMsgId: 'c1',
        serverMsgId: 's1',
        sendTimeMs: 1700000000000,
        status: 2,
        conversationId: 'conv1',
        sendId: 'user1',
        recvId: 'user2',
        groupId: '',
        sessionType: 1,
        contentType: 101,
        content: '{"content":"hello"}',
        senderNickname: '测试',
        senderFaceUrl: '',
      );
      expect(msg.clientMsgId, 'c1');
      expect(msg.serverMsgId, 's1');
      expect(msg.status, 2);
      expect(msg.isRead, false);
      expect(msg.contentType, 101);
    });
  });

  group('sortMessagesByTime', () {
    MessageInfo msg(int seq, int sendTime) => MessageInfo(
          clientMsgId: 'm$seq',
          serverMsgId: '',
          sendId: 'u',
          recvId: 'v',
          groupId: '',
          senderPlatformId: 0,
          senderNickname: '',
          senderFaceUrl: '',
          sessionType: 1,
          msgFrom: 0,
          contentType: 101,
          content: '{"content":"x"}',
          seq: seq,
          sendTime: sendTime,
          createTime: sendTime,
          status: 2,
          isRead: false,
          attachedInfo: '',
          ex: '',
        );

    test('按 sendTime 升序', () {
      final sorted = sortMessagesByTime([msg(3, 3000), msg(1, 1000), msg(2, 2000)]);
      expect(sorted.map((m) => m.seq).toList(), [1, 2, 3]);
    });

    test('sendTime 相同按 seq 升序', () {
      final sorted = sortMessagesByTime([msg(2, 1000), msg(1, 1000)]);
      expect(sorted.map((m) => m.seq).toList(), [1, 2]);
    });

    test('空列表返回空', () {
      expect(sortMessagesByTime([]), isEmpty);
    });
  });
}
