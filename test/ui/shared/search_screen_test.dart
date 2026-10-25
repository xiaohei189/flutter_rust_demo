import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_rust_demo/domain/models/conversation.dart';
import 'package:flutter_rust_demo/domain/models/friend_search_result.dart';
import 'package:flutter_rust_demo/domain/models/group.dart';
import 'package:flutter_rust_demo/domain/models/message_search_result.dart';
import 'package:flutter_rust_demo/ui/core/theme/app_theme.dart';
import 'package:flutter_rust_demo/ui/shared/providers/search_provider.dart';
import 'package:flutter_rust_demo/ui/shared/views/search_screen.dart';
import 'package:flutter_rust_demo/ui/shared/view_models/search_view_model.dart';

class _FakeGateway implements SearchGateway {
  @override
  Future<List<MessageSearchResult>> searchMessages(String query) async =>
      const [];

  @override
  Future<List<Conversation>> searchConversations(String query) async => const [
    Conversation(
      conversationId: 'sg_g1',
      conversationType: 2,
      userId: '',
      groupId: 'g1',
      showName: '测试群',
      faceUrl: '',
      latestMsg: '',
      latestMsgSendTime: 0,
      unreadCount: 0,
      recvMsgOpt: 0,
      isPinned: false,
      isPrivateChat: false,
      burnDuration: 0,
      groupAtType: 0,
      isNotInGroup: false,
      updateUnreadCountTime: 0,
      attachedInfo: '',
      ex: '',
      draftText: '',
      draftTextTime: 0,
      maxSeq: 0,
      minSeq: 0,
      isMsgDestruct: false,
      msgDestructTime: 0,
    ),
  ];

  @override
  Future<List<FriendSearchResult>> searchContacts(String query) async =>
      const [];

  @override
  Future<List<Group>> searchGroups(String query) async => const [];
}

Widget _host() => ProviderScope(
  overrides: [searchGatewayProvider.overrideWithValue(_FakeGateway())],
  child: MaterialApp(theme: AppTheme.lightTheme, home: const SearchScreen()),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('空查询展示最近搜索，清空后消失', (tester) async {
    SharedPreferences.setMockInitialValues({
      'search_history_v1': ['小萌', '测试群'],
    });
    await tester.pumpWidget(_host());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('最近搜索'), findsOneWidget);
    expect(find.text('小萌'), findsOneWidget);
    expect(find.text('测试群'), findsOneWidget);

    await tester.tap(find.text('清空'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('最近搜索'), findsNothing);
  });

  testWidgets('四个分类可见，会话分类展示会话结果', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(_host());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('消息'), findsOneWidget);
    expect(find.text('会话'), findsOneWidget);
    expect(find.text('联系人'), findsOneWidget);
    expect(find.text('群组'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '测试');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.text('会话'));
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('测试群'), findsWidgets);
  });
}
