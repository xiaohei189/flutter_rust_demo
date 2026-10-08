import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_rust_demo/ui/contacts/utils/contact_index.dart';

/// 通讯录索引纯逻辑：分组首字母、分组排序、内嵌搜索匹配。
void main() {
  group('ContactIndex.initialOf', () {
    test('中文取拼音首字母', () {
      expect(ContactIndex.initialOf('张伟'), 'Z');
      expect(ContactIndex.initialOf('李娜'), 'L');
      expect(ContactIndex.initialOf('欧阳锋'), 'O');
      expect(ContactIndex.initialOf('同学聚会'), 'T');
    });

    test('英文取首字母并转大写', () {
      expect(ContactIndex.initialOf('xiaoming'), 'X');
      expect(ContactIndex.initialOf('Alice'), 'A');
    });

    test('数字/符号/emoji/空名归到 #', () {
      expect(ContactIndex.initialOf('123'), ContactIndex.otherBucket);
      expect(ContactIndex.initialOf('  '), ContactIndex.otherBucket);
      expect(ContactIndex.initialOf('😀哈哈'), ContactIndex.otherBucket);
    });
  });

  group('ContactIndex.group', () {
    test('A→Z 升序，非字母分组排最后', () {
      final grouped = ContactIndex.group(
        ['赵敏', '李娜', 'Alice', '123', '张伟', '苏晴'],
        (name) => name,
      );

      expect(grouped.keys.toList(), ['A', 'L', 'S', 'Z', ContactIndex.otherBucket]);
      expect(grouped['Z'], ['赵敏', '张伟']);
      expect(grouped[ContactIndex.otherBucket], ['123']);
    });

    test('同一首字母内部保持输入顺序（列表本身已按名称排序）', () {
      final grouped = ContactIndex.group(['张伟', '赵敏', '周杰'], (name) => name);
      expect(grouped['Z'], ['张伟', '赵敏', '周杰']);
    });
  });

  group('ContactIndex.matches', () {
    test('空关键词不过滤', () {
      expect(ContactIndex.matches(query: '', displayName: '张伟'), isTrue);
      expect(ContactIndex.matches(query: '   ', displayName: '张伟'), isTrue);
    });

    test('姓名/昵称/ID 命中（大小写不敏感）', () {
      expect(
        ContactIndex.matches(query: '张', displayName: '张伟'),
        isTrue,
      );
      expect(
        ContactIndex.matches(
          query: 'nick',
          displayName: '备注名',
          nickname: 'NickName',
        ),
        isTrue,
      );
      expect(
        ContactIndex.matches(
          query: '2772835353',
          displayName: '张伟',
          userId: '2772835353',
        ),
        isTrue,
      );
    });

    test('拼音首字母与全拼命中', () {
      expect(ContactIndex.matches(query: 'zw', displayName: '张伟'), isTrue);
      expect(ContactIndex.matches(query: 'zhang', displayName: '张伟'), isTrue);
      expect(ContactIndex.matches(query: 'wei', displayName: '张伟'), isTrue);
      expect(ContactIndex.matches(query: 'li', displayName: '张伟'), isFalse);
    });
  });
}
