import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../domain/models/group.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/state_views.dart';

/// 群组 Tab 内容
class GroupTab extends StatelessWidget {
  final List<Group> groups;
  final ScrollController? controller;
  final bool isLoadingMore;

  const GroupTab({
    super.key,
    required this.groups,
    this.controller,
    this.isLoadingMore = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    if (groups.isEmpty) {
      return const EmptyState(icon: Icons.groups_outlined, title: '暂无群组');
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
            style: TextStyle(fontSize: 12, color: colors.textSecondary),
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
