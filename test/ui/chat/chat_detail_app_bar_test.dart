import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_rust_demo/domain/models/user.dart';
import 'package:flutter_rust_demo/ui/core/theme/app_theme.dart';
import 'package:flutter_rust_demo/ui/chat/widgets/shared/chat_detail_app_bar.dart';

void main() {
  testWidgets('ChatDetailAppBar 展示会话名、在线状态与搜索入口', (tester) async {
    var searchCalled = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          appBar: ChatDetailAppBar(
            user: const User(id: 'u1', name: '张三'),
            unread: 3,
            isTyping: false,
            isGroup: false,
            online: true,
            onBack: () {},
            onOpenSettings: () {},
            onSearch: () => searchCalled = true,
          ),
        ),
      ),
    );

    expect(find.text('张三'), findsOneWidget);
    expect(find.text('在线'), findsOneWidget);
    expect(find.byIcon(Icons.search), findsOneWidget);

    await tester.tap(find.byIcon(Icons.search));
    expect(searchCalled, isTrue);
  });

  testWidgets('群聊标题显示群聊文案', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          appBar: ChatDetailAppBar(
            user: const User(id: 'g1', name: '技术群'),
            unread: 0,
            isTyping: false,
            isGroup: true,
            online: null,
            onBack: () {},
            onOpenSettings: () {},
            onSearch: () {},
          ),
        ),
      ),
    );

    expect(find.text('技术群'), findsOneWidget);
    expect(find.text('群聊'), findsOneWidget);
  });
}