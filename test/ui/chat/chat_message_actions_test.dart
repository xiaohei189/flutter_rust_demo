import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_rust_demo/domain/models/chat_message.dart'
    show ChatMessage;
import 'package:flutter_rust_demo/ui/chat/widgets/menu/chat_message_actions.dart';
import 'package:flutter_rust_demo/ui/chat/widgets/menu/message_hover_toolbar.dart'
    show MessageReactionGroup;

ChatMessage _message(String id) => ChatMessage(
  clientMsgId: id,
  serverMsgId: '',
  sendId: 'user_a',
  recvId: 'user_b',
  groupId: '',
  senderPlatformId: 0,
  senderNickname: '张三',
  senderFaceUrl: '',
  sessionType: 1,
  msgFrom: 0,
  contentType: 101,
  content: '{"content":"hi"}',
  seq: 0,
  sendTime: 0,
  createTime: 0,
  status: 2,
  isRead: false,
  attachedInfo: '',
  ex: '',
);

void main() {
  test('首次点击添加“我”的 reaction', () {
    final reactions = <String, List<MessageReactionGroup>>{};
    toggleMessageReaction(reactions, _message('m1'), '👍');
    final groups = reactions['m1']!;
    expect(groups, hasLength(1));
    expect(groups.first.emoji, '👍');
    expect(groups.first.count, 1);
    expect(groups.first.names, ['我']);
  });

  test('再次点击移除“我”的 reaction', () {
    final reactions = <String, List<MessageReactionGroup>>{
      'm1': [
        const MessageReactionGroup(emoji: '👍', count: 1, names: ['我']),
      ],
    };
    toggleMessageReaction(reactions, _message('m1'), '👍');
    expect(reactions['m1'], isEmpty);
  });

  test('非我点击增加 count 并追加“我”', () {
    final reactions = <String, List<MessageReactionGroup>>{
      'm1': [
        const MessageReactionGroup(emoji: '👍', count: 2, names: ['李四', '王五']),
      ],
    };
    toggleMessageReaction(reactions, _message('m1'), '👍');
    final group = reactions['m1']!.single;
    expect(group.count, 3);
    expect(group.names, ['李四', '王五', '我']);
  });
}
