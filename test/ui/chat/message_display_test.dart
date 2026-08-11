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
