import 'package:flutter/material.dart';

import '../../../domain/models/group_member.dart';
import '../../../domain/models/user.dart';
import '../../previews/app_theme_preview.dart';
import '../../previews/fake_data.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/user_avatar.dart';
import '../../core/widgets/list_row.dart';
import '../../core/widgets/card_layout.dart';
import '../../../l10n/app_localizations.dart';

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
    final l10n = AppLocalizations.of(context);
    // 成员行的禁言状态按「当前时间」判定：到期后徽标自动消失。
    final now = DateTime.now();
    return CardLayout(
      children: [
        ListRow(
          label: l10n?.groupMembers ?? '群成员',
          trailing: Text(
            isLoading ? '加载中...' : '${members.length}人',
            style: TextStyle(
              fontSize: 14,
              color: context.appColors.textSecondary,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: TextField(
            onChanged: onKeywordChanged,
            decoration: InputDecoration(
              hintText: l10n?.searchMembers ?? '搜索群成员',
              prefixIcon: const Icon(Icons.search, size: 20),
              isDense: true,
              filled: true,
              fillColor: context.appColors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        if (isLoading)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (members.isEmpty)
          Padding(
            padding: const EdgeInsets.all(20),
            child: Center(child: Text(l10n?.noMatchingMembers ?? '没有匹配的成员')),
          )
        else
          ...members.map(
            (m) => ListTile(
              key: ValueKey('group_member_${m.userId}'),
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              leading: UserAvatar.fromUser(
                user: User(
                  id: m.userId,
                  name: m.nickname,
                  avatar: m.faceUrl.isNotEmpty ? m.faceUrl : null,
                ),
                radius: 18,
              ),
              title: Row(
                children: [
                  Flexible(
                    child: Text(
                      m.nickname.isNotEmpty ? m.nickname : m.userId,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (m.isMutedAt(now)) ...[
                    const SizedBox(width: 6),
                    MuteBadge(remaining: m.muteRemainingAt(now)!),
                  ],
                ],
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
        ListRow(
          label: l10n?.ownerAdmin ?? '群主和管理员',
          trailing: Text(
            '$ownerAdminCount人',
            style: TextStyle(
              fontSize: 14,
              color: context.appColors.textSecondary,
            ),
          ),
          onTap: onOwnerAdminTap,
        ),
        ListRow(
          label: l10n?.joinTimeFilter ?? '按加入时间筛选',
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

// ==================== 预览 ====================

/// 禁言中徽标，例如 `禁言中 · 剩 12 分钟`。
///
/// 单独成组件便于在群成员行与后续的成员详情处复用，也方便组件测试直接断言。
class MuteBadge extends StatelessWidget {
  const MuteBadge({super.key, required this.remaining});

  /// 距离解除禁言的剩余时长（应大于 0）。
  final Duration remaining;

  static String formatRemaining(Duration remaining) {
    if (remaining.inMinutes < 1) return '不到 1 分钟';
    if (remaining.inHours < 1) return '${remaining.inMinutes} 分钟';
    if (remaining.inDays < 1) return '${remaining.inHours} 小时';
    return '${remaining.inDays} 天';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: colors.warning.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Text(
        '禁言中 · 剩 ${formatRemaining(remaining)}',
        style: TextStyle(fontSize: 11, color: colors.warning),
      ),
    );
  }
}

@AppThemePreview(name: '群成员分区', group: 'GroupMemberSection')
Widget groupMemberSectionPreview() {
  return Padding(
    padding: const EdgeInsets.all(16),
    child: GroupMemberSection(
      members: fakeGroupMemberList(),
      keyword: '',
      isLoading: false,
      ownerAdminCount: 2,
      joinTimeFilterLabel: '全部',
      onKeywordChanged: (_) {},
      onMemberTap: (_) {},
      onOwnerAdminTap: () {},
      onJoinTimeFilterTap: () {},
    ),
  );
}
