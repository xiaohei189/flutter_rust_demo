import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_rust_demo/ui/chat/widgets/list/chat_list_header.dart';
import 'package:flutter_rust_demo/ui/chat/widgets/list/group_filter_panel.dart'
    show GroupFilter;

void main() {
  Widget wrap({
    required bool isSyncing,
    String? syncError,
    VoidCallback? onRetrySync,
  }) => MaterialApp(
    home: Scaffold(
      body: ChatListHeader(
        activeFilter: GroupFilter.all,
        totalUnreadCount: 0,
        isQuickTab: true,
        isSyncing: isSyncing,
        syncProgress: 40,
        syncError: syncError,
        onRetrySync: onRetrySync,
        onFilterChange: (_) {},
        onOpenGroupFilter: () {},
        onSearchTap: () {},
      ),
    ),
  );

  testWidgets('同步失败时展示错误文案与重试按钮', (tester) async {
    var retried = 0;
    await tester.pumpWidget(
      wrap(
        isSyncing: false,
        syncError: '消息同步失败，请检查网络后重试',
        onRetrySync: () => retried++,
      ),
    );

    expect(find.text('消息同步失败，请检查网络后重试'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('sync_retry_button')));
    expect(retried, 1);
  });

  testWidgets('同步中优先展示进度，不展示失败提示', (tester) async {
    await tester.pumpWidget(
      wrap(
        isSyncing: true,
        syncError: '消息同步失败，请检查网络后重试',
        onRetrySync: () {},
      ),
    );

    expect(find.text('同步中 40%'), findsOneWidget);
    expect(find.byKey(const ValueKey('sync_retry_button')), findsNothing);
  });
}
