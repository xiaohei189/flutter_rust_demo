import 'package:flutter/material.dart';

import '../../../domain/models/group_member.dart';
import '../../../domain/models/user.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/user_avatar.dart';
import '../../core/widgets/list_row.dart';
import '../../core/widgets/card_layout.dart';

/// 群成员分区：搜索、成员列表、群主/管理员、按时间筛选。
class GroupMemberSection extends StatelessWidget {
  const GroupMemberSection({
    super.key,
    required this.members,
    required this.keyword,
    required this.isLoading,
    required this.ownerAdminCount,
    required this.joinTimeFilterLabel,
    required this.onKeywordChanged,
    required this.onMemberTap,
    required this.onOwnerAdminTap,
    required this.onJoinTimeFilterTap,
  });

  final List<GroupMember> members;
  final String keyword;
  final bool isLoading;
  final int ownerAdminCount;
  final String joinTimeFilterLabel;
  final ValueChanged<String> onKeywordChanged;
  final ValueChanged<GroupMember> onMemberTap;
  final VoidCallback onOwnerAdminTap;
  final VoidCallback onJoinTimeFilterTap;

  String _roleName(int roleLevel) {
    return switch (roleLevel) {
      3 => '群主',
      2 => '管理员',
      _ => '成员',
    };
  }

  @override
  Widget build(BuildContext context) {
    return CardLayout(
      children: [
        ListRow(
          label: '群成员',
          trailing: Text(
            isLoading ? '加载中...' : '${members.length}人',
            style: TextStyle(
              fontSize: 14,
              color: context.appColors.textSecondary,
            ),
          ),
        ),
        const ListDivider(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: TextField(
            onChanged: onKeywordChanged,
            decoration: InputDecoration(
              hintText: '搜索群成员',
              prefixIcon: const Icon(Icons.search, size: 20),
              isDense: true,
              filled: true,
              fillColor: context.appColors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const ListDivider(),
        if (isLoading)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (members.isEmpty)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: Text('没有匹配的成员')),
          )
        else
          ...members.map(
            (m) => ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              leading: UserAvatar(
                user: User(
                  id: m.userId,
                  name: m.nickname,
                  avatar: m.faceUrl.isNotEmpty ? m.faceUrl : null,
                ),
                radius: 18,
              ),
              title: Text(
                m.nickname.isNotEmpty ? m.nickname : m.userId,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                _roleName(m.roleLevel),
                style: const TextStyle(fontSize: 12),
              ),
              trailing: Icon(
                Icons.chevron_right,
                size: 16,
                color: context.appColors.textSecondary,
              ),
              onTap: () => onMemberTap(m),
            ),
          ),
        const ListDivider(),
        ListRow(
          label: '群主和管理员',
          trailing: Text(
            '$ownerAdminCount人',
            style: TextStyle(
              fontSize: 14,
              color: context.appColors.textSecondary,
            ),
          ),
          onTap: onOwnerAdminTap,
        ),
        const ListDivider(),
        ListRow(
          label: '按加入时间筛选',
          trailing: Text(
            joinTimeFilterLabel,
            style: TextStyle(
              fontSize: 14,
              color: context.appColors.textSecondary,
            ),
          ),
          onTap: onJoinTimeFilterTap,
        ),
      ],
    );
  }
}
