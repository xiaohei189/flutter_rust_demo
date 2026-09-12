import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/group_member.dart';
import '../../../domain/models/user.dart';
import '../../../router/app_router.dart';
import '../../../providers/current_user_provider.dart';
import '../../chat/widgets/settings_dialogs.dart' show showInviteMemberSheet;
import '../../core/theme/app_theme.dart';
import '../../core/widgets/user_avatar.dart';
import '../providers/group_provider.dart';

/// 群成员页（对齐飞书）：顶部搜索 + 成员列表 + 右上角「添加」。
///
/// 成员行展示头像、昵称与身份标签（群主/管理员）。点击进入该成员资料页。
class GroupMembersScreen extends ConsumerStatefulWidget {
  const GroupMembersScreen({super.key, required this.groupId});

  final String groupId;

  @override
  ConsumerState<GroupMembersScreen> createState() => _GroupMembersScreenState();
}

class _GroupMembersScreenState extends ConsumerState<GroupMembersScreen> {
  String _keyword = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = groupMemberProvider(widget.groupId);
      if (ref.read(provider).members.isEmpty) {
        unawaited(ref.read(provider.notifier).loadMembers());
      }
    });
  }

  List<GroupMember> _filtered(List<GroupMember> members) {
    final keyword = _keyword.trim().toLowerCase();
    if (keyword.isEmpty) return members;
    return members
        .where(
          (m) => (m.nickname.isNotEmpty ? m.nickname : m.userId)
              .toLowerCase()
              .contains(keyword),
        )
        .toList();
  }

  Future<void> _addMembers() async {
    await showInviteMemberSheet(
      context,
      onInvite: (ids) async {
        await ref
            .read(groupMemberProvider(widget.groupId).notifier)
            .inviteMembers(ids);
      },
    );
  }

  void _openMember(GroupMember member) {
    AppRouter.goToUserProfile(
      context,
      userId: member.userId,
      user: User(
        id: member.userId,
        name: member.nickname.isNotEmpty ? member.nickname : member.userId,
        avatar: member.faceUrl.isNotEmpty ? member.faceUrl : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final state = ref.watch(groupMemberProvider(widget.groupId));
    final members = _filtered(state.members);
    final currentUserId = ref.watch(currentUserIdProvider);

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        centerTitle: true,
        title: const Text('群成员'),
        actions: [
          TextButton(
            onPressed: _addMembers,
            child: Text(
              '添加',
              style: TextStyle(fontSize: 16, color: colors.textPrimary),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              onChanged: (value) => setState(() => _keyword = value),
              decoration: InputDecoration(
                hintText: '搜索群成员',
                hintStyle: TextStyle(
                  fontSize: 15,
                  color: colors.textSecondary,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  size: 20,
                  color: colors.textSecondary,
                ),
                isDense: true,
                filled: true,
                fillColor: colors.background,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: state.isLoading && state.members.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: members.length,
                    itemBuilder: (_, index) {
                      final member = members[index];
                      return _MemberRow(
                        member: member,
                        isSelf: member.userId == currentUserId,
                        onTap: () => _openMember(member),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.member,
    required this.isSelf,
    required this.onTap,
  });

  final GroupMember member;
  final bool isSelf;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final name = member.nickname.isNotEmpty ? member.nickname : member.userId;
    final roleTag = switch (member.roleLevel) {
      3 => '群主',
      2 => '管理员',
      _ => null,
    };

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            UserAvatar(
              user: User(
                id: member.userId,
                name: name,
                avatar: member.faceUrl.isNotEmpty ? member.faceUrl : null,
              ),
              radius: 22,
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 16, color: colors.textPrimary),
              ),
            ),
            // 「外部」标签：协议层暂无"外部联系人"字段，先按 UI 稿展示
            // （自己不算外部）；等 SDK 提供字段后替换为真实判断。
            if (!isSelf) ...[
              const SizedBox(width: 6),
              const _RoleTag(text: '外部'),
            ],
            if (roleTag != null) ...[
              const SizedBox(width: 6),
              _RoleTag(text: roleTag),
            ],
          ],
        ),
      ),
    );
  }
}

/// 身份标签（群主/管理员），对齐飞书稿的浅蓝圆角小标签。
class _RoleTag extends StatelessWidget {
  const _RoleTag({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, color: colors.primary),
      ),
    );
  }
}
