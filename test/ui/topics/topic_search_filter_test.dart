import 'package:flutter_rust_demo/domain/models/topic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TopicSearchFilter', () {
    test('默认筛选不激活且使用 any 状态', () {
      const filter = TopicSearchFilter();

      expect(filter.isActive, isFalse);
      expect(filter.stateWireValue, 0);
    });

    test('组合筛选可保持并清除单个条件', () {
      final filter = const TopicSearchFilter(
        authorId: 'user_1',
        createdAfter: 100,
        state: TopicSearchState.closed,
        hasAttachments: true,
        hasTasks: true,
        pinnedOnly: true,
        groupPinnedOnly: true,
      );
      final cleared = filter.copyWith(
        clearAuthor: true,
        clearCreatedAfter: true,
      );

      expect(filter.isActive, isTrue);
      expect(cleared.authorId, isEmpty);
      expect(cleared.createdAfter, 0);
      expect(cleared.state, TopicSearchState.closed);
      expect(cleared.hasAttachments, isTrue);
      expect(cleared.hasTasks, isTrue);
      expect(cleared.pinnedOnly, isTrue);
      expect(cleared.groupPinnedOnly, isTrue);
      expect(cleared.stateWireValue, 2);
    });
  });

  test('话题群设置缺省为开启并保留服务端版本', () {
    final profile = TopicGroupSettingsProfile.fromJson({
      'settings': {'allowMemberReply': false},
      'version': 7,
    });

    expect(profile.version, 7);
    expect(profile.settings.allowMemberPublish, isTrue);
    expect(profile.settings.allowMemberReply, isFalse);
    expect(profile.settings.defaultSubscribe, isTrue);
    expect(profile.settings.allowMemberPin, isTrue);
    expect(profile.settings.allowMemberGroupPin, isTrue);
  });

  test('话题保留 @我 状态', () {
    final topic = Topic.fromJson({
      'topicID': 'topic_1',
      'groupID': 'group_1',
      'hasMention': true,
      'pinned': true,
      'groupPinned': true,
    });

    expect(topic.hasMention, isTrue);
    expect(topic.pinned, isTrue);
    expect(topic.groupPinned, isTrue);
  });
}
