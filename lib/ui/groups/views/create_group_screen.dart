import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/models/friend.dart' show Friend, FriendDisplayName;
import '../../../../domain/models/group.dart';
import '../../../../domain/models/group_member.dart';
import '../../../../domain/models/user.dart';
import '../../../../providers/current_user_provider.dart';
import '../../contacts/providers/friend_provider.dart';
import '../../contacts/views/contact_picker_screen.dart';
import '../../contacts/widgets/contact_pick_item.dart';
import '../../core/theme/app_icon_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/user_avatar.dart';
import '../providers/group_provider.dart';
import '../view_models/create_group_view_model.dart';
import 'group_mode_screen.dart';

/// 创建群组页（对齐飞书稿）：先选人（顺带选群模式），再创建。
///
/// 飞书不在这一步填群名，群名由已选成员自动拼接；后端 `groupName` 必填，
/// 因此这里也只生成默认名，建完可在群设置里改。
class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

/// 「我的群组」整批拉进来的群：既用于展示群 chip，也用于移除时整批摘掉成员。
class _PickedGroup {
  const _PickedGroup({required this.name, required this.memberIds});

  final String name;
  final List<String> memberIds;
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final TextEditingController _searchController = TextEditingController();

  String _keyword = '';
  final Map<String, _PickedGroup> _pickedGroups = {};

  /// 好友列表之外（从群成员带进来）的昵称，用于头像与默认群名。
  final Map<String, String> _memberNames = {};

  bool _loadingGroupMembers = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(createGroupProvider.notifier).reset();
      ref.read(friendListProvider.notifier).loadFriends();
      ref.read(groupListProvider.notifier).loadGroups();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ==================== 数据辅助 ====================

  Set<String> _groupMemberIds() => {
    for (final group in _pickedGroups.values) ...group.memberIds,
  };

  String _displayNameOf(String userId) {
    final friend = ref
        .read(friendListProvider)
        .friends
        .where((f) => f.userId == userId)
        .firstOrNull;
    if (friend != null) return friend.displayName;
    return _memberNames[userId] ?? userId;
  }

  String? _avatarOf(String userId) {
    final friend = ref
        .read(friendListProvider)
        .friends
        .where((f) => f.userId == userId)
        .firstOrNull;
    final url = friend?.faceUrl ?? '';
    return url.isEmpty ? null : url;
  }

  /// 默认群名：已选成员昵称前三位，超过三人加「等」（对齐飞书的自动命名）。
  String _defaultGroupName(List<String> memberIds) {
    final names = memberIds
        .map(_displayNameOf)
        .where((name) => name.isNotEmpty)
        .toList();
    if (names.isEmpty) return '群聊';
    final head = names.take(3).join('、');
    return names.length > 3 ? '$head等' : head;
  }

