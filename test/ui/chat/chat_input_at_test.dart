import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_rust_demo/domain/models/group_member.dart';
import 'package:flutter_rust_demo/ui/chat/widgets/chat_input.dart';

void main() {
  GroupMember makeMember(String id, String name) => GroupMember(
        groupId: 'g1',
        userId: id,
        nickname: name,
        faceUrl: '',
        roleLevel: 1,
        joinSource: '',
      );

  testWidgets('输入 @ 后显示群成员列表，选择后插入 @昵称', (tester) async {
    final controller = TextEditingController();
    var selectedUserId = '';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatInput(
            controller: controller,
            onSend: (_, _) {},
            atMembers: [makeMember('u1', '张三'), makeMember('u2', '李四')],
            isGroupChat: true,
            onAtMemberSelected: (id) => selectedUserId = id,
          ),
        ),
      ),
    );

    // 聚焦输入框后输入 "@张" 触发成员列表
    await tester.tap(find.byType(TextField));
    await tester.pump();

    controller.text = '@张';
    controller.selection = const TextSelection.collapsed(offset: 2);
    controller.notifyListeners();
    await tester.pump();

    // 成员列表应只显示匹配"张"的成员
    expect(find.text('张三'), findsOneWidget);
    expect(find.text('李四'), findsNothing, reason: '关键字过滤应排除不匹配成员');

    // 选择成员
    await tester.tap(find.text('张三'));
    await tester.pump();

    expect(controller.text, '@张三 ', reason: '应替换 @关键字 为 @昵称');
    expect(selectedUserId, 'u1', reason: '应回调外部记录 atUserId');
  });

  testWidgets('非群聊或成员为空时输入 @ 不显示成员列表', (tester) async {
    final controller = TextEditingController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatInput(
            controller: controller,
            onSend: (_, _) {},
            isGroupChat: false,
          ),
        ),
      ),
    );

    controller.text = '@';
    controller.selection = const TextSelection.collapsed(offset: 1);
    controller.notifyListeners();
    await tester.pump();

    expect(find.byType(ListTile), findsNothing, reason: '单聊不应显示成员列表');
  });

  testWidgets('未匹配成员时显示无匹配提示', (tester) async {
    final controller = TextEditingController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatInput(
            controller: controller,
            onSend: (_, _) {},
            atMembers: [makeMember('u1', '张三')],
            isGroupChat: true,
          ),
        ),
      ),
    );

    await tester.tap(find.byType(TextField));
    await tester.pump();

    controller.text = '@不存在的名字';
    controller.selection =
        const TextSelection.collapsed(offset: 6); // '@不存在的名字'.length
    controller.notifyListeners();
    await tester.pump();

    expect(find.text('无匹配成员'), findsOneWidget);
  });
}
