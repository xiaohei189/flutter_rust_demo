import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/models/conversation.dart';
import '../../../../domain/models/group_member.dart';
import '../../../../domain/models/user.dart';
import '../../../../router/app_router.dart';
import '../../../../ui/core/theme/app_theme.dart';
import '../../../../ui/core/widgets/card_layout.dart';
import '../../../../ui/core/widgets/list_row.dart';
import '../../../../ui/core/widgets/user_avatar.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/group_info_provider.dart';
import '../providers/group_provider.dart';
import '../view_models/group_info_view_model.dart';
import '../widgets/group_member_section.dart';
import '../widgets/group_dialogs.dart';

enum _JoinTimeFilter { all, today, week, month }

/// 群信息页面：群头像（可编辑）、群名称（可编辑）、群描述（可编辑）、群二维码（只读）
class GroupInfoScreen extends ConsumerStatefulWidget {
  final String conversationId;

  const GroupInfoScreen({super.key, required this.conversationId});

  @override
  ConsumerState<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends ConsumerState<GroupInfoScreen> {
  late final GroupInfoViewModel _viewModel;
  String _memberKeyword = '';
  _JoinTimeFilter _joinTimeFilter = _JoinTimeFilter.all;

  Conversation? get _conversation => _viewModel.conversation;
  String get _groupId => _viewModel.groupId;
  User get _groupUser => _viewModel.groupUser;

  @override
  void initState() {
    super.initState();
    _viewModel = ref.read(
      groupInfoViewModelProvider(widget.conversationId).notifier,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_viewModel.load());
    });
  }

  Widget _buildOwnerManageCard(AppLocalizations? l10n) {
    return Column(
      children: [
        const SizedBox(height: 12),
        CardLayout(
          children: [
            ListRow(
              label: l10n?.muteAll ?? '全员禁言',
              trailing: Icon(
                Icons.volume_off_outlined,
                size: 20,
                color: context.appColors.textSecondary,
              ),
              onTap: () => _showGroupManageSheet(),
            ),
            const ListDivider(),
            ListRow(
              label: l10n?.transferOwner ?? '转让群主',
              trailing: Icon(
                Icons.swap_horiz,
                size: 20,
                color: context.appColors.textSecondary,
              ),
              onTap: _transferOwner,
            ),
            const ListDivider(),
            DangerActionRow(
              title: l10n?.dismissGroup ?? '解散群组',
              onTap: _dismissGroup,
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final conversation = _conversation;
    final groupInfo = ref.watch(
      groupInfoViewModelProvider(widget.conversationId),
    );
    final l10n = AppLocalizations.of(context);

    if (conversation == null) {
      return Scaffold(
        backgroundColor: context.appColors.background,
        appBar: AppBar(
          title: const Text('群信息'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            onPressed: () => AppRouter.goBack(context),
          ),
        ),
        body: const Center(child: Text('群组不存在')),
      );
    }

    final currentUserId = _viewModel.currentUserId;
    final memberState = ref.watch(groupMemberProvider(_groupId));
    final keyword = _memberKeyword.trim().toLowerCase();
    final now = DateTime.now();
    final joinCutoff = switch (_joinTimeFilter) {
      _JoinTimeFilter.all => null,
      _JoinTimeFilter.today => DateTime(now.year, now.month, now.day),
      _JoinTimeFilter.week => now.subtract(const Duration(days: 7)),
      _JoinTimeFilter.month => now.subtract(const Duration(days: 30)),
    };
    final visibleMembers = memberState.members.where((m) {
      final matchKeyword =
          keyword.isEmpty ||
          m.nickname.toLowerCase().contains(keyword) ||
          m.userId.toLowerCase().contains(keyword);
      final rawJoinTime = m.joinTimeMs;
      final joinTime = rawJoinTime > 946684800000
          ? rawJoinTime
          : rawJoinTime * 1000;
      final matchTime =
          joinCutoff == null || joinTime >= joinCutoff.millisecondsSinceEpoch;
      return matchKeyword && matchTime;
    }).toList();
    final currentMember = memberState.members
        .where((m) => m.userId == currentUserId)
        .firstOrNull;
    final isOwner = currentMember?.roleLevel == 3;

    return Scaffold(
      backgroundColor: context.appColors.background,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)?.groupInfoTitle ?? '群信息'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => AppRouter.goBack(context),
        ),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 12),
          // 群头像、群名称、群描述
          CardLayout(
            children: [
              ListRow(
                label: l10n?.groupAvatar ?? '群头像',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    UserAvatar(user: _groupUser, radius: 22),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 14,
                      color: context.appColors.textSecondary.withValues(
                        alpha: 0.5,
                      ),
                    ),
                  ],
                ),
                onTap: _changeGroupAvatar,
              ),
              const ListDivider(),
              TwoLineListRow(
                label: l10n?.groupName ?? '群名称',
                value: groupInfo.groupName,
                onTap: () => _editField(
                  title: l10n?.editGroupName ?? '修改群名称',
                  initialValue: groupInfo.groupName,
                  onSave: _saveGroupName,
                ),
              ),
              const ListDivider(),
              TwoLineListRow(
                label: l10n?.groupDescription ?? '群描述',
                value: groupInfo.groupDescription,
                onTap: () => _editField(
                  title: l10n?.editGroupDescription ?? '修改群描述',
                  initialValue: groupInfo.groupDescription == '暂无描述'
                      ? ''
                      : groupInfo.groupDescription,
                  onSave: _saveGroupDescription,
                ),
              ),
            ],
          ),
          // 群成员
          GroupMemberSection(
            members: visibleMembers,
            keyword: _memberKeyword,
            isLoading: memberState.isLoading,
            ownerAdminCount: memberState.members
                .where((m) => m.roleLevel >= 2)
                .length,
            joinTimeFilterLabel: _joinTimeFilterLabel,
            onKeywordChanged: (value) => setState(() => _memberKeyword = value),
            onMemberTap: _showMemberActions,
            onOwnerAdminTap: _showOwnerAdminList,
            onJoinTimeFilterTap: _showJoinTimeFilter,
          ),
          if (isOwner) _buildOwnerManageCard(l10n),
          const SizedBox(height: 12),
          // 群二维码（只读）
          CardLayout(
            children: [
              ListRow(
                label: l10n?.groupQrCode ?? '群二维码',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.qr_code_2,
                      size: 22,
                      color: context.appColors.textSecondary.withValues(
                        alpha: 0.7,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 14,
                      color: context.appColors.textSecondary.withValues(
                        alpha: 0.5,
                      ),
                    ),
                  ],
                ),
                onTap: () {
                  AppRouter.goToQrCode(
                    context,
                    title: '群二维码',
                    data: _groupId,
                    subtitle: groupInfo.groupName,
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  String _roleName(int roleLevel) {
    return switch (roleLevel) {
      3 => '群主',
      2 => '管理员',
      _ => '成员',
    };
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _showMemberActions(GroupMember member) async {
    final currentUserId = _viewModel.currentUserId;
    final canManage = _viewModel.canManage;
    final isOwner = _viewModel.isOwner;

    if (!canManage || member.userId == currentUserId) {
      return;
    }

    final action = await showGroupMemberActionsSheet(
      context,
      member,
      isOwner: isOwner,
    );

    switch (action) {
      case 'kick':
        await _kickMember(member);
      case 'mute':
        await _muteMemberDialog(member);
      case 'unmute':
        await _unmuteMember(member);
      case 'setAdmin':
        await _setAdmin(member, true);
      case 'unsetAdmin':
        await _setAdmin(member, false);
      case 'transfer':
        await _transferOwner(target: member);
    }
  }

  Future<void> _setAdmin(GroupMember member, bool isAdmin) async {
    final ok = await _viewModel.setAdmin(member.userId, isAdmin);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isAdmin ? '已设为管理员' : '已取消管理员'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_viewModel.currentState.error ?? '设置管理员失败')),
      );
    }
  }

  void _showOwnerAdminList() {
    final members = _viewModel.members.where((m) => m.roleLevel >= 2).toList();
    if (members.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('暂无群主和管理员'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    showGroupOwnerAdminSheet(context, members, roleName: _roleName);
  }

  String get _joinTimeFilterLabel => switch (_joinTimeFilter) {
    _JoinTimeFilter.all => '全部',
    _JoinTimeFilter.today => '今天',
    _JoinTimeFilter.week => '近 7 天',
    _JoinTimeFilter.month => '近 30 天',
  };

  Future<void> _showJoinTimeFilter() async {
    final l10n = AppLocalizations.of(context);
    final selected = await showModalBottomSheet<_JoinTimeFilter>(
      context: context,
      backgroundColor: context.appColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                l10n?.joinTimeFilter ?? '按加入时间筛选',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const Divider(height: 1),
            for (final filter in _JoinTimeFilter.values)
              ListTile(
                title: Text(switch (filter) {
                  _JoinTimeFilter.all => l10n?.all ?? '全部',
                  _JoinTimeFilter.today => l10n?.today ?? '今天',
                  _JoinTimeFilter.week => l10n?.last7Days ?? '近 7 天',
                  _JoinTimeFilter.month => l10n?.last30Days ?? '近 30 天',
                }),
                trailing: _joinTimeFilter == filter
                    ? Icon(
                        Icons.check,
                        size: 20,
                        color: context.appColors.primary,
                      )
                    : null,
                onTap: () => Navigator.of(sheetContext).pop(filter),
              ),
          ],
        ),
      ),
    );
    if (selected != null && mounted) {
      setState(() => _joinTimeFilter = selected);
    }
  }

  Future<void> _kickMember(GroupMember member) async {
    final confirmed = await confirmKickMember(context, member);
    if (confirmed != true) return;
    final ok = await _viewModel.kickMember(member.userId);
    if (!mounted) return;
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('已踢出'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      _showError(_viewModel.currentState.error ?? '踢出成员失败');
    }
  }

  Future<void> _muteMemberDialog(GroupMember member) async {
    final duration = await showGroupMuteDurationSheet(context);
    if (duration == null) return;
    final ok = await _viewModel.muteMember(member.userId, duration);
    if (!mounted) return;
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('已禁言'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      _showError(_viewModel.currentState.error ?? '禁言失败');
    }
  }

  Future<void> _unmuteMember(GroupMember member) async {
    final ok = await _viewModel.unmuteMember(member.userId);
    if (!mounted) return;
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('已取消禁言'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      _showError(_viewModel.currentState.error ?? '取消禁言失败');
    }
  }

  Future<void> _showGroupManageSheet() async {
    final action = await showGroupManageSheet(context);

    switch (action) {
      case 'muteAll':
        await _setMuteAll(true);
      case 'unmuteAll':
        await _setMuteAll(false);
      case 'transfer':
        await _transferOwner();
      case 'dismiss':
        await _dismissGroup();
    }
  }

  Future<void> _setMuteAll(bool isMute) async {
    final ok = await _viewModel.muteAll(isMute);
    if (!mounted) return;
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isMute ? '已全员禁言' : '已解除全员禁言'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      _showError(_viewModel.currentState.error ?? '全员禁言操作失败');
    }
  }

  Future<void> _transferOwner({GroupMember? target}) async {
    final members = _viewModel.members;
    final currentUserId = _viewModel.currentUserId;
    final candidates = members.where((m) => m.userId != currentUserId).toList();
    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('暂无可转让成员'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    GroupMember? selected = target;
    selected ??= await showGroupOwnerPickerSheet(context, candidates);
    if (selected == null) return;

    final ok = await _viewModel.transferOwner(selected.userId);
    if (!mounted) return;
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('群主已转让'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      _showError(_viewModel.currentState.error ?? '转让群主失败');
    }
  }

  Future<void> _dismissGroup() async {
    final confirmed = await confirmDismissGroup(context);
    if (confirmed != true) return;
    final ok = await _viewModel.dismissGroup();
    if (!mounted) return;
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('群组已解散'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      AppRouter.goBack(context);
    } else {
      _showError(_viewModel.currentState.error ?? '解散群组失败');
    }
  }

  /// 更换群头像（输入图片 URL）
  Future<void> _changeGroupAvatar() async {
    final url = await showChangeGroupAvatarDialog(
      context,
      initialUrl: _conversation?.faceUrl ?? '',
    );
    if (url == null || url.isEmpty) return;
    final ok = await _viewModel.updateGroupAvatar(url);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('群头像已更新'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      _showError(_viewModel.currentState.error ?? '更新失败');
    }
  }

  void _editField({
    required String title,
    required String initialValue,
    required Future<void> Function(String) onSave,
    int maxLines = 1,
  }) {
    showEditGroupFieldDialog(
      context,
      title: title,
      initialValue: initialValue,
      onSave: onSave,
      maxLines: maxLines,
    );
  }

  Future<void> _saveGroupName(String value) async {
    final ok = await _viewModel.updateGroupName(value);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('群名称已更新'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      _showError(_viewModel.currentState.error ?? '群名称更新失败');
    }
  }

  Future<void> _saveGroupDescription(String value) async {
    final ok = await _viewModel.updateGroupDescription(value);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('群描述已更新'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      _showError(_viewModel.currentState.error ?? '群描述更新失败');
    }
  }
}
