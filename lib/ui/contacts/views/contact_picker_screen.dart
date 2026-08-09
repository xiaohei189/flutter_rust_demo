import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../domain/models/friend.dart';
import '../../../../domain/models/group.dart';
import '../../../../providers/providers.dart';
import '../../../../ui/core/theme/app_theme.dart';
import '../../../../ui/core/widgets/user_avatar.dart';
import '../../../../domain/models/user.dart';

/// 联系人选择结果项
class ContactPickItem {
  final String id;
  final String name;
  final String avatarUrl;
  final bool isGroup;

  const ContactPickItem({
    required this.id,
    required this.name,
    required this.avatarUrl,
    required this.isGroup,
  });
}

/// 通用联系人选择页面
/// 支持单选（转发）和多选（建群）模式
class ContactPickerScreen extends ConsumerStatefulWidget {
  final bool multiSelect;
  final String? title;
  final List<String>? excludeIds;

  const ContactPickerScreen({
    super.key,
    this.multiSelect = false,
    this.title,
    this.excludeIds,
  });

  @override
  ConsumerState<ContactPickerScreen> createState() =>
      _ContactPickerScreenState();
}

class _ContactPickerScreenState extends ConsumerState<ContactPickerScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _keyword = '';
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureDataLoaded();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// 确保好友和群组数据已加载
  Future<void> _ensureDataLoaded() async {
    final friendState = ref.read(friendListProvider);
    if (friendState.friends.isEmpty && !friendState.isLoading) {
      await ref.read(friendListProvider.notifier).loadFriends();
    }
    final groupState = ref.read(groupListProvider);
    if (groupState.groups.isEmpty && !groupState.isLoading) {
      await ref.read(groupListProvider.notifier).loadGroups();
    }
  }

  /// 获取过滤后的好友列表
  List<Friend> _getFilteredFriends(List<Friend> friends) {
    final excludeSet = widget.excludeIds?.toSet() ?? {};
    return friends.where((f) {
      if (excludeSet.contains(f.userId)) return false;
      if (_keyword.isEmpty) return true;
      final kw = _keyword.toLowerCase();
      return f.nickname.toLowerCase().contains(kw) ||
          f.userId.toLowerCase().contains(kw) ||
          (f.remark.isNotEmpty && f.remark.toLowerCase().contains(kw));
    }).toList();
  }

  /// 获取过滤后的群组列表
  List<Group> _getFilteredGroups(List<Group> groups) {
    final excludeSet = widget.excludeIds?.toSet() ?? {};
    return groups.where((g) {
      if (excludeSet.contains(g.groupId)) return false;
      if (_keyword.isEmpty) return true;
      final kw = _keyword.toLowerCase();
      return g.groupName.toLowerCase().contains(kw) ||
          g.groupId.toLowerCase().contains(kw);
    }).toList();
  }

  /// 切换选中状态
  void _toggleSelection(ContactPickItem item) {
    setState(() {
      if (_selectedIds.contains(item.id)) {
        _selectedIds.remove(item.id);
      } else {
        if (widget.multiSelect) {
          _selectedIds.add(item.id);
        } else {
          _selectedIds.clear();
          _selectedIds.add(item.id);
        }
      }
    });

    // 单选模式下直接返回
    if (!widget.multiSelect && _selectedIds.contains(item.id)) {
      Navigator.pop(context, [item]);
    }
  }

  /// 确认选择
  void _confirmSelection() {
    if (_selectedIds.isEmpty) return;

    final friendState = ref.read(friendListProvider);
    final groupState = ref.read(groupListProvider);

    final items = <ContactPickItem>[];

    for (final f in friendState.friends) {
      if (_selectedIds.contains(f.userId)) {
        items.add(
          ContactPickItem(
            id: f.userId,
            name: f.remark.isNotEmpty ? f.remark : f.nickname,
            avatarUrl: f.faceUrl,
            isGroup: false,
          ),
        );
      }
    }

    for (final g in groupState.groups) {
      if (_selectedIds.contains(g.groupId)) {
        items.add(
          ContactPickItem(
            id: g.groupId,
            name: g.groupName,
            avatarUrl: g.faceUrl,
            isGroup: true,
          ),
        );
      }
    }

    Navigator.pop(context, items);
  }

  @override
  Widget build(BuildContext context) {
    final friendState = ref.watch(friendListProvider);
    final groupState = ref.watch(groupListProvider);
    final filteredFriends = _getFilteredFriends(friendState.friends);
    final filteredGroups = _getFilteredGroups(groupState.groups);
    final isLoading = friendState.isLoading || groupState.isLoading;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 22),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(widget.title ?? '选择联系人'),
        actions: [
          if (widget.multiSelect && _selectedIds.isNotEmpty)
            TextButton(
              onPressed: _confirmSelection,
              child: Text(
                '确定(${_selectedIds.length})',
                style: const TextStyle(
                  color: AppTheme.primaryColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // 搜索栏
          _buildSearchBar(),
          // 联系人列表
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildContactList(filteredFriends, filteredGroups),
          ),
        ],
      ),
      // 多选模式下的底部栏
      bottomNavigationBar: widget.multiSelect && _selectedIds.isNotEmpty
          ? _buildBottomBar()
          : null,
    );
  }

  /// 搜索栏
  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _keyword = v),
        decoration: InputDecoration(
          hintText: '搜索联系人/群组',
          prefixIcon: const Icon(
            Icons.search,
            size: 20,
            color: AppTheme.textSecondaryColor,
          ),
          suffixIcon: _keyword.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _keyword = '');
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: AppTheme.backgroundColor,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          hintStyle: const TextStyle(
            color: AppTheme.textSecondaryColor,
            fontSize: 14,
          ),
        ),
        style: const TextStyle(fontSize: 14),
      ),
    );
  }

  /// 联系人列表
  Widget _buildContactList(List<Friend> friends, List<Group> groups) {
    final hasFriends = friends.isNotEmpty;
    final hasGroups = groups.isNotEmpty;

    if (!hasFriends && !hasGroups) {
      return Center(
        child: Text(
          _keyword.isEmpty ? '暂无联系人' : '未找到匹配结果',
          style: const TextStyle(
            color: AppTheme.textSecondaryColor,
            fontSize: 15,
          ),
        ),
      );
    }

    return ListView(
      children: [
        // 我的好友
        if (hasFriends) ...[
          _buildSectionHeader('我的好友', friends.length),
          ...friends.map((f) => _buildFriendItem(f)),
        ],
        // 我的群组
        if (hasGroups) ...[
          _buildSectionHeader('我的群组', groups.length),
          ...groups.map((g) => _buildGroupItem(g)),
        ],
        // 底部间距
        const SizedBox(height: 80),
      ],
    );
  }

  /// 分区标题
  Widget _buildSectionHeader(String title, int count) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondaryColor,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$count',
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondaryColor,
            ),
          ),
        ],
      ),
    );
  }

  /// 好友列表项
  Widget _buildFriendItem(Friend friend) {
    final id = friend.userId;
    final displayName = friend.remark.isNotEmpty
        ? friend.remark
        : friend.nickname;
    final isSelected = _selectedIds.contains(id);

    return InkWell(
      onTap: () => _toggleSelection(
        ContactPickItem(
          id: id,
          name: displayName,
          avatarUrl: friend.faceUrl,
          isGroup: false,
        ),
      ),
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            UserAvatar(
              user: User(
                id: id,
                name: displayName,
                avatar: friend.faceUrl.isNotEmpty ? friend.faceUrl : null,
              ),
              radius: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppTheme.textPrimaryColor,
                    ),
                  ),
                  if (friend.remark.isNotEmpty)
                    Text(
                      friend.nickname,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                ],
              ),
            ),
            if (widget.multiSelect)
              Checkbox(
                value: isSelected,
                onChanged: (_) => _toggleSelection(
                  ContactPickItem(
                    id: id,
                    name: displayName,
                    avatarUrl: friend.faceUrl,
                    isGroup: false,
                  ),
                ),
                activeColor: AppTheme.primaryColor,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
          ],
        ),
      ),
    );
  }

  /// 群组列表项
  Widget _buildGroupItem(Group group) {
    final id = group.groupId;
    final isSelected = _selectedIds.contains(id);

    return InkWell(
      onTap: () => _toggleSelection(
        ContactPickItem(
          id: id,
          name: group.groupName,
          avatarUrl: group.faceUrl,
          isGroup: true,
        ),
      ),
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            UserAvatar(
              user: User(
                id: id,
                name: group.groupName,
                avatar: group.faceUrl.isNotEmpty ? group.faceUrl : null,
              ),
              radius: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.groupName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppTheme.textPrimaryColor,
                    ),
                  ),
                  Text(
                    '${group.memberCount}人',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondaryColor,
                    ),
                  ),
                ],
              ),
            ),
            if (widget.multiSelect)
              Checkbox(
                value: isSelected,
                onChanged: (_) => _toggleSelection(
                  ContactPickItem(
                    id: id,
                    name: group.groupName,
                    avatarUrl: group.faceUrl,
                    isGroup: true,
                  ),
                ),
                activeColor: AppTheme.primaryColor,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
          ],
        ),
      ),
    );
  }

  /// 多选模式底部栏
  Widget _buildBottomBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: AppTheme.dividerColor, width: 0.5),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      child: Row(
        children: [
          // 已选数量
          Text(
            '已选 ${_selectedIds.length} 项',
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondaryColor,
            ),
          ),
          const Spacer(),
          // 确认按钮
          ElevatedButton(
            onPressed: _selectedIds.isEmpty ? null : _confirmSelection,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppTheme.primaryColor.withValues(
                alpha: 0.5,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text(
              '确定',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
