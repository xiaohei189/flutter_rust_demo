import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_rust_demo/domain/models/conversation_draft.dart';

void main() {
  group('ConversationDraft.textOf', () {
    test('空字符串返回 null', () {
      expect(ConversationDraft.textOf(''), isNull);
    });

    test('JSON 含非空 text 返回文本', () {
      expect(ConversationDraft.textOf('{"text":"草稿"}'), '草稿');
    });

    test('JSON 无 text key 返回 null', () {
      expect(ConversationDraft.textOf('{"other":1}'), isNull);
    });

    test('JSON text 为空字符串返回 null', () {
      expect(ConversationDraft.textOf('{"text":""}'), isNull);
    });

    test('非 JSON 原样返回（兼容旧数据纯文本）', () {
      expect(ConversationDraft.textOf('纯文本草稿'), '纯文本草稿');
    });

    test('非法 JSON 原样返回', () {
      expect(ConversationDraft.textOf('{invalid'), '{invalid');
    });
  });

  group('ConversationDraft.encode', () {
    test('编码为 text JSON', () {
      expect(ConversationDraft.encode('你好'), '{"text":"你好"}');
    });

    test('encode 与 textOf 互逆', () {
      final encoded = ConversationDraft.encode('晚上见');
      expect(ConversationDraft.textOf(encoded), '晚上见');
    });
  });
}
