import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_rust_demo/data/mappers/message_mapper.dart';
import 'package:flutter_rust_demo/generated/rust/event/events/message.dart' as generated_events;

void main() {
  group('groupReadReceiptsFromGenerated', () {
    test('完整映射 generated 回执到领域模型', () {
      final raw = generated_events.GroupReadReceipt(
        groupId: 'g1',
        msgId: 'm1',
        hasReadUserIdList: ['u1', 'u2'],
        hasReadCount: 2,
        groupMemberCount: 10,
        readTime: 1700000000000,
      );

      final result = groupReadReceiptsFromGenerated([raw]).single;

      expect(result.groupId, 'g1');
      expect(result.msgId, 'm1');
      expect(result.hasReadUserIdList, ['u1', 'u2']);
      expect(result.hasReadCount, 2);
      expect(result.groupMemberCount, 10);
      expect(result.readTime, 1700000000000);
    });

    test('空输入返回空列表', () {
      expect(groupReadReceiptsFromGenerated([]), isEmpty);
    });
  });
}