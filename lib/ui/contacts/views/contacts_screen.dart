import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../providers/providers.dart';
import '../../../../l10n/app_localizations.dart';
import '../widgets/contact_item.dart';

/// 联系人页面
class ContactsScreen extends ConsumerWidget {
  const ContactsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friendState = ref.watch(friendListProvider);
    final applyState = ref.watch(friendApplyProvider);
    final groupState = ref.watch(groupListProvider);
    final groupApplyState = ref.watch(groupApplicationProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)?.contactsTitle ?? '通讯录'),
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
                ContactItem(
                  icon: Icons.person_add_outlined,
                  iconColor: const Color(0xFF07C160),
                  title: '新朋友',
                  badgeCount: applyState.unhandledCount,
                  onTap: () => context.push('/friend-requests'),
                ),
                const Divider(height: 1, indent: 56),
                ContactItem(
                  icon: Icons.group_outlined,
                  iconColor: const Color(0xFF007AFF),
                  title: '我的好友',
                  trailingText: '${friendState.friendCount}',
                  onTap: () => context.push('/friend-list'),
                ),
                const Divider(height: 1, indent: 56),
                ContactItem(
                  icon: Icons.groups_outlined,
                  iconColor: const Color(0xFFFF9500),
                  title: '我的群组',
                  trailingText: '${groupState.groups.length}',
                  onTap: () => context.push('/group-list'),
                ),
                const Divider(height: 1, indent: 56),
                ContactItem(
                  icon: Icons.group_add_outlined,
                  iconColor: const Color(0xFF34C759),
                  title: '群申请',
                  badgeCount: groupApplyState.unhandledCount,
                  onTap: () => context.push('/group-applications'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
