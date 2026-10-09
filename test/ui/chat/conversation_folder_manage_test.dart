import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_rust_demo/ui/chat/providers/conversation_folder_provider.dart';
import 'package:flutter_rust_demo/ui/chat/views/conversation_folder_manage_screen.dart';

/// 用 Mock 的 SharedPreferences 预置分组数据，并等待 Provider 首次加载完成。
Future<ProviderContainer> _containerWith(
  Map<String, List<String>> folders,
) async {
  SharedPreferences.setMockInitialValues({
    'conversation_folders_v1': jsonEncode(folders),
  });
  final container = ProviderContainer();
  addTearDown(container.dispose);
  container.read(conversationFoldersProvider);
  await Future<void>.delayed(const Duration(milliseconds: 50));
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('重命名分组保留会话与分组顺序', () async {
    final container = await _containerWith({
      'A': ['c1'],
      'B': ['c2'],
    });
    final notifier = container.read(conversationFoldersProvider.notifier);

    expect(await notifier.renameFolder('A', 'A2'), isTrue);

    final folders = container.read(conversationFoldersProvider);
    expect(folders.keys.toList(), ['A2', 'B']);
    expect(folders['A2'], ['c1']);
  });

  test('重命名守卫：空名 / 重名 / 不存在的分组都返回 false', () async {
    final container = await _containerWith({
      'A': ['c1'],
      'B': ['c2'],
    });
    final notifier = container.read(conversationFoldersProvider.notifier);

    expect(await notifier.renameFolder('A', '   '), isFalse);
    expect(await notifier.renameFolder('A', 'B'), isFalse);
    expect(await notifier.renameFolder('missing', 'C'), isFalse);
    expect(container.read(conversationFoldersProvider).keys.toList(), [
      'A',
      'B',
    ]);
  });

  test('reorderFolders 按给定顺序重排，集合不一致时忽略', () async {
    final container = await _containerWith({
      'A': ['c1'],
      'B': ['c2'],
      'C': ['c3'],
    });
    final notifier = container.read(conversationFoldersProvider.notifier);

    await notifier.reorderFolders(['C', 'A', 'B']);
    expect(container.read(conversationFoldersProvider).keys.toList(), [
      'C',
      'A',
      'B',
    ]);

    // 顺序与现有分组集合不一致：直接忽略，避免误删分组。
    await notifier.reorderFolders(['A', 'B']);
    expect(container.read(conversationFoldersProvider).keys.toList(), [
      'C',
      'A',
      'B',
    ]);
  });

  test('新建的空分组会落盘，重新加载后仍在', () async {
    final container = await _containerWith({});
    await container
        .read(conversationFoldersProvider.notifier)
        .createFolder('工作');
    expect(container.read(conversationFoldersProvider).keys.toList(), ['工作']);

    // 用新容器模拟重启：从同一份本地存储重新加载。
    final restarted = ProviderContainer();
    addTearDown(restarted.dispose);
    restarted.read(conversationFoldersProvider);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(restarted.read(conversationFoldersProvider).keys.toList(), ['工作']);
  });

  testWidgets('分组管理页展示分组与会话数量', (tester) async {
    SharedPreferences.setMockInitialValues({
      'conversation_folders_v1': jsonEncode({
        '工作': ['c1', 'c2'],
      }),
    });
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: ConversationFolderManageScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('分组管理'), findsOneWidget);
    expect(find.text('工作'), findsOneWidget);
    expect(find.text('2 个会话'), findsOneWidget);
  });

  testWidgets('没有分组时展示空态与新建入口', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: ConversationFolderManageScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('还没有分组'), findsOneWidget);
    expect(find.text('新建分组'), findsWidgets);
  });
}
