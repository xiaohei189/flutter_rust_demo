import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/providers.dart';
import '../src/rust/model/group.dart' show GroupInfo;

/// 我的群组页面
class GroupListScreen extends ConsumerStatefulWidget {
  const GroupListScreen({super.key});

  @override
  ConsumerState<GroupListScreen> createState() => _GroupListScreenState();
}

class _GroupListScreenState extends ConsumerState<GroupListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(groupListProvider.notifier).loadGroups();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final groupState = ref.watch(groupListProvider);
    final currentUserId = ref.watch(userProfileProvider).profile?.userId ?? '';

    final createdGroups =
        groupState.groups.where((g) => g.ownerUserId == currentUserId).toList();
    final joinedGroups =
        groupState.groups.where((g) => g.ownerUserId != currentUserId).toList();

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
                _GroupTab(groups: createdGroups),
                _GroupTab(groups: joinedGroups),
              ],
            ),
    );
  }
}

/// 群组 Tab 内容
class _GroupTab extends StatelessWidget {
  final List<GroupInfo> groups;

  const _GroupTab({required this.groups});

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
      itemCount: groups.length,
      itemBuilder: (context, index) {
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
