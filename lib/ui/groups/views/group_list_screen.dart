import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../domain/models/group.dart';
import '../../../../providers/providers.dart';

/// 我的群组页面
class GroupListScreen extends ConsumerStatefulWidget {
  const GroupListScreen({super.key});

  @override
  ConsumerState<GroupListScreen> createState() => _GroupListScreenState();
}

class _GroupListScreenState extends ConsumerState<GroupListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _createdScrollController = ScrollController();
  final _joinedScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _createdScrollController.addListener(
      () => _maybeLoadMore(_createdScrollController),
    );
    _joinedScrollController.addListener(
      () => _maybeLoadMore(_joinedScrollController),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(groupListProvider.notifier).loadGroups();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _createdScrollController.dispose();
    _joinedScrollController.dispose();
    super.dispose();
  }

  void _maybeLoadMore(ScrollController controller) {
    if (!controller.hasClients) return;
    final position = controller.position;
    if (position.pixels >= position.maxScrollExtent - 200) {
      ref.read(groupListProvider.notifier).loadMoreGroups();
    }
  }

  @override
  Widget build(BuildContext context) {
    final groupState = ref.watch(groupListProvider);
    final currentUserId = ref.watch(userProfileProvider).profile?.userId ?? '';

    final createdGroups = groupState.groups
        .where((g) => g.ownerUserId == currentUserId)
        .toList();
    final joinedGroups = groupState.groups
        .where((g) => g.ownerUserId != currentUserId)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的群组'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '我创建的'),
            Tab(text: '我加入的'),
          ],
        ),
      ),
      body: groupState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _GroupTab(
                  groups: createdGroups,
                  controller: _createdScrollController,
                  isLoadingMore: groupState.isLoadingMore,
                ),
                _GroupTab(
                  groups: joinedGroups,
                  controller: _joinedScrollController,
                  isLoadingMore: groupState.isLoadingMore,
                ),
              ],
            ),
    );
  }
}

/// 群组 Tab 内容
class _GroupTab extends StatelessWidget {
  final List<Group> groups;
  final ScrollController? controller;
  final bool isLoadingMore;

  const _GroupTab({
    required this.groups,
    this.controller,
    this.isLoadingMore = false,
  });

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) {
      return const Center(
        child: Text(
          '暂无群组',
          style: TextStyle(fontSize: 16, color: Color(0xFF8E8E93)),
        ),
      );
    }

    return ListView.builder(
      controller: controller,
      itemCount: groups.length + (isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == groups.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final group = groups[index];
        return ListTile(
          leading: CircleAvatar(
            radius: 22,
            backgroundColor: _avatarColor(group.groupName),
            child: Text(
              _initial(group.groupName),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          title: Text(
            group.groupName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '${group.memberCount}人',
            style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E93)),
          ),
          onTap: () {
            context.push('/group/${group.groupId}/info');
          },
        );
      },
    );
  }

  String _initial(String name) {
    if (name.isEmpty) return '?';
    return name[0];
  }

  Color _avatarColor(String name) {
    if (name.isEmpty) return const Color(0xFF007AFF);
    final colors = [
      const Color(0xFF007AFF),
      const Color(0xFF07C160),
      const Color(0xFFFF9500),
      const Color(0xFFFF3B30),
      const Color(0xFFAF52DE),
      const Color(0xFF5AC8FA),
      const Color(0xFFFF6482),
      const Color(0xFF34C759),
    ];
    return colors[name.hashCode.abs() % colors.length];
  }
}
