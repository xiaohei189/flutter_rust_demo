import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_rust_demo/domain/models/conversation.dart';
import 'package:flutter_rust_demo/domain/models/conversation_flags.dart';

Conversation _conversation({String ex = '', int unreadCount = 0}) =>
    Conversation(
      conversationId: 'c1',
      conversationType: 1,
      userId: 'u1',
      groupId: '',
      showName: '会话',
      faceUrl: '',
      latestMsg: '',
      latestMsgSendTime: 0,
      unreadCount: unreadCount,
      recvMsgOpt: 0,
      isPinned: false,
      isPrivateChat: false,
      burnDuration: 0,
      groupAtType: 0,
      isNotInGroup: false,
      updateUnreadCountTime: 0,
      attachedInfo: '',
      ex: ex,
      draftText: '',
      draftTextTime: 0,
      maxSeq: 0,
      minSeq: 0,
      isMsgDestruct: false,
      msgDestructTime: 0,
    );

void main() {
  group('ConversationFlags.parse', () {
    test('空字符串返回空标记', () {
      final flags = ConversationFlags.parse('');
      expect(flags.flagged, isFalse);
      expect(flags.done, isFalse);
      expect(flags.markedUnread, isFalse);
      expect(flags.archived, isFalse);
    });

    test('非法 JSON 返回空标记', () {
      final flags = ConversationFlags.parse('not-json');
      expect(flags, ConversationFlags.empty);
    });

    test('解析各标记位', () {
      final flags = ConversationFlags.parse(
        '{"flagged":true,"done":false,"unread":true,"archived":true}',
      );
      expect(flags.flagged, isTrue);
      expect(flags.done, isFalse);
      expect(flags.markedUnread, isTrue);
      expect(flags.archived, isTrue);
    });

    test('非布尔值按 false 处理', () {
      final flags = ConversationFlags.parse('{"flagged":"yes"}');
      expect(flags.flagged, isFalse);
    });
  });

  group('ConversationFlags.fromConversation', () {
    test('从会话 ex 字段解析', () {
      final conversation = _conversation(ex: '{"archived":true}');
      final flags = ConversationFlags.fromConversation(conversation);
      expect(flags.archived, isTrue);
    });
  });

  group('ConversationFlags.copyWith', () {
    test('只更新指定标记', () {
      final flags = ConversationFlags.parse('{"flagged":true}');
      final updated = flags.copyWith(markedUnread: true);
      expect(updated.flagged, isTrue);
      expect(updated.markedUnread, isTrue);
      expect(updated.done, isFalse);
    });
  });

  group('ConversationFlags.encodeMerged', () {
    test('合并进现有 ex 并保留其他 key', () {
      final flags = ConversationFlags.parse('{"flagged":true}');
      final ex = flags.copyWith(markedUnread: true).encodeMerged(
        '{"custom":"保留"}',
      );
      expect(ex, contains('"flagged":true'));
      expect(ex, contains('"unread":true'));
      expect(ex, contains('"custom":"保留"'));
    });

    test('空 ex 时生成全新标记 JSON', () {
      final ex = const ConversationFlags(flagged: true, done: false)
          .encodeMerged('');
      expect(ex, contains('"flagged":true'));
      expect(ex, contains('"done":false'));
    });
  });

  group('ConversationFlags.effectiveUnreadCount', () {
    test('本地标未读时至少显示 1', () {
      final marked = _conversation(
        ex: ConversationFlags.empty
            .copyWith(markedUnread: true)
            .encodeMerged(''),
        unreadCount: 0,
      );
      expect(ConversationFlags.fromConversation(marked).effectiveUnreadCount(marked), 1);
    });

    test('未标未读时返回原始未读数', () {
      final plain = _conversation(unreadCount: 5);
      expect(ConversationFlags.fromConversation(plain).effectiveUnreadCount(plain), 5);
    });
  });
}
