import 'package:flutter/material.dart';
import 'package:flutter_rust_demo/ui/core/theme/topic_group_theme.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TopicGroupVisualTheme', () {
    test('同一群稳定复用同一主题色', () {
      final first = TopicGroupVisualTheme.forGroup(groupId: 'group-1');
      final second = TopicGroupVisualTheme.forGroup(groupId: 'group-1');

      expect(first.headerColor, second.headerColor);
    });

    test('不同群可以展示不同主题色', () {
      final colors = {
        for (var index = 0; index < 20; index++)
          TopicGroupVisualTheme.forGroup(groupId: 'group-$index').headerColor,
      };

      expect(colors.length, greaterThan(1));
    });

    test('群 ex 中的 themeColor 优先于默认色板', () {
      final theme = TopicGroupVisualTheme.forGroup(
        groupId: 'group-1',
        groupEx: '{"openim_topic":{"themeColor":"#123456"}}',
      );

      expect(theme.headerColor, const Color(0xFF123456));
      expect(theme.foregroundColor, const Color(0xFFFFFFFF));
    });
  });
}
