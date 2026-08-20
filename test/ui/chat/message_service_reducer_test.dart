import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_rust_demo/generated/rust/model/local.dart';
import 'package:flutter_rust_demo/domain/models/chat_message.dart' show ChatMessage;
import 'package:flutter_rust_demo/application/chat/message_service_reducer.dart';
import 'package:flutter_rust_demo/application/chat/message_service_state.dart';

ChatMessage _message(String id) => ChatMessage(
  clientMsgId: id,
  serverMsgId: '',
  sendId: 'u1',
  recvId: 'u2',
  groupId: '',
  senderPlatformId: 0,
  senderNickname: '我',
  senderFaceUrl: '',
  sessionType: 1,
  msgFrom: 0,
  contentType: 101,
  content: '{"content":"你好"}',
  seq: 1,
  sendTime: 1000,
  createTime: 1000,
  status: 2,
  isRead: false,
  attachedInfo: '',
  ex: '',
);

void main() {
  group('MessageServiceReducer', () {
    test('appendIncomingMessage 追加新消息并去重', () {
      final state = MessageServiceState();

      final added = MessageServiceReducer.appendIncomingMessage(
        state,
        'conv1',
        _message('m1'),
      );
      final duplicated = MessageServiceReducer.appendIncomingMessage(
        added,
        'conv1',
        _message('m1'),
      );

      expect(duplicated.messages['conv1'], hasLength(1));
      expect(duplicated.messages['conv1']!.first.clientMsgId, 'm1');
    });

    test('removeMessage 只移除指定消息', () {
      final state = MessageServiceState().copyWith(
        messages: {
          'conv1': [_message('m1'), _message('m2')],
        },
      );

      final result = MessageServiceReducer.removeMessage(state, 'conv1', 'm1');

      expect(result.messages['conv1'], hasLength(1));
      expect(result.messages['conv1']!.first.clientMsgId, 'm2');
    });

    test('applyDeleted 删除多条消息', () {
      final state = MessageServiceState().copyWith(
        messages: {
          'conv1': [_message('m1'), _message('m2'), _message('m3')],
        },
      );

      final result = MessageServiceReducer.applyDeleted(state, 'conv1', [
        'm1',
        'm3',
      ]);

      expect(result.messages['conv1'], hasLength(1));
      expect(result.messages['conv1']!.first.clientMsgId, 'm2');
    });

    test('applySendFailed 标记失败并移除上传进度', () {
      final state = MessageServiceState().copyWith(
        messages: {
          'conv1': [_message('m1')],
        },
        uploadProgress: {'m1': 50},
      );

      final result = MessageServiceReducer.applySendFailed(state, 'm1');

      expect(result.messages['conv1']!.first.status, 3);
      expect(result.uploadProgress.containsKey('m1'), isFalse);
    });

    test('applyUploadProgress 完成时移除进度', () {
      final state = MessageServiceState().copyWith(
        uploadProgress: {'m1': 50},
      );

      final result = MessageServiceReducer.applyUploadProgress(
        state,
        'm1',
        100,
      );

      expect(result.uploadProgress.containsKey('m1'), isFalse);
    });

    test('applyConversationEvent 合并会话列表', () {
      final state = MessageServiceState();
      const raw = LocalConversation(
        conversationId: 'si_user_a_user_b',
        conversationType: 1,
        userId: 'user_b',
        groupId: '',
        showName: '张三',
        faceUrl: '',
        latestMsg: '{"content":"你好"}',
        latestMsgSendTime: 1720000000000,
        unreadCount: 1,
        recvMsgOpt: 0,
        isPinned: false,
        isPrivateChat: false,
        burnDuration: 0,
        groupAtType: 0,
        isNotInGroup: false,
        updateUnreadCountTime: 1720000001000,
        attachedInfo: '',
        ex: '',
        draftText: '',
        draftTextTime: 0,
        maxSeq: 1,
        minSeq: 0,
        isMsgDestruct: false,
        msgDestructTime: 0,
      );

      final result = MessageServiceReducer.applyConversationEvent(state, [raw]);

      expect(result.conversations, hasLength(1));
      expect(result.conversations.first.showName, '张三');
    });
  });
}
