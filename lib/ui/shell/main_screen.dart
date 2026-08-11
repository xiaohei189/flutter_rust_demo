import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/providers.dart';
import '../../l10n/app_localizations.dart';
import '../chat/views/chat_list_screen.dart';
import '../contacts/views/contacts_screen.dart';
import '../discover/views/discover_screen.dart';
import '../profile/views/mine_screen.dart';

/// 主页面 - 底部 Tab：消息、通讯录、发现、我的
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tabs = [
      (
        widget: const ChatListScreen(),
        label: l10n?.tabMessages ?? '消息',
        icon: Icons.chat_bubble_outline,
        activeIcon: Icons.chat_bubble,
      ),
      (
        widget: const ContactsScreen(),
        label: l10n?.tabContacts ?? '通讯录',
        icon: Icons.people_outline,
        activeIcon: Icons.people,
      ),
      (
        widget: const DiscoverScreen(),
        label: l10n?.tabDiscover ?? '发现',
        icon: Icons.explore_outlined,
        activeIcon: Icons.explore,
      ),
      (
        widget: const MineScreen(),
        label: l10n?.tabMine ?? '我的',
        icon: Icons.person_outline,
        activeIcon: Icons.person,
      ),
    ];
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: tabs.map((e) => e.widget).toList(),
      ),
      bottomNavigationBar: Consumer(
        builder: (context, ref, child) {
          final totalUnread = ref.watch(totalUnreadCountProvider);
          return BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            type: BottomNavigationBarType.fixed,
            items: [
              for (var i = 0; i < tabs.length; i++)
                BottomNavigationBarItem(
                  icon: i == 0 && totalUnread > 0
                      ? Badge(
                          label: Text(
                            totalUnread > 99 ? '99+' : '$totalUnread',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                            ),
                          ),
                          child: Icon(tabs[i].icon),
                        )
                      : Icon(tabs[i].icon),
                  activeIcon: i == 0 && totalUnread > 0
                      ? Badge(
                          label: Text(
                            totalUnread > 99 ? '99+' : '$totalUnread',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                            ),
                          ),
                          child: Icon(tabs[i].activeIcon),
                        )
                      : Icon(tabs[i].activeIcon),
                  label: tabs[i].label,
                ),
            ],
          );
        },
      ),
    );
  }
}

/// "我的"页面 - 用户信息 + 设置菜单
