import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_rust_demo/generated/rust/model/local.dart';
import 'package:flutter_rust_demo/domain/models/chat_message.dart'
    show ChatMessage;
import 'package:flutter_rust_demo/domain/models/group_read_receipt.dart'
    show GroupReadReceipt;
import 'package:flutter_rust_demo/application/chat/message_service_reducer.dart';
import 'package:flutter_rust_demo/application/chat/message_service_state.dart';

ChatMessage _message(String id, {int status = 2, int sendTime = 1000}) =>
    ChatMessage(
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
      sendTime: sendTime,
      createTime: 1000,
      status: status,
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
      final state = MessageServiceState().copyWith(uploadProgress: {'m1': 50});

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

  group('applyGroupReadReceipts', () {
    test('写入群回执并递增 groupRevision', () {
      final state = MessageServiceState();
      final receipt = const GroupReadReceipt(
        groupId: 'g1',
        msgId: 'm1',
        hasReadUserIdList: ['u1', 'u2'],
        hasReadCount: 2,
        groupMemberCount: 10,
        readTime: 1700000000000,
      );

      final result = MessageServiceReducer.applyGroupReadReceipts(state, [
        receipt,
      ]);

      expect(result.groupReadReceipts['m1']?.groupId, 'g1');
      expect(result.groupReadReceipts['m1']?.hasReadCount, 2);
      expect(result.groupRevision, 1);
    });

    test('空回执列表不改变状态', () {
      final state = MessageServiceState();
      final result = MessageServiceReducer.applyGroupReadReceipts(state, []);
      expect(identical(result, state), isTrue);
    });
  });

  group('发送状态机', () {
    ChatMessage sending(String id, {int sendTime = 1000}) =>
        _message(id, status: 1, sendTime: sendTime);

    test('applySendStatus 幂等：同值不改状态，找不到消息也不报错', () {
      final state = MessageServiceState().copyWith(
        messages: {
          'conv1': [sending('m1')],
        },
      );

      final failed = MessageServiceReducer.applySendStatus(
        state,
        'conv1',
        'm1',
        3,
      );
      expect(failed.messages['conv1']!.single.status, 3);
      // 重复置同一状态：返回原 state（幂等，不产生多余状态变更）
      expect(
        identical(
          MessageServiceReducer.applySendStatus(failed, 'conv1', 'm1', 3),
          failed,
        ),
        isTrue,
      );
      expect(
        identical(
          MessageServiceReducer.applySendStatus(state, 'conv1', 'nope', 3),
          state,
        ),
        isTrue,
      );
    });

    test('mergeSentMessage 就地合并服务端字段且保持本地 clientMsgId', () {
      final state = MessageServiceState().copyWith(
        messages: {
          'conv1': [sending('m1')],
        },
      );
      final sent = _message(
        'server-generated-id',
        status: 2,
      ).copyWith(serverMsgId: 'srv1', seq: 9);

      final result = MessageServiceReducer.mergeSentMessage(
        state,
        'conv1',
        'm1',
        sent,
      );

      final merged = result.messages['conv1']!.single;
      expect(merged.clientMsgId, 'm1');
      expect(merged.status, 2);
      expect(merged.serverMsgId, 'srv1');
      expect(merged.seq, 9);
      expect(result.messages['conv1'], hasLength(1));
    });

    test('sweepStaleSending 只把超时且无上传进度的发送中消息标失败', () {
      const timeout = 30000;
      final now = 1_700_000_000_000;
      final state = MessageServiceState().copyWith(
        messages: {
          'conv1': [
            sending('stale', sendTime: now - timeout - 1),
            sending('fresh', sendTime: now - 1000),
            sending('uploading', sendTime: now - timeout - 1),
            _message('done', status: 2),
            _message('failed', status: 3),
          ],
        },
        uploadProgress: {'uploading': 40},
      );

      final result = MessageServiceReducer.sweepStaleSending(
        state,
        'conv1',
        now: now,
      );

      final byId = {
        for (final m in result.messages['conv1']!) m.clientMsgId: m.status,
      };
      expect(byId['stale'], 3);
      expect(byId['fresh'], 1);
      expect(byId['uploading'], 1);
      expect(byId['done'], 2);
      expect(byId['failed'], 3);
    });

    test('sweepStaleSending 无僵尸时返回原 state', () {
      final now = 1_700_000_000_000;
      final state = MessageServiceState().copyWith(
        messages: {
          'conv1': [sending('fresh', sendTime: now - 100)],
        },
      );

      expect(
        identical(
          MessageServiceReducer.sweepStaleSending(state, 'conv1', now: now),
          state,
        ),
        isTrue,
      );
    });
  });
}
