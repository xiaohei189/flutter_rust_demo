import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../domain/models/friend.dart';
import '../../../../domain/models/group.dart';
import '../../../../providers/providers.dart';
import '../../../../ui/core/theme/app_theme.dart';
import '../widgets/contact_pick_item.dart';
import '../widgets/contact_picker_list.dart';

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
      backgroundColor: context.appColors.background,
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
                style: TextStyle(
                  color: context.appColors.primary,
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
                : ContactPickerList(
                    friends: filteredFriends,
                    groups: filteredGroups,
                    keyword: _keyword,
                    multiSelect: widget.multiSelect,
                    selectedIds: _selectedIds,
                    onToggle: _toggleSelection,
                  ),
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
          prefixIcon: Icon(
            Icons.search,
            size: 20,
            color: context.appColors.textSecondary,
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
          fillColor: context.appColors.background,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          hintStyle: TextStyle(
            color: context.appColors.textSecondary,
            fontSize: 14,
          ),
        ),
        style: const TextStyle(fontSize: 14),
      ),
    );
  }

  /// 多选模式底部栏
  Widget _buildBottomBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: context.appColors.divider, width: 0.5),
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
            style: TextStyle(
              fontSize: 14,
              color: context.appColors.textSecondary,
            ),
          ),
          const Spacer(),
          // 确认按钮
          ElevatedButton(
            onPressed: _selectedIds.isEmpty ? null : _confirmSelection,
            style: ElevatedButton.styleFrom(
              backgroundColor: context.appColors.primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: context.appColors.primary.withValues(
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
