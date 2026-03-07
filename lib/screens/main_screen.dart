import 'package:flutter/material.dart';

import 'chat_list_screen.dart';
import 'contacts_screen.dart';

/// 主页面 - 底部 Tab：消息、通讯录
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  static const _tabs = [
    (widget: ChatListScreen(), label: '消息', icon: Icons.chat_bubble_outline, activeIcon: Icons.chat_bubble),
    (widget: ContactsScreen(), label: '通讯录', icon: Icons.people_outline, activeIcon: Icons.people),
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
