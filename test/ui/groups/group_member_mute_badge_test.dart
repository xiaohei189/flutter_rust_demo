import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_rust_demo/domain/models/group_member.dart';
import 'package:flutter_rust_demo/ui/core/theme/app_theme.dart';
import 'package:flutter_rust_demo/ui/groups/widgets/group_member_section.dart';

GroupMember _member({
  required String userId,
  required String nickname,
  DateTime? muteEndTime,
  int roleLevel = 1,
}) => GroupMember(
  groupId: 'g1',
  userId: userId,
  nickname: nickname,
  faceUrl: '',
  roleLevel: roleLevel,
  joinSource: '',
  muteEndTime: muteEndTime,
);

Widget _host(List<GroupMember> members) => MaterialApp(
  theme: AppTheme.lightTheme,
  home: Scaffold(
    body: GroupMemberSection(
      members: members,
      keyword: '',
      isLoading: false,
      ownerAdminCount: 0,
      joinTimeFilterLabel: '全部',
      onKeywordChanged: (_) {},
      onMemberTap: (_) {},
      onOwnerAdminTap: () {},
      onJoinTimeFilterTap: () {},
    ),
  ),
);

void main() {
  group('群成员禁言状态', () {
    testWidgets('被禁言的成员显示徽标与剩余时长，未禁言/已到期的不显示', (tester) async {
      final now = DateTime.now();
      await tester.pumpWidget(
        _host([
          _member(
            userId: 'u_muted',
            nickname: '张三',
            // 多给 30 秒，避免「构建耗时」让剩余时长从 12 分钟掉到 11 分钟
            muteEndTime: now.add(const Duration(minutes: 12, seconds: 30)),
          ),
          _member(userId: 'u_normal', nickname: '李四'),
          _member(
            userId: 'u_expired',
            nickname: '王五',
            muteEndTime: now.subtract(const Duration(minutes: 1)),
          ),
        ]),
      );

      expect(
        find.text('禁言中 · 剩 12 分钟'),
        findsOneWidget,
        reason: '禁言未到期的成员应显示剩余时长',
      );
      expect(
        find.textContaining('禁言中'),
        findsOneWidget,
        reason: '未禁言与已解除禁言的成员不应出现徽标',
      );
    });

    test('剩余时长按分钟/小时/天分档展示', () {
      expect(
        MuteBadge.formatRemaining(const Duration(seconds: 30)),
        '不到 1 分钟',
      );
      expect(MuteBadge.formatRemaining(const Duration(minutes: 45)), '45 分钟');
      expect(MuteBadge.formatRemaining(const Duration(hours: 5)), '5 小时');
      expect(MuteBadge.formatRemaining(const Duration(days: 3)), '3 天');
    });
  });
}
