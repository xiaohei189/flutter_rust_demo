import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_rust_demo/domain/models/message.dart';
import 'package:flutter_rust_demo/domain/extensions/message_ext.dart';
import 'package:flutter_rust_demo/generated/rust/model/local.dart'
    show LocalChatLog;
import 'package:flutter_rust_demo/generated/rust/model/message.dart'
    show MessageInfo;

void main() {
  group('messageTypeFromContentType', () {
    test('101 → text', () {
      expect(messageTypeFromContentType(101), MessageType.text);
    });
    test('102 → image', () {
      expect(messageTypeFromContentType(102), MessageType.image);
    });
    test('103 → audio（语音）', () {
      expect(messageTypeFromContentType(103), MessageType.audio);
    });
    test('104 → video（视频）', () {
      expect(messageTypeFromContentType(104), MessageType.video);
    });
    test('105 → file', () {
      expect(messageTypeFromContentType(105), MessageType.file);
    });
    test('106 → at（@消息）', () {
      expect(messageTypeFromContentType(106), MessageType.at);
    });
    test('109 → location（位置）', () {
      expect(messageTypeFromContentType(109), MessageType.location);
    });
    test('117 → advancedText（富文本）', () {
      expect(messageTypeFromContentType(117), MessageType.advancedText);
    });
    test('118 → markdown', () {
      expect(messageTypeFromContentType(118), MessageType.markdown);
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
    test('1203 好友申请通知 → system', () {
      expect(messageTypeFromContentType(1203), MessageType.system);
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
      final m = msg0(
        107,
        jsonEncode({
          'multiMessage': List.generate(5, (i) => {'text': 'm$i'}),
        }),
      );
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
      final sorted = sortMessagesByTime([
        msg(3, 3000),
        msg(1, 1000),
        msg(2, 2000),
      ]);
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
  group('LocalChatLogExt.displayText', () {
    LocalChatLog log0(int contentType, String content) => LocalChatLog(
      conversationId: 'c1',
      clientMsgId: 'id1',
      serverMsgId: 'sid1',
      sendId: 'user1',
      recvId: 'user2',
      senderPlatformId: 0,
      senderNickName: 'test',
      senderFaceUrl: '',
      sessionType: 1,
      msgFrom: 0,
      contentType: contentType,
      content: content,
      isRead: 0,
      status: 2,
      seq: 1,
      sendTime: 1700000000000,
      createTime: 1700000000000,
      attachedInfo: '',
      ex: '',
      localEx: '',
      groupId: '',
    );

    test('文本消息取 content.content', () {
      final log = log0(101, jsonEncode({'content': '搜索到你好'}));
      expect(log.displayText, '搜索到你好');
    });

    test('图片消息显示占位文本而不是原始 JSON', () {
      final log = log0(
        102,
        jsonEncode({
          'bigPicture': {'url': 'x.jpg'},
        }),
      );
      expect(log.displayText, '[图片]');
    });

    test('系统消息返回可读文本', () {
      final log = log0(10000, jsonEncode({'content': '对方已撤回'}));
      expect(log.displayText, '对方已撤回');
    });

    test('好友申请通知从 detail 提取 reqMsg', () {
      final log = log0(
        1203,
        jsonEncode({
          'detail': jsonEncode({
            'request': {'reqMsg': '重复添加'},
          }),
        }),
      );
      expect(log.messageType, MessageType.system);
      expect(log.displayText, '重复添加');
    });
  });

  group('mergeSubMessageFromJson', () {
    test('Rust camelCase 字段映射', () {
      final sub = mergeSubMessageFromJson({
        'clientMsgId': 'rust-id',
        'serverMsgId': 'srv-id',
        'sendID': 'user_1',
        'recvID': 'user_2',
        'groupId': '',
        'senderNickname': '张三',
        'senderFaceUrl': 'http://a/avatar.png',
        'sessionType': 2,
        'contentType': 101,
        'content': jsonEncode({'content': '你好'}),
        'sendTime': 1700000000000,
        'createTime': 1700000000000,
        'status': 2,
      });
      expect(sub.clientMsgId, 'rust-id');
      expect(sub.sendId, 'user_1');
      expect(sub.recvId, 'user_2');
      expect(sub.senderNickname, '张三');
      expect(sub.senderFaceUrl, 'http://a/avatar.png');
      expect(sub.sessionType, 2);
      expect(sub.messageType, MessageType.text);
      expect(sub.sendTime, 1700000000000);
      expect(sub.status, 2);
    });

    test('Go SDK 大写 ID 字段映射', () {
      final sub = mergeSubMessageFromJson({
        'clientMsgID': 'go-id',
        'serverMsgID': 'srv-go',
        'sendID': 'go_sender',
        'recvID': 'go_receiver',
        'groupID': 'group_1',
        'senderPlatformID': 3,
        'senderNickname': '李四',
        'sessionType': 2,
        'contentType': 102,
        'content': jsonEncode({
          'sourcePicture': {'url': 'http://img/1.png'},
        }),
      });
      expect(sub.clientMsgId, 'go-id');
      expect(sub.serverMsgId, 'srv-go');
      expect(sub.sendId, 'go_sender');
      expect(sub.recvId, 'go_receiver');
      expect(sub.groupId, 'group_1');
      expect(sub.senderPlatformId, 3);
      expect(sub.messageType, MessageType.image);
    });

    test('缺失字段使用默认值', () {
      final sub = mergeSubMessageFromJson({'contentType': 101});
      expect(sub.clientMsgId, '');
      expect(sub.sendId, '');
      expect(sub.sessionType, 1);
      expect(sub.sendTime, 0);
      expect(sub.content, '');
    });

    test('Go SDK 子消息 content 为空时从 pictureElem 还原图片', () {
      final sub = mergeSubMessageFromJson({
        'clientMsgID': 'go-img',
        'sendID': 'u1',
        'contentType': 102,
        'content': '',
        'pictureElem': {
          'sourcePath': '',
          'sourcePicture': {
            'url': 'http://img.example.com/a.png',
            'width': 640,
            'height': 640,
          },
          'bigPicture': {'url': 'http://img.example.com/b.png'},
          'snapshotPicture': {'url': 'http://img.example.com/s.png'},
        },
      });
      expect(sub.messageType, MessageType.image);
      final pic = sub.parsedContent['sourcePicture'] as Map<String, dynamic>;
      expect(pic['url'], 'http://img.example.com/a.png');
      expect(sub.displayImageSource, 'http://img.example.com/a.png');
    });

    test('Go SDK 子消息 content 为空时从 textElem 还原文本', () {
      final sub = mergeSubMessageFromJson({
        'clientMsgID': 'go-text',
        'sendID': 'u1',
        'contentType': 101,
        'content': '',
        'textElem': {'content': '来自 textElem 的文本'},
      });
      expect(sub.messageType, MessageType.text);
      expect(sub.displayText, '来自 textElem 的文本');
    });

    test('content 非空时优先使用 content', () {
      final sub = mergeSubMessageFromJson({
        'clientMsgID': 'mix',
        'contentType': 101,
        'content': jsonEncode({'content': 'content 字段'}),
        'textElem': {'content': 'textElem 字段'},
      });
      expect(sub.displayText, 'content 字段');
    });
  });
}
