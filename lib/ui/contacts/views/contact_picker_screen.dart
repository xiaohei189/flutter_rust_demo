import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../providers/providers.dart';
import '../../../../ui/core/theme/app_theme.dart';
import '../view_models/contact_picker_view_model.dart';
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
  late final ContactPickerViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = ref.read(contactPickerViewModelProvider.notifier);
    _viewModel.initialize(
      multiSelect: widget.multiSelect,
      excludeIds: widget.excludeIds ?? const [],
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_viewModel.ensureDataLoaded());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSelection(ContactPickItem item) {
    final shouldPop = _viewModel.toggleSelection(item);
    if (shouldPop) {
      Navigator.pop(context, [item]);
    }
  }

  void _confirmSelection() {
    if (ref.read(contactPickerViewModelProvider).selectedIds.isEmpty) return;
    Navigator.pop(context, _viewModel.confirmSelection());
  }

  @override
  Widget build(BuildContext context) {
    final friendState = ref.watch(friendListProvider);
    final groupState = ref.watch(groupListProvider);
    final pickerState = ref.watch(contactPickerViewModelProvider);
    final filteredFriends = _viewModel.filteredFriends(friendState.friends);
    final filteredGroups = _viewModel.filteredGroups(groupState.groups);
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
          if (widget.multiSelect && pickerState.selectedIds.isNotEmpty)
            TextButton(
              onPressed: _confirmSelection,
              child: Text(
                '确定(${pickerState.selectedIds.length})',
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
                    keyword: pickerState.keyword,
                    multiSelect: widget.multiSelect,
                    selectedIds: pickerState.selectedIds,
                    onToggle: _toggleSelection,
                  ),
          ),
        ],
      ),
      // 多选模式下的底部栏
      bottomNavigationBar:
          widget.multiSelect && pickerState.selectedIds.isNotEmpty
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
        onChanged: _viewModel.setKeyword,
        decoration: InputDecoration(
          hintText: '搜索联系人/群组',
          prefixIcon: Icon(
            Icons.search,
            size: 20,
            color: context.appColors.textSecondary,
          ),
          suffixIcon:
              ref.read(contactPickerViewModelProvider).keyword.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    _viewModel.clearKeyword();
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
            '已选 ${ref.read(contactPickerViewModelProvider).selectedIds.length} 项',
            style: TextStyle(
              fontSize: 14,
              color: context.appColors.textSecondary,
            ),
          ),
          const Spacer(),
          // 确认按钮
          ElevatedButton(
            onPressed:
                ref.read(contactPickerViewModelProvider).selectedIds.isEmpty
                ? null
                : _confirmSelection,
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
