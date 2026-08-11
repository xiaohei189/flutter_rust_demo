import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_rust_demo/domain/models/conversation.dart';
import 'package:flutter_rust_demo/generated/rust/model/local.dart';

void main() {
  group('ConversationMapping', () {
    test('fromLocalConversation 完整转换字段', () {
      final raw = const LocalConversation(
        conversationId: 'si_user_a_user_b',
        conversationType: 1,
        userId: 'user_b',
        groupId: '',
        showName: '张三',
        faceUrl: 'https://example.com/avatar.png',
        latestMsg: '{"content":"你好"}',
        latestMsgSendTime: 1720000000000,
        unreadCount: 3,
        recvMsgOpt: 1,
        isPinned: true,
        isPrivateChat: false,
        burnDuration: 0,
        groupAtType: 0,
        isNotInGroup: false,
        updateUnreadCountTime: 1720000001000,
        attachedInfo: '{}',
        ex: 'ex',
        draftText: '{"text":"草稿"}',
        draftTextTime: 1720000002000,
        maxSeq: 12,
        minSeq: 3,
        isMsgDestruct: false,
        msgDestructTime: 0,
      );

      final conversation = ConversationMapping.fromLocalConversation(raw);

      expect(conversation.conversationId, 'si_user_a_user_b');
      expect(conversation.conversationType, 1);
      expect(conversation.userId, 'user_b');
      expect(conversation.groupId, '');
      expect(conversation.showName, '张三');
      expect(conversation.faceUrl, 'https://example.com/avatar.png');
      expect(conversation.latestMsg, '{"content":"你好"}');
      expect(conversation.latestMsgSendTime, 1720000000000);
      expect(conversation.unreadCount, 3);
      expect(conversation.recvMsgOpt, 1);
      expect(conversation.isPinned, isTrue);
      expect(conversation.isPrivateChat, isFalse);
      expect(conversation.burnDuration, 0);
      expect(conversation.groupAtType, 0);
      expect(conversation.isNotInGroup, isFalse);
      expect(conversation.updateUnreadCountTime, 1720000001000);
      expect(conversation.attachedInfo, '{}');
      expect(conversation.ex, 'ex');
      expect(conversation.draftText, '{"text":"草稿"}');
      expect(conversation.draftTextTime, 1720000002000);
      expect(conversation.maxSeq, 12);
      expect(conversation.minSeq, 3);
      expect(conversation.isMsgDestruct, isFalse);
      expect(conversation.msgDestructTime, 0);
    });
  });
}