  Future<List<GroupMember>> _loadGroupMembers(String groupId) async {
    final currentUserId = ref.read(currentUserIdProvider);
    try {
      final notifier = ref.read(groupMemberProvider(groupId).notifier);
      await notifier.loadMembers();
      final members = ref.read(groupMemberProvider(groupId)).members;
      return members
          .where((m) => m.userId.isNotEmpty && m.userId != currentUserId)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// 把「好友勾选」和「群整批成员」拼成最终成员列表。
  void _syncSelectionWithGroups() {
    final groupIds = _groupMemberIds();
    final friendIds = ref
        .read(createGroupProvider)
        .selectedMemberIds
        .where((id) => !groupIds.contains(id));
    ref.read(createGroupProvider.notifier).setSelectedMembers([
      ...friendIds,
      ...groupIds,
    ]);
  }

  // ==================== 选择动作 ====================

  Future<void> _pickFriends() async {
    final groupIds = _groupMemberIds();
    final friendSelection = ref
        .read(createGroupProvider)
        .selectedMemberIds
        .where((id) => !groupIds.contains(id))
        .toSet();
    final result = await Navigator.of(context).push<List<ContactPickItem>>(
      MaterialPageRoute(
        builder: (_) => ContactPickerScreen(
          key: const ValueKey('create_group_friend_picker'),
          multiSelect: true,
          includeGroups: false,
          title: '选择联系人',
          initialSelectedIds: friendSelection,
        ),
      ),
    );
    if (!mounted || result == null) return;
    final picked = result.where((item) => !item.isGroup).map((item) => item.id);
    ref.read(createGroupProvider.notifier).setSelectedMembers([
      ...picked,
      ...groupIds,
    ]);
  }

  Future<void> _pickGroups() async {
    final result = await Navigator.of(context).push<List<ContactPickItem>>(
      MaterialPageRoute(
        builder: (_) => ContactPickerScreen(
          key: const ValueKey('create_group_group_picker'),
          multiSelect: true,
          includeFriends: false,
          title: '选择群组',
          initialSelectedIds: _pickedGroups.keys.toSet(),
        ),
      ),
    );
    if (!mounted || result == null) return;
    final pickedItems = result.where((item) => item.isGroup).toList();
    final pickedIds = pickedItems.map((item) => item.id).toSet();

    // 取消勾选的群：整批成员一起移除
    setState(() {
      _pickedGroups.removeWhere((groupId, _) => !pickedIds.contains(groupId));
    });
    // 新勾选的群：拉一次成员
    for (final item in pickedItems) {
      if (_pickedGroups.containsKey(item.id)) continue;
      await _addPickedGroup(item.id, item.name);
    }
    _syncSelectionWithGroups();
  }

  /// 拉取群成员并整批加入选择，同时记住群名用于 chip 展示。
  Future<void> _addPickedGroup(String groupId, String groupName) async {
    setState(() => _loadingGroupMembers = true);
    final members = await _loadGroupMembers(groupId);
    if (!mounted) return;
    setState(() {
      _pickedGroups[groupId] = _PickedGroup(
        name: groupName,
        memberIds: members.map((m) => m.userId).toList(),
      );
      for (final member in members) {
        if (member.nickname.isNotEmpty) {
          _memberNames[member.userId] = member.nickname;
        }
      }
      _loadingGroupMembers = false;
    });
    if (members.isEmpty) {
      _toast('没有拉到「$groupName」的成员');
    }
  }

  Future<void> _toggleGroup(Group group) async {
    if (_pickedGroups.containsKey(group.groupId)) {
      setState(() => _pickedGroups.remove(group.groupId));
      _syncSelectionWithGroups();
      return;
    }
    await _addPickedGroup(group.groupId, group.groupName);
    _syncSelectionWithGroups();
  }

  void _removePickedGroup(String groupId) {
    setState(() => _pickedGroups.remove(groupId));
    _syncSelectionWithGroups();
  }

  void _removeSelectedMember(String userId) {
    // 群整批拉进来的成员要从群记录里一起摘掉，否则下次同步又会被加回来
    setState(() {
      for (final entry in _pickedGroups.entries.toList()) {
        if (!entry.value.memberIds.contains(userId)) continue;
        _pickedGroups[entry.key] = _PickedGroup(
          name: entry.value.name,
          memberIds: entry.value.memberIds.where((id) => id != userId).toList(),
        );
      }
    });
    ref.read(createGroupProvider.notifier).removeSelectedMember(userId);
  }

  // ==================== 创建 / 关闭 ====================

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  void _showFaceToFaceHint() {
    _toast('面对面建群需要服务端的附近能力，暂未开放');
  }

  Future<void> _handleCreate() async {
    final state = ref.read(createGroupProvider);
    if (state.selectedMemberIds.isEmpty) {
      _toast('请先选择联系人');
      return;
    }
    await ref
        .read(createGroupProvider.notifier)
        .createGroup(
          groupName: _defaultGroupName(state.selectedMemberIds),
          groupType: 2,
        );
  }

  Future<void> _handleClose() async {
    if (ref.read(createGroupProvider).selectedMemberIds.isNotEmpty) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('放弃创建群组？'),
          content: const Text('已选择的成员不会保留。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('继续创建'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(
                '放弃',
                style: TextStyle(color: context.appColors.danger),
              ),
            ),
          ],
        ),
      );
      if (discard != true) return;
    }
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  // ==================== 构建 ====================

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final state = ref.watch(createGroupProvider);
    final friends = ref.watch(friendListProvider).friends;
    final groups = ref.watch(groupListProvider).groups;

    ref.listen<CreateGroupState>(createGroupProvider, (previous, next) {
      final error = next.error;
      if (error != null && error != previous?.error) {
        _toast(error);
        return;
      }
      if (next.createdGroup != null) {
        _toast(next.mode.isTopic ? '群组创建成功（话题模式待接入，先按对话群创建）' : '群组创建成功');
        Navigator.of(context).pop(next.createdGroup);
      }
    });

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        automaticallyImplyLeading: false,
        leadingWidth: 52,
        leading: IconButton(
          key: const ValueKey('create_group_close'),
          icon: const Icon(Icons.close, size: 24),
          tooltip: '关闭',
          onPressed: _handleClose,
        ),
        title: const Text('创建群组'),
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: _keyword.isEmpty
                ? _buildSections(state, friends, groups)
                : _buildSearchResults(friends, groups, state),
          ),
          if (state.selectedMemberIds.isNotEmpty ||
              _pickedGroups.isNotEmpty ||
              _loadingGroupMembers)
            _buildSelectedStrip(state.selectedMemberIds),
          _buildBottomBar(state),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    final colors = context.appColors;
    return Container(
      color: colors.surface,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: TextField(
        key: const ValueKey('create_group_search'),
        controller: _searchController,
        onChanged: (value) => setState(() => _keyword = value.trim()),
        decoration: InputDecoration(
          hintText: '搜索联系人、我的群组',
          prefixIcon: Icon(Icons.search, size: 20, color: colors.textSecondary),
          suffixIcon: _keyword.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  color: colors.textSecondary,
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _keyword = '');
                  },
                ),
          filled: true,
          fillColor: colors.inputBackground,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            borderSide: BorderSide.none,
          ),
          hintStyle: TextStyle(color: colors.textSecondary, fontSize: 14),
        ),
        style: const TextStyle(fontSize: 14),
      ),
    );
  }

  Widget _buildSections(
    CreateGroupState state,
    List<Friend> friends,
    List<Group> groups,
  ) {
    final colors = context.appColors;
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _buildSectionHeader('选择联系人'),
        ColoredBox(
          color: colors.surface,
          child: Column(
            children: [
              _buildModeRow(state),
              Divider(height: 1, indent: 16, color: colors.divider),
              _buildEntryRow(
                key: const ValueKey('create_group_friends_entry'),
                icon: Icons.people_alt_outlined,
                color: AppIconColors.green,
                label: '我的好友',
                count: friends.isEmpty ? null : friends.length,
                onTap: _pickFriends,
              ),
              Divider(height: 1, indent: 56, color: colors.divider),
              _buildEntryRow(
                key: const ValueKey('create_group_groups_entry'),
                icon: Icons.groups_2_outlined,
                color: AppIconColors.blue,
                label: '我的群组',
                count: groups.isEmpty ? null : groups.length,
                onTap: _pickGroups,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _buildSectionHeader('其它方式'),
        ColoredBox(
          color: colors.surface,
          child: _buildEntryRow(
            key: const ValueKey('create_group_face_to_face_entry'),
            icon: Icons.wifi_tethering,
            color: AppIconColors.orange,
            label: '面对面建群',
            onTap: _showFaceToFaceHint,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Text(
        title,
        style: TextStyle(fontSize: 13, color: colors.textSecondary),
      ),
    );
  }

  Widget _buildModeRow(CreateGroupState state) {
    final colors = context.appColors;
    return InkWell(
      key: const ValueKey('create_group_mode_entry'),
      onTap: () => Navigator.of(
        context,
      ).push<void>(MaterialPageRoute(builder: (_) => const GroupModeScreen())),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '群模式',
                style: TextStyle(fontSize: 16, color: colors.textPrimary),
              ),
            ),
            Text(
              state.mode.isTopic ? '话题' : '对话',
              style: TextStyle(fontSize: 15, color: colors.textSecondary),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: colors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEntryRow({
    required Key key,
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
    int? count,
  }) {
    final colors = context.appColors;
    return InkWell(
      key: key,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(fontSize: 16, color: colors.textPrimary),
              ),
            ),
            if (count != null)
              Text(
                '$count',
                style: TextStyle(fontSize: 14, color: colors.textSecondary),
              ),
            const SizedBox(width: 6),
            Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: colors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults(
    List<Friend> friends,
    List<Group> groups,
    CreateGroupState state,
  ) {
    final colors = context.appColors;
    final keyword = _keyword.toLowerCase();
    final matchedFriends = friends
        .where(
          (f) =>
              f.displayName.toLowerCase().contains(keyword) ||
              f.userId.toLowerCase().contains(keyword),
        )
        .toList();
    final matchedGroups = groups
        .where(
          (g) =>
              g.groupName.toLowerCase().contains(keyword) ||
              g.groupId.toLowerCase().contains(keyword),
        )
        .toList();

    if (matchedFriends.isEmpty && matchedGroups.isEmpty) {
      return Center(
        child: Text(
          '未找到匹配结果',
          style: TextStyle(fontSize: 15, color: colors.textSecondary),
        ),
      );
    }

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        for (final friend in matchedFriends)
          ListTile(
            key: ValueKey('create_group_search_friend_${friend.userId}'),
            tileColor: colors.surface,
            leading: UserAvatar.fromUser(
              user: User(
                id: friend.userId,
                name: friend.displayName,
                avatar: friend.faceUrl.isEmpty ? null : friend.faceUrl,
              ),
              radius: 20,
            ),
            title: Text(
              friend.displayName,
              style: const TextStyle(fontSize: 15),
            ),
            trailing: Checkbox(
              value: state.selectedMemberIds.contains(friend.userId),
              activeColor: colors.primary,
              onChanged: (_) {
                final notifier = ref.read(createGroupProvider.notifier);
                if (state.selectedMemberIds.contains(friend.userId)) {
                  notifier.removeSelectedMember(friend.userId);
                } else {
                  notifier.addSelectedMember(friend.userId);
                }
              },
            ),
            onTap: () {
              final notifier = ref.read(createGroupProvider.notifier);
              if (state.selectedMemberIds.contains(friend.userId)) {
                notifier.removeSelectedMember(friend.userId);
              } else {
                notifier.addSelectedMember(friend.userId);
              }
            },
          ),
        for (final group in matchedGroups)
          ListTile(
            key: ValueKey('create_group_search_group_${group.groupId}'),
            tileColor: colors.surface,
            leading: UserAvatar(
              avatarUrl: group.faceUrl.isEmpty ? null : group.faceUrl,
              cacheKey: group.groupId,
              fallbackName: group.groupName,
              radius: 20,
            ),
            title: Text(group.groupName, style: const TextStyle(fontSize: 15)),
            subtitle: Text(
              '${group.memberCount} 人 · 整批加入',
              style: TextStyle(fontSize: 12, color: colors.textSecondary),
            ),
            trailing: Checkbox(
              value: _pickedGroups.containsKey(group.groupId),
              activeColor: colors.primary,
              onChanged: (_) => _toggleGroup(group),
            ),
            onTap: () => _toggleGroup(group),
          ),
      ],
    );
  }

  Widget _buildSelectedStrip(List<String> selectedIds) {
    final colors = context.appColors;
    return Container(
      color: colors.surface,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_loadingGroupMembers) ...[
            Row(
              children: [
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                Text(
                  '正在读取群成员…',
                  style: TextStyle(
                    fontSize: AppTheme.fontSizeCaption,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          if (_pickedGroups.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in _pickedGroups.entries)
                  InputChip(
                    key: ValueKey('create_group_chip_${entry.key}'),
                    label: Text(
                      '${entry.value.name}（${entry.value.memberIds.length}）',
                      style: const TextStyle(fontSize: 13),
                    ),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () => _removePickedGroup(entry.key),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          SizedBox(
            height: 56,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: selectedIds.length,
              separatorBuilder: (_, __) => const SizedBox(width: 4),
              itemBuilder: (context, index) =>
                  _buildSelectedAvatar(selectedIds[index]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedAvatar(String userId) {
    final colors = context.appColors;
    return SizedBox(
      key: ValueKey('create_group_selected_$userId'),
      width: 52,
      height: 56,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 4,
            top: 6,
            child: UserAvatar.fromUser(
              user: User(
                id: userId,
                name: _displayNameOf(userId),
                avatar: _avatarOf(userId),
              ),
              radius: 20,
            ),
          ),
          Positioned(
            right: 2,
            top: 2,
            child: GestureDetector(
              onTap: () => _removeSelectedMember(userId),
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: colors.textSecondary,
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.surface, width: 1.5),
                ),
                child: Icon(Icons.close, size: 11, color: colors.onPrimary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(CreateGroupState state) {
    final colors = context.appColors;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.divider)),
      ),
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      child: Row(
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '已选：',
                  style: TextStyle(fontSize: 15, color: colors.textSecondary),
                ),
                TextSpan(
                  text: '${state.selectedMemberIds.length}',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: colors.primary,
                  ),
                ),
                TextSpan(
                  text: ' 人',
                  style: TextStyle(fontSize: 15, color: colors.textSecondary),
                ),
              ],
            ),
          ),
          const Spacer(),
          SizedBox(
            height: 40,
            child: FilledButton(
              key: const ValueKey('create_group_submit'),
              onPressed: state.isCreating ? null : _handleCreate,
              style: FilledButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: colors.onPrimary,
                disabledBackgroundColor: colors.primary.withValues(alpha: 0.5),
                padding: const EdgeInsets.symmetric(horizontal: 28),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
              ),
              child: state.isCreating
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.onPrimary,
                      ),
                    )
                  : const Text(
                      '创建',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
