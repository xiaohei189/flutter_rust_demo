import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/providers.dart';

/// 联系人页面
class ContactsScreen extends ConsumerStatefulWidget {
  const ContactsScreen({super.key});

  @override
  ConsumerState<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends ConsumerState<ContactsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(friendListProvider.notifier).loadFriends();
      ref.read(groupListProvider.notifier).loadGroups();
      ref.read(friendApplyProvider.notifier).loadApplications();
    });
  }

  @override
  Widget build(BuildContext context) {
    final friendState = ref.watch(friendListProvider);
    final applyState = ref.watch(friendApplyProvider);
    final groupState = ref.watch(groupListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('通讯录'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: () {
              context.push('/add-contact');
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                _ContactItem(
                  icon: Icons.person_add_outlined,
                  iconColor: const Color(0xFF07C160),
                  title: '新朋友',
                  badgeCount: applyState.unhandledCount,
                  onTap: () => context.push('/friend-requests'),
                ),
                const Divider(height: 1, indent: 56),
                _ContactItem(
                  icon: Icons.group_outlined,
                  iconColor: const Color(0xFF007AFF),
                  title: '我的好友',
                  trailingText: '${friendState.friendCount}',
                  onTap: () => context.push('/friend-list'),
                ),
                const Divider(height: 1, indent: 56),
                _ContactItem(
                  icon: Icons.groups_outlined,
                  iconColor: const Color(0xFFFF9500),
                  title: '我的群组',
                  trailingText: '${groupState.groups.length}',
                  onTap: () => context.push('/group-list'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 联系人列表项
class _ContactItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final int badgeCount;
  final String trailingText;
  final VoidCallback onTap;

  const _ContactItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.badgeCount = 0,
    this.trailingText = '',
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(title),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (badgeCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$badgeCount',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          if (trailingText.isNotEmpty)
            Text(
              trailingText,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF8E8E93),
              ),
            ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, color: Color(0xFFC7C7CC)),
        ],
      ),
      onTap: onTap,
    );
  }
}
