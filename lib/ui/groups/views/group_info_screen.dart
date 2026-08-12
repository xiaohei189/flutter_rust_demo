import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/models/conversation.dart';
import '../../../../domain/models/group_member.dart';
import '../../../../domain/models/user.dart';
import '../../profile/providers/user_profile_provider.dart';
import '../../../../router/app_router.dart';
import '../../../../data/services/services.dart';
import '../../../../ui/core/theme/app_theme.dart';
import '../../../../ui/core/widgets/card_layout.dart';
import '../../../../ui/core/widgets/list_row.dart';
import '../../../../ui/core/widgets/user_avatar.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/group_info_provider.dart';
import '../providers/group_provider.dart';
import '../view_models/group_info_view_model.dart';
import '../widgets/group_member_section.dart';

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

  @override
  Widget build(BuildContext context) {
    final conversation = _conversation;
    final groupInfo = ref.watch(
      groupInfoViewModelProvider(widget.conversationId),
    );

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

    final currentUserId = ref.watch(userProfileProvider).profile?.userId ?? '';
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
                label: '群头像',
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
                label: '群名称',
                value: groupInfo.groupName,
                onTap: () => _editField(
                  title: '修改群名称',
                  initialValue: groupInfo.groupName,
                  onSave: _saveGroupName,
                ),
              ),
              const ListDivider(),
              TwoLineListRow(
                label: '群描述',
                value: groupInfo.groupDescription,
                onTap: () => _editField(
                  title: '修改群描述',
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
          if (isOwner) ...[
            const SizedBox(height: 12),
            CardLayout(
              children: [
                ListRow(
                  label: '全员禁言',
                  trailing: Icon(
                    Icons.volume_off_outlined,
                    size: 20,
                    color: context.appColors.textSecondary,
                  ),
                  onTap: () => _showGroupManageSheet(),
                ),
                const ListDivider(),
                ListRow(
                  label: '转让群主',
                  trailing: Icon(
                    Icons.swap_horiz,
                    size: 20,
                    color: context.appColors.textSecondary,
                  ),
                  onTap: _transferOwner,
                ),
                const ListDivider(),
                DangerActionRow(title: '解散群组', onTap: _dismissGroup),
              ],
            ),
          ],
          const SizedBox(height: 12),
          // 群二维码（只读）
          CardLayout(
            children: [
              ListRow(
                label: '群二维码',
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

    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: context.appColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                member.nickname.isNotEmpty ? member.nickname : member.userId,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.person_remove_outlined),
              title: const Text('踢出群聊'),
              onTap: () => Navigator.of(ctx).pop('kick'),
            ),
            ListTile(
              leading: const Icon(Icons.volume_off_outlined),
              title: const Text('禁言'),
              onTap: () => Navigator.of(ctx).pop('mute'),
            ),
            ListTile(
              leading: const Icon(Icons.volume_up_outlined),
              title: const Text('取消禁言'),
              onTap: () => Navigator.of(ctx).pop('unmute'),
            ),
            if (isOwner && member.roleLevel != 3)
              ListTile(
                leading: const Icon(Icons.admin_panel_settings_outlined),
                title: Text(member.roleLevel == 2 ? '取消管理员' : '设为管理员'),
                onTap: () => Navigator.of(
                  ctx,
                ).pop(member.roleLevel == 2 ? 'unsetAdmin' : 'setAdmin'),
              ),
            if (isOwner)
              ListTile(
                leading: const Icon(Icons.swap_horiz),
                title: const Text('转让群主'),
                onTap: () => Navigator.of(ctx).pop('transfer'),
              ),
          ],
        ),
      ),
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
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.appColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                '群主和管理员',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const Divider(height: 1),
            ...members.map(
              (m) => ListTile(
                leading: UserAvatar(
                  user: User(
                    id: m.userId,
                    name: m.nickname,
                    avatar: m.faceUrl.isNotEmpty ? m.faceUrl : null,
                  ),
                  radius: 18,
                ),
                title: Text(m.nickname.isNotEmpty ? m.nickname : m.userId),
                subtitle: Text(_roleName(m.roleLevel)),
                onTap: () => Navigator.of(sheetContext).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _joinTimeFilterLabel => switch (_joinTimeFilter) {
    _JoinTimeFilter.all => '全部',
    _JoinTimeFilter.today => '今天',
    _JoinTimeFilter.week => '近 7 天',
    _JoinTimeFilter.month => '近 30 天',
  };

  Future<void> _showJoinTimeFilter() async {
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
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                '按加入时间筛选',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const Divider(height: 1),
            for (final filter in _JoinTimeFilter.values)
              ListTile(
                title: Text(switch (filter) {
                  _JoinTimeFilter.all => '全部',
                  _JoinTimeFilter.today => '今天',
                  _JoinTimeFilter.week => '近 7 天',
                  _JoinTimeFilter.month => '近 30 天',
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('踢出群聊'),
        content: Text(
          '确定将 ${member.nickname.isNotEmpty ? member.nickname : member.userId} 移出群聊吗？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              '踢出',
              style: TextStyle(color: context.appColors.danger),
            ),
          ),
        ],
      ),
    );
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
    const durations = <String, int>{
      '1 分钟': 60,
      '10 分钟': 600,
      '1 小时': 3600,
      '24 小时': 86400,
    };
    final duration = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: context.appColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                '选择禁言时长',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            ...durations.entries.map(
              (e) => ListTile(
                title: Text(e.key),
                onTap: () => Navigator.of(ctx).pop(e.value),
              ),
            ),
          ],
        ),
      ),
    );
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
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: context.appColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('群管理', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.volume_off_outlined),
              title: const Text('全员禁言'),
              onTap: () => Navigator.of(ctx).pop('muteAll'),
            ),
            ListTile(
              leading: const Icon(Icons.volume_up_outlined),
              title: const Text('解除全员禁言'),
              onTap: () => Navigator.of(ctx).pop('unmuteAll'),
            ),
            ListTile(
              leading: const Icon(Icons.swap_horiz),
              title: const Text('转让群主'),
              onTap: () => Navigator.of(ctx).pop('transfer'),
            ),
            ListTile(
              leading: Icon(
                Icons.delete_outline,
                color: context.appColors.danger,
              ),
              title: Text(
                '解散群组',
                style: TextStyle(color: context.appColors.danger),
              ),
              onTap: () => Navigator.of(ctx).pop('dismiss'),
            ),
          ],
        ),
      ),
    );

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
    selected ??= await showModalBottomSheet<GroupMember>(
      context: context,
      backgroundColor: context.appColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                '选择新群主',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const Divider(height: 1),
            ...candidates.map(
              (m) => ListTile(
                title: Text(m.nickname.isNotEmpty ? m.nickname : m.userId),
                onTap: () => Navigator.of(ctx).pop(m),
              ),
            ),
          ],
        ),
      ),
    );
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('解散群组'),
        content: const Text('解散后所有成员都将退出，且无法恢复，确定继续吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              '解散',
              style: TextStyle(color: context.appColors.danger),
            ),
          ),
        ],
      ),
    );
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
    final controller = TextEditingController(
      text: _conversation?.faceUrl ?? '',
    );
    final url = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('更换群头像'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '请输入图片 URL',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
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
    final controller = TextEditingController(text: initialValue);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          maxLines: maxLines,
          autofocus: true,
          decoration: InputDecoration(
            hintText: '请输入$title',
            filled: true,
            fillColor: context.appColors.background,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => NavigationService.instance.goBack(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              final text = controller.text.trim();
              if (text.isNotEmpty) {
                await onSave(text);
              }
              if (context.mounted) {
                NavigationService.instance.goBack();
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
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
