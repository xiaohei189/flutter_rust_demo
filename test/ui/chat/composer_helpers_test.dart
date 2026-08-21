import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_rust_demo/domain/models/group_member.dart';
import 'package:flutter_rust_demo/ui/chat/widgets/composer/at_member_query.dart';
import 'package:flutter_rust_demo/ui/chat/widgets/composer/format_toolbar.dart'
    show MarkdownFormat;
import 'package:flutter_rust_demo/ui/chat/widgets/composer/markdown_editor.dart';

GroupMember _member(String userId, String nickname) => GroupMember(
  groupId: 'g1',
  userId: userId,
  nickname: nickname,
  faceUrl: '',
  roleLevel: 1,
  joinSource: '',
);

void main() {
  group('MarkdownEditor', () {
    test('包裹选中文本为粗体', () {
      final controller = TextEditingController(text: 'hello world')
        ..selection = const TextSelection(baseOffset: 0, extentOffset: 5);
      const MarkdownEditor().handleFormat(controller, MarkdownFormat.bold);
      expect(controller.text, '**hello** world');
    });

    test('插入标题占位符并把光标放到占位符上', () {
      final controller = TextEditingController(text: 'abc')
        ..selection = const TextSelection.collapsed(offset: 0);
      const MarkdownEditor().handleFormat(controller, MarkdownFormat.heading);
      expect(controller.text, '## 标题abc');
      expect(controller.selection.baseOffset, 3);
    });
  });

  group('AtMemberQuery', () {
    test('光标位于 @ 后时解析关键字', () {
      const query = AtMemberQuery();
      final keyword = query.resolve(
        'hi @张',
        const TextSelection.collapsed(offset: 5),
        isGroupChat: true,
        atMembers: [_member('u1', '张三')],
      );
      expect(keyword, '张');
    });

    test('非群聊不激活 @ 查询', () {
      const query = AtMemberQuery();
      final keyword = query.resolve(
        'hi @张',
        const TextSelection.collapsed(offset: 5),
        isGroupChat: false,
        atMembers: [_member('u1', '张三')],
      );
      expect(keyword, isNull);
    });

    test('按昵称和 ID 过滤成员', () {
      const query = AtMemberQuery();
      final members = [
        _member('u1', '张三'),
        _member('u2', '李四'),
        _member('zhang3', '王五'),
      ];
      expect(query.filter('张', members).map((m) => m.userId), ['u1']);
      expect(query.filter('zhang', members).map((m) => m.userId), ['zhang3']);
      expect(query.filter('', members), hasLength(3));
    });

    test('空关键字返回全部成员', () {
      const query = AtMemberQuery();
      final members = [_member('u1', '张三')];
      expect(query.filter('', members), hasLength(1));
    });

    test('选择索引循环归一化', () {
      const query = AtMemberQuery();
      expect(query.normalizedIndex(3, 3), 0);
      expect(query.normalizedIndex(-1, 3), 2);
      expect(query.normalizedIndex(2, 0), 0);
    });
  });
}
