import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../profile/providers/user_profile_provider.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/group_provider.dart';
import '../widgets/group_tab.dart';

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
        title: Text(AppLocalizations.of(context)?.groupListTitle ?? '我的群组'),
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
                GroupTab(
                  groups: createdGroups,
                  controller: _createdScrollController,
                  isLoadingMore: groupState.isLoadingMore,
                ),
                GroupTab(
                  groups: joinedGroups,
                  controller: _joinedScrollController,
                  isLoadingMore: groupState.isLoadingMore,
                ),
              ],
            ),
    );
  }
}
