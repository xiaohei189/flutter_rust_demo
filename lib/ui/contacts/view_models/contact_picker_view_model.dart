import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/models/friend.dart';
import '../../../../domain/models/group.dart';
import '../../groups/providers/group_provider.dart';
import '../providers/friend_provider.dart';
import '../widgets/contact_pick_item.dart';

/// 联系人选择页状态
class ContactPickerState {
  final bool initialized;
  final bool multiSelect;
  final String keyword;
  final Set<String> selectedIds;
  final List<String> excludeIds;

  const ContactPickerState({
    this.initialized = false,
    this.multiSelect = false,
    this.keyword = '',
    this.selectedIds = const {},
    this.excludeIds = const [],
  });

  ContactPickerState copyWith({
    bool? initialized,
    bool? multiSelect,
    String? keyword,
    Set<String>? selectedIds,
    List<String>? excludeIds,
  }) {
    return ContactPickerState(
      initialized: initialized ?? this.initialized,
      multiSelect: multiSelect ?? this.multiSelect,
      keyword: keyword ?? this.keyword,
      selectedIds: selectedIds ?? this.selectedIds,
      excludeIds: excludeIds ?? this.excludeIds,
    );
  }
}

/// 联系人选择 ViewModel：负责数据加载、搜索过滤与选中状态。
class ContactPickerViewModel extends Notifier<ContactPickerState> {
  @override
  ContactPickerState build() => const ContactPickerState();

  void initialize({
    required bool multiSelect,
    List<String> excludeIds = const [],
  }) {
    if (state.initialized) return;
    state = state.copyWith(
      initialized: true,
      multiSelect: multiSelect,
      excludeIds: excludeIds,
    );
  }

  Future<void> ensureDataLoaded() async {
    final friendState = ref.read(friendListProvider);
    if (friendState.friends.isEmpty && !friendState.isLoading) {
      await ref.read(friendListProvider.notifier).loadFriends();
    }
    final groupState = ref.read(groupListProvider);
    if (groupState.groups.isEmpty && !groupState.isLoading) {
      await ref.read(groupListProvider.notifier).loadGroups();
    }
  }

  void setKeyword(String value) {
    state = state.copyWith(keyword: value);
  }

  void clearKeyword() {
    state = state.copyWith(keyword: '');
  }

  List<Friend> filteredFriends(List<Friend> friends) {
    final excludeSet = state.excludeIds.toSet();
    final keyword = state.keyword.toLowerCase();
    return friends.where((f) {
      if (excludeSet.contains(f.userId)) return false;
      if (keyword.isEmpty) return true;
      return f.nickname.toLowerCase().contains(keyword) ||
          f.userId.toLowerCase().contains(keyword) ||
          (f.remark.isNotEmpty && f.remark.toLowerCase().contains(keyword));
    }).toList();
  }

  List<Group> filteredGroups(List<Group> groups) {
    final excludeSet = state.excludeIds.toSet();
    final keyword = state.keyword.toLowerCase();
    return groups.where((g) {
      if (excludeSet.contains(g.groupId)) return false;
      if (keyword.isEmpty) return true;
      return g.groupName.toLowerCase().contains(keyword) ||
          g.groupId.toLowerCase().contains(keyword);
    }).toList();
  }

  /// 返回 true 表示单选模式可直接关闭页面。
  bool toggleSelection(ContactPickItem item) {
    final selectedIds = Set<String>.from(state.selectedIds);
    if (selectedIds.contains(item.id)) {
      selectedIds.remove(item.id);
    } else if (state.multiSelect) {
      selectedIds.add(item.id);
    } else {
      selectedIds
        ..clear()
        ..add(item.id);
    }
    state = state.copyWith(selectedIds: selectedIds);
    return !state.multiSelect && selectedIds.contains(item.id);
  }

  List<ContactPickItem> confirmSelection() {
    final items = <ContactPickItem>[];
    final friendState = ref.read(friendListProvider);
    final groupState = ref.read(groupListProvider);
    for (final f in friendState.friends) {
      if (state.selectedIds.contains(f.userId)) {
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
      if (state.selectedIds.contains(g.groupId)) {
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
    return items;
  }
}
