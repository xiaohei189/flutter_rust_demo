import 'package:flutter/material.dart';

import 'chat_list_screen.dart';
import 'contacts_screen.dart';
import 'discover_screen.dart';
import 'profile_screen.dart';

/// 主页面 - 底部导航与 openim-flutter-demo 对齐：会话、通讯录、发现、我的
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  static const _tabs = [
    (widget: ChatListScreen(), label: '会话', icon: Icons.chat_bubble_outline, activeIcon: Icons.chat_bubble),
    (widget: ContactsScreen(), label: '通讯录', icon: Icons.people_outline, activeIcon: Icons.people),
    (widget: DiscoverScreen(), label: '发现', icon: Icons.explore_outlined, activeIcon: Icons.explore),
    (widget: ProfileScreen(), label: '我的', icon: Icons.person_outline, activeIcon: Icons.person),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _tabs.map((e) => e.widget).toList(),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        items: [
          for (var i = 0; i < _tabs.length; i++)
            BottomNavigationBarItem(
              icon: Icon(_tabs[i].icon),
              activeIcon: Icon(_tabs[i].activeIcon),
              label: _tabs[i].label,
            ),
        ],
      ),
    );
  }
}



