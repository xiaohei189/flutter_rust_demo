import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_rust_demo/ui/chat/utils/conversation_display.dart';

void main() {
  group('latestMessagePreview', () {
    test('空字符串返回暂无消息', () {
      expect(latestMessagePreview(''), '暂无消息');
    });

    test('纯文本直接返回', () {
      expect(latestMessagePreview('hello'), 'hello');
    });

    test('长纯文本截断', () {
      final long = 'a' * 100;
      final result = latestMessagePreview(long);
      expect(result.length, lessThan(long.length));
      expect(result, endsWith('…'));
    });

    test('文本消息 contentType=101', () {
      final json = jsonEncode({
        'contentType': 101,
        'senderNickname': '张三',
        'content': jsonEncode({'content': '你好'}),
      });
      final result = latestMessagePreview(json);
      expect(result, contains('你好'));
      expect(result, contains('张三'));
    });

    test('文本消息 textElem 结构', () {
      final json = jsonEncode({
        'contentType': 101,
        'senderNickname': '',
        'content': jsonEncode({
          'textElem': {'content': '测试消息'},
        }),
      });
      final result = latestMessagePreview(json);
      expect(result, contains('测试消息'));
    });

    test('图片消息', () {
      final json = jsonEncode({
        'contentType': 102,
        'senderNickname': '李四',
        'content': '{}',
      });
      expect(latestMessagePreview(json), contains('[图片]'));
    });

    test('语音消息', () {
      final json = jsonEncode({'contentType': 103, 'content': '{}'});
      expect(latestMessagePreview(json), '[语音]');
    });

    test('视频消息', () {
      final json = jsonEncode({'contentType': 104, 'content': '{}'});
      expect(latestMessagePreview(json), '[视频]');
    });

    test('文件消息', () {
      final json = jsonEncode({'contentType': 105, 'content': '{}'});
      expect(latestMessagePreview(json), '[文件]');
    });

    test('合并转发消息 107 → 聊天记录', () {
      final json = jsonEncode({'contentType': 107, 'content': '{}'});
      expect(latestMessagePreview(json), '[聊天记录]');
    });

    test('名片消息 108 → 名片', () {
      final json = jsonEncode({'contentType': 108, 'content': '{}'});
      expect(latestMessagePreview(json), '[名片]');
    });

    test('位置消息 109 → 位置', () {
      final json = jsonEncode({'contentType': 109, 'content': '{}'});
      expect(latestMessagePreview(json), '[位置]');
    });

    test('自定义消息 110 → 自定义', () {
      final json = jsonEncode({'contentType': 110, 'content': '{}'});
      expect(latestMessagePreview(json), '[自定义]');
    });

    test('引用消息 114 → 引用', () {
      final json = jsonEncode({'contentType': 114, 'content': '{}'});
      expect(latestMessagePreview(json), '[引用]');
    });

    test('表情消息 115 → 表情', () {
      final json = jsonEncode({'contentType': 115, 'content': '{}'});
      expect(latestMessagePreview(json), '[表情]');
    });

    test('富文本消息 117 提取文本内容', () {
      final json = jsonEncode({
        'contentType': 117,
        'content': jsonEncode({'content': '富文本正文'}),
      });
      expect(latestMessagePreview(json), contains('富文本正文'));
    });

    test('Markdown 消息 118 提取文本内容', () {
      final json = jsonEncode({
        'contentType': 118,
        'content': jsonEncode({'content': '# 标题'}),
      });
      expect(latestMessagePreview(json), contains('# 标题'));
    });

    test('未知 contentType 显示序号', () {
      final json = jsonEncode({'contentType': 999, 'content': '{}'});
      expect(latestMessagePreview(json), '[999]');
    });

    test('contentType=0 回退到 content 字段', () {
      final json = jsonEncode({'contentType': 0, 'content': '纯文本内容'});
      expect(latestMessagePreview(json), '纯文本内容');
    });

    test('content 为 Map 且无 text/content key 不输出原始 Map', () {
      final json = jsonEncode({
        'contentType': 0,
        'content': {'msgTips': 'yes'},
      });
      final result = latestMessagePreview(json);
      // 不应包含原始 Map 表示
      expect(result, isNot(contains('{')));
      // 应取到第一个字符串值
      expect(result, 'yes');
    });

    test('非 JSON 字符串直接返回', () {
      expect(latestMessagePreview('hello world'), 'hello world');
    });

    test('无效 JSON 返回原文截断', () {
      final result = latestMessagePreview('{invalid json');
      expect(result, contains('{invalid json'));
    });
  });
}
