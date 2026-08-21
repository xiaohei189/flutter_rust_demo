import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_rust_demo/domain/models/group_member.dart';
import 'package:flutter_rust_demo/ui/groups/widgets/group_dialogs.dart';

GroupMember _member({int roleLevel = 2}) => GroupMember(
  groupId: 'g1',
  userId: 'u2',
  nickname: '李四',
  faceUrl: '',
  roleLevel: roleLevel,
  joinSource: '',
);

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('成员操作弹窗：群主可选转让，返回 transfer', (tester) async {
    String? action;
    await tester.pumpWidget(
      _host(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              action = await showGroupMemberActionsSheet(
                context,
                _member(),
                isOwner: true,
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('踢出群聊'), findsOneWidget);
    expect(find.text('取消管理员'), findsOneWidget);
    await tester.tap(find.text('转让群主'));
    await tester.pumpAndSettle();
    expect(action, 'transfer');
  });

  testWidgets('禁言时长弹窗返回秒数', (tester) async {
    int? duration;
    await tester.pumpWidget(
      _host(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              duration = await showGroupMuteDurationSheet(context);
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('选择禁言时长'), findsOneWidget);
    await tester.tap(find.text('1 小时'));
    await tester.pumpAndSettle();
    expect(duration, 3600);
  });

  testWidgets('踢出成员确认弹窗返回 true', (tester) async {
    bool? confirmed;
    await tester.pumpWidget(
      _host(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              confirmed = await confirmKickMember(context, _member());
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.textContaining('移出群聊'), findsOneWidget);
    await tester.tap(find.text('踢出'));
    await tester.pumpAndSettle();
    expect(confirmed, isTrue);
  });

  testWidgets('群管理弹窗返回解散动作', (tester) async {
    String? action;
    await tester.pumpWidget(
      _host(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              action = await showGroupManageSheet(context);
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('解散群组'));
    await tester.pumpAndSettle();
    expect(action, 'dismiss');
  });

  testWidgets('编辑字段弹窗回调保存后的文本', (tester) async {
    String? saved;
    await tester.pumpWidget(
      _host(
        Builder(
          builder: (context) => TextButton(
            onPressed: () {
              showEditGroupFieldDialog(
                context,
                title: '群名称',
                initialValue: '',
                onSave: (value) async => saved = value,
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '新群名');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(saved, '新群名');
  });
}
