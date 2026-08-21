import 'package:flutter/material.dart';

import '../../../domain/models/group_member.dart';
import '../../../domain/models/user.dart';
import '../../../ui/core/theme/app_theme.dart';
import '../../../ui/core/widgets/user_avatar.dart';

/// 成员操作底部弹窗，返回动作标识：kick/mute/unmute/setAdmin/unsetAdmin/transfer。
Future<String?> showGroupMemberActionsSheet(
  BuildContext context,
  GroupMember member, {
  required bool isOwner,
}) {
  return showModalBottomSheet<String>(
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
}

/// 群管理底部弹窗，返回动作标识：muteAll/unmuteAll/transfer/dismiss。
Future<String?> showGroupManageSheet(BuildContext context) {
  return showModalBottomSheet<String>(
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
}

/// 群主和管理员列表弹窗。
Future<void> showGroupOwnerAdminSheet(
  BuildContext context,
  List<GroupMember> members, {
  required String Function(int roleLevel) roleName,
}) {
  return showModalBottomSheet<void>(
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
              subtitle: Text(roleName(m.roleLevel)),
              onTap: () => Navigator.of(sheetContext).pop(),
            ),
          ),
        ],
      ),
    ),
  );
}

/// 禁言时长选择弹窗。
Future<int?> showGroupMuteDurationSheet(BuildContext context) {
  const durations = <String, int>{
    '1 分钟': 60,
    '10 分钟': 600,
    '1 小时': 3600,
    '24 小时': 86400,
  };
  return showModalBottomSheet<int>(
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
}

/// 选择新群主弹窗。
Future<GroupMember?> showGroupOwnerPickerSheet(
  BuildContext context,
  List<GroupMember> candidates,
) {
  return showModalBottomSheet<GroupMember>(
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
            child: Text('选择新群主', style: TextStyle(fontWeight: FontWeight.w600)),
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
}

/// 确认踢出成员。
Future<bool> confirmKickMember(BuildContext context, GroupMember member) {
  return showDialog<bool>(
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
          child: Text('踢出', style: TextStyle(color: context.appColors.danger)),
        ),
      ],
    ),
  ).then((value) => value ?? false);
}

/// 确认解散群组。
Future<bool> confirmDismissGroup(BuildContext context) {
  return showDialog<bool>(
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
          child: Text('解散', style: TextStyle(color: context.appColors.danger)),
        ),
      ],
    ),
  ).then((value) => value ?? false);
}

/// 更换群头像（输入图片 URL）。
Future<String?> showChangeGroupAvatarDialog(
  BuildContext context, {
  required String initialUrl,
}) {
  final controller = TextEditingController(text: initialUrl);
  return showDialog<String>(
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
}

/// 编辑群名称/描述弹窗，保存后关闭。
Future<void> showEditGroupFieldDialog(
  BuildContext context, {
  required String title,
  required String initialValue,
  required Future<void> Function(String) onSave,
  int maxLines = 1,
}) {
  final controller = TextEditingController(text: initialValue);
  return showDialog(
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
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () async {
            final text = controller.text.trim();
            if (text.isNotEmpty) {
              await onSave(text);
            }
            if (ctx.mounted) {
              Navigator.of(ctx).pop();
            }
          },
          child: const Text('保存'),
        ),
      ],
    ),
  );
}
