import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/models/group_member.dart';
import '../../../../models/user.dart';
import '../../../../providers/providers.dart';
import '../../../../router/app_router.dart';
import '../../../../ui/features/profile/views/qr_code_screen.dart';
import '../../../../services/services.dart';
import '../../../../src/rust/model/local.dart' show LocalConversation;
import '../../../../theme/app_theme.dart';
import '../../../../widgets/card_layout.dart';
import '../../../../widgets/list_row.dart';
import '../../../../widgets/user_avatar.dart';

enum _JoinTimeFilter { all, today, week, month }

/// 群信息页面：群头像（可编辑）、群名称（可编辑）、群描述（可编辑）、群二维码（只读）
class GroupInfoScreen extends ConsumerStatefulWidget {
  final String conversationId;

  const GroupInfoScreen({super.key, required this.conversationId});

  @override
  ConsumerState<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends ConsumerState<GroupInfoScreen> {
  late String _groupName;
  late String _groupDescription;
  String _memberKeyword = '';
  _JoinTimeFilter _joinTimeFilter = _JoinTimeFilter.all;

  /// 获取会话信息
  LocalConversation? get _conversation {
    // 先尝试从新的 ConversationService 获取
    final newService = ref.read(conversationServiceProvider);
    var conversation = newService.getConversation(widget.conversationId);
    if (conversation != null) return conversation;

    // 如果新服务没有，尝试从旧的 conversationListProvider 获取
    final oldState = ref.read(conversationListProvider);
    conversation = oldState.conversations
        .where((c) => c.conversationId == widget.conversationId)
        .firstOrNull;
    return conversation;
  }

  String get _groupId {
    final conversation = _conversation;
    if (conversation == null) return widget.conversationId;
    return conversation.groupId.isNotEmpty
        ? conversation.groupId
        : conversation.conversationId;
  }

  User get _groupUser {
    final conversation = _conversation;
    if (conversation == null) {
      return User(id: widget.conversationId, name: '未知群组', avatar: null);
    }
    return User(
      id: _groupId,
      name: _groupName,
      avatar: conversation.faceUrl.isNotEmpty ? conversation.faceUrl : null,
    );
  }

  @override
  void initState() {
    super.initState();
    final conversation = _conversation;
    if (conversation != null) {
      _groupName = conversation.showName.isNotEmpty
          ? conversation.showName
          : '群聊';
    } else {
      _groupName = '群聊';
    }
    _groupDescription = '暂无描述';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(groupMemberProvider(_groupId).notifier).loadMembers();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final conversation = _conversation;

    if (conversation == null) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
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
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('群信息'),
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
                      color: AppTheme.textSecondaryColor.withValues(alpha: 0.5),
                    ),
                  ],
                ),
                onTap: _changeGroupAvatar,
              ),
              const ListDivider(),
              TwoLineListRow(
                label: '群名称',
                value: _groupName,
                onTap: () => _editField(
                  title: '修改群名称',
                  initialValue: _groupName,
                  onSave: _saveGroupName,
                ),
              ),
              const ListDivider(),
              TwoLineListRow(
                label: '群描述',
                value: _groupDescription,
                onTap: () => _editField(
                  title: '修改群描述',
                  initialValue: _groupDescription == '暂无描述'
                      ? ''
                      : _groupDescription,
                  onSave: _saveGroupDescription,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 群成员
          CardLayout(
            children: [
              ListRow(
                label: '群成员',
                trailing: Text(
                  memberState.isLoading
                      ? '加载中...'
                      : '${memberState.members.length}人',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondaryColor,
                  ),
                ),
              ),
              const ListDivider(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                child: TextField(
                  onChanged: (value) => setState(() => _memberKeyword = value),
                  decoration: InputDecoration(
                    hintText: '搜索群成员',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    filled: true,
                    fillColor: AppTheme.backgroundColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const ListDivider(),
              if (memberState.isLoading)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (visibleMembers.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: Text('没有匹配的成员')),
                )
              else
                ...visibleMembers.map(
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
                    trailing: const Icon(
                      Icons.chevron_right,
                      size: 16,
                      color: AppTheme.textSecondaryColor,
                    ),
                    onTap: () => _showMemberActions(m),
                  ),
                ),
              const ListDivider(),
              ListRow(
                label: '群主和管理员',
                trailing: Text(
                  '${memberState.members.where((m) => m.roleLevel >= 2).length}人',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondaryColor,
                  ),
                ),
                onTap: _showOwnerAdminList,
              ),
              const ListDivider(),
              ListRow(
                label: '按加入时间筛选',
                trailing: Text(
                  _joinTimeFilterLabel,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondaryColor,
                  ),
                ),
                onTap: _showJoinTimeFilter,
              ),
            ],
          ),
          if (isOwner) ...[
            const SizedBox(height: 12),
            CardLayout(
              children: [
                ListRow(
                  label: '全员禁言',
                  trailing: const Icon(
                    Icons.volume_off_outlined,
                    size: 20,
                    color: AppTheme.textSecondaryColor,
                  ),
                  onTap: () => _showGroupManageSheet(),
                ),
                const ListDivider(),
                ListRow(
                  label: '转让群主',
                  trailing: const Icon(
                    Icons.swap_horiz,
                    size: 20,
                    color: AppTheme.textSecondaryColor,
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
                      color: AppTheme.textSecondaryColor.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 14,
                      color: AppTheme.textSecondaryColor.withValues(alpha: 0.5),
                    ),
                  ],
                ),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => QrCodeScreen(
                        title: '群二维码',
                        data: _groupId,
                        subtitle: _groupName,
                      ),
                    ),
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

  Future<void> _showMemberActions(GroupMember member) async {
    final currentUserId = ref.read(userProfileProvider).profile?.userId ?? '';
    final members = ref.read(groupMemberProvider(_groupId)).members;
    final currentMember = members
        .where((m) => m.userId == currentUserId)
        .firstOrNull;
    final canManage = currentMember != null && currentMember.roleLevel >= 2;
    final isOwner = currentMember?.roleLevel == 3;

    if (!canManage || member.userId == currentUserId) {
      return;
    }

    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
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
    final ok = await ref
        .read(groupMemberProvider(_groupId).notifier)
        .setMemberRole(member.userId, isAdmin ? 2 : 1);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isAdmin ? '已设为管理员' : '已取消管理员'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('设置管理员失败')));
    }
  }

  void _showOwnerAdminList() {
    final members = ref
        .read(groupMemberProvider(_groupId))
        .members
        .where((m) => m.roleLevel >= 2)
        .toList();
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
      backgroundColor: Colors.white,
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
      backgroundColor: Colors.white,
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
                    ? const Icon(
                        Icons.check,
                        size: 20,
                        color: AppTheme.primaryColor,
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
            child: const Text(
              '踢出',
              style: TextStyle(color: AppTheme.unreadRed),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final ok = await ref
        .read(groupMemberProvider(_groupId).notifier)
        .kickMembers([member.userId]);
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('已踢出'),
          behavior: SnackBarBehavior.floating,
        ),
      );
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
      backgroundColor: Colors.white,
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
    final ok = await ref
        .read(groupMemberProvider(_groupId).notifier)
        .muteMember(member.userId, duration);
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('已禁言'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _unmuteMember(GroupMember member) async {
    final ok = await ref
        .read(groupMemberProvider(_groupId).notifier)
        .unmuteMember(member.userId);
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('已取消禁言'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _showGroupManageSheet() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
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
              leading: const Icon(
                Icons.delete_outline,
                color: AppTheme.unreadRed,
              ),
              title: const Text(
                '解散群组',
                style: TextStyle(color: AppTheme.unreadRed),
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
    final ok = await ref
        .read(groupMemberProvider(_groupId).notifier)
        .muteAll(isMute);
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isMute ? '已全员禁言' : '已解除全员禁言'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _transferOwner({GroupMember? target}) async {
    final members = ref.read(groupMemberProvider(_groupId)).members;
    final currentUserId = ref.read(userProfileProvider).profile?.userId ?? '';
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
      backgroundColor: Colors.white,
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

    final ok = await ref
        .read(groupMemberProvider(_groupId).notifier)
        .transferOwner(selected.userId);
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('群主已转让'),
          behavior: SnackBarBehavior.floating,
        ),
      );
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
            child: const Text(
              '解散',
              style: TextStyle(color: AppTheme.unreadRed),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final ok = await ref
        .read(groupMemberProvider(_groupId).notifier)
        .dismissGroup();
    if (ok && mounted) {
      await ref.read(groupListProvider.notifier).loadGroups();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('群组已解散'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        AppRouter.goBack(context);
      }
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
    try {
      await ref
          .read(groupRepositoryProvider)
          .setGroupInfo(_groupId, faceUrl: url);
      await ref.read(conversationListProvider.notifier).refreshConversations();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('群头像已更新'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('更新失败: $e')));
      }
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
            fillColor: AppTheme.backgroundColor,
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
    try {
      await ref
          .read(groupRepositoryProvider)
          .setGroupInfo(_groupId, groupName: value);
      if (mounted) {
        setState(() => _groupName = value);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('群名称已更新'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('群名称更新失败: $e')));
      }
    }
  }

  Future<void> _saveGroupDescription(String value) async {
    try {
      await ref
          .read(groupRepositoryProvider)
          .setGroupInfo(_groupId, introduction: value);
      if (mounted) {
        setState(() => _groupDescription = value.isEmpty ? '暂无描述' : value);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('群描述已更新'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('群描述更新失败: $e')));
      }
    }
  }
}
