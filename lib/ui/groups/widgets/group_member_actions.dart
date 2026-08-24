import 'package:flutter/material.dart';

import '../../../domain/models/group_member.dart';
import '../../../router/app_router.dart';
import '../view_models/group_info_view_model.dart';
import 'group_dialogs.dart' as dialogs;

/// 群成员管理操作：踢人、禁言/取消禁言、设/取消管理员、转让群主、全员禁言、解散群。
/// 与 [ChatMediaActions] 一样由页面持有，方法按需接收 [BuildContext]。
class GroupMemberActions {
  GroupMemberActions({required this.viewModel, required this.roleName});

  final GroupInfoViewModel viewModel;
  final String Function(int roleLevel) roleName;

  void showMemberActions(BuildContext context, GroupMember member) async {
    final currentUserId = viewModel.currentUserId;
    final canManage = viewModel.canManage;
    final isOwner = viewModel.isOwner;

    if (!canManage || member.userId == currentUserId) {
      return;
    }

    final action = await dialogs.showGroupMemberActionsSheet(
      context,
      member,
      isOwner: isOwner,
    );
    if (!context.mounted) return;

    switch (action) {
      case 'kick':
        await kickMember(context, member);
      case 'mute':
        await muteMemberDialog(context, member);
      case 'unmute':
        await unmuteMember(context, member);
      case 'setAdmin':
        await setAdmin(context, member, true);
      case 'unsetAdmin':
        await setAdmin(context, member, false);
      case 'transfer':
        await transferOwner(context, target: member);
    }
  }

  Future<void> setAdmin(
    BuildContext context,
    GroupMember member,
    bool isAdmin,
  ) async {
    final ok = await viewModel.setAdmin(member.userId, isAdmin);
    if (!context.mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isAdmin ? '已设为管理员' : '已取消管理员'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(viewModel.currentState.error ?? '设置管理员失败'),
        ),
      );
    }
  }

  void showOwnerAdminList(BuildContext context) {
    final members = viewModel.members.where((m) => m.roleLevel >= 2).toList();
    if (members.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('暂无群主和管理员'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    dialogs.showGroupOwnerAdminSheet(context, members, roleName: roleName);
  }

  Future<void> kickMember(BuildContext context, GroupMember member) async {
    final confirmed = await dialogs.confirmKickMember(context, member);
    if (confirmed != true) return;
    final ok = await viewModel.kickMember(member.userId);
    if (!context.mounted) return;
    if (ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('已踢出'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      _showError(context, viewModel.currentState.error ?? '踢出成员失败');
    }
  }

  Future<void> muteMemberDialog(BuildContext context, GroupMember member) async {
    final duration = await dialogs.showGroupMuteDurationSheet(context);
    if (duration == null) return;
    final ok = await viewModel.muteMember(member.userId, duration);
    if (!context.mounted) return;
    if (ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('已禁言'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      _showError(context, viewModel.currentState.error ?? '禁言失败');
    }
  }

  Future<void> unmuteMember(BuildContext context, GroupMember member) async {
    final ok = await viewModel.unmuteMember(member.userId);
    if (!context.mounted) return;
    if (ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('已取消禁言'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      _showError(context, viewModel.currentState.error ?? '取消禁言失败');
    }
  }

  Future<void> showGroupManageSheet(BuildContext context) async {
    final action = await dialogs.showGroupManageSheet(context);
    if (!context.mounted) return;

    switch (action) {
      case 'muteAll':
        await setMuteAll(context, true);
      case 'unmuteAll':
        await setMuteAll(context, false);
      case 'transfer':
        await transferOwner(context);
      case 'dismiss':
        await dismissGroup(context);
    }
  }

  Future<void> setMuteAll(BuildContext context, bool isMute) async {
    final ok = await viewModel.muteAll(isMute);
    if (!context.mounted) return;
    if (ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isMute ? '已全员禁言' : '已解除全员禁言'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      _showError(context, viewModel.currentState.error ?? '全员禁言操作失败');
    }
  }

  Future<void> transferOwner(
    BuildContext context, {
    GroupMember? target,
  }) async {
    final members = viewModel.members;
    final currentUserId = viewModel.currentUserId;
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
    selected ??= await dialogs.showGroupOwnerPickerSheet(context, candidates);
    if (selected == null) return;

    final ok = await viewModel.transferOwner(selected.userId);
    if (!context.mounted) return;
    if (ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('群主已转让'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      _showError(context, viewModel.currentState.error ?? '转让群主失败');
    }
  }

  Future<void> dismissGroup(BuildContext context) async {
    final confirmed = await dialogs.confirmDismissGroup(context);
    if (confirmed != true) return;
    final ok = await viewModel.dismissGroup();
    if (!context.mounted) return;
    if (ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('群组已解散'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      AppRouter.goBack(context);
    } else {
      _showError(context, viewModel.currentState.error ?? '解散群组失败');
    }
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }
}
