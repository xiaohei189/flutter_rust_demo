import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_rust_demo/domain/models/group_member.dart';
import 'package:flutter_rust_demo/domain/models/mention.dart';
import 'package:flutter_rust_demo/ui/chat/widgets/composer/group_member_picker.dart';

void main() {
  GroupMember makeMember(String id, String name) => GroupMember(
    groupId: 'g1',
    userId: id,
    nickname: name,
    faceUrl: '',
    roleLevel: 1,
    joinSource: '',
  );

  testWidgets('@ 选择器置顶「所有人」，返回 SDK AtAllTag', (tester) async {
    GroupMember? picked;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                picked = await showGroupMemberPicker(context, [
                  makeMember('u1', '张三'),
                ]);
              },
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    expect(find.text(kAtAllDisplayName), findsOneWidget);
    // 头像首字与昵称各有一个 Text，这里只确认成员行存在。
    expect(find.text('张三'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('at_all_option')));
    await tester.pumpAndSettle();

    expect(picked?.userId, kAtAllTag, reason: '发送侧需要 AtAllTag 才能让服务端识别 @所有人');
    expect(picked?.nickname, kAtAllDisplayName);
  });

  test('insertAtMention 插入 @所有人 文本并补空格', () {
    final controller = TextEditingController(text: '通知');
    addTearDown(controller.dispose);

    insertAtMention(controller, kAtAllDisplayName, kAtAllTag);

    expect(controller.text, '通知 @所有人 ');
    expect(controller.selection.baseOffset, controller.text.length);
  });
}
