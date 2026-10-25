import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_rust_demo/domain/models/conversation.dart';
import 'package:flutter_rust_demo/domain/models/friend_search_result.dart';
import 'package:flutter_rust_demo/domain/models/group.dart';
import 'package:flutter_rust_demo/domain/models/message_search_result.dart'
    show MessageSearchResult;
import 'package:flutter_rust_demo/ui/shared/providers/search_provider.dart';
import 'package:flutter_rust_demo/ui/shared/view_models/search_view_model.dart';

class FakeSearchGateway implements SearchGateway {
  FakeSearchGateway({this.shouldFail = false});

  final bool shouldFail;

  @override
  Future<List<MessageSearchResult>> searchMessages(String query) async {
    if (shouldFail) throw Exception('搜索失败');
    return const [];
  }

  @override
  Future<List<Conversation>> searchConversations(String query) async {
    if (shouldFail) throw Exception('搜索失败');
    return const [
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
  }

  @override
  Future<List<FriendSearchResult>> searchContacts(String query) async {
    if (shouldFail) throw Exception('搜索失败');
    return const [
      FriendSearchResult(
        userId: 'u1',
        nickname: '张三',
        faceUrl: '',
        remark: '',
        ex: '',
        relationship: 0,
      ),
    ];
  }

  @override
  Future<List<Group>> searchGroups(String query) async {
    if (shouldFail) throw Exception('搜索失败');
    return const [
      Group(
        groupId: 'g1',
        groupName: '测试群',
        faceUrl: '',
        introduction: '',
        notification: '',
        ownerUserId: 'u1',
        memberCount: 3,
        status: 0,
      ),
    ];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('联系人搜索成功后更新结果', () {
    fakeAsync((async) {
      final container = ProviderContainer(
        overrides: [
          searchGatewayProvider.overrideWithValue(FakeSearchGateway()),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(searchViewModelProvider.notifier);
      notifier.setCategory(SearchCategory.contacts);
      notifier.onQueryChanged('张');
      async.elapse(const Duration(milliseconds: 300));

      final state = container.read(searchViewModelProvider);
      expect(state.searching, isFalse);
      expect(state.error, isNull);
      expect(state.friendResults, hasLength(1));
    });
  });

  test('群组搜索成功后更新结果', () {
    fakeAsync((async) {
      final container = ProviderContainer(
        overrides: [
          searchGatewayProvider.overrideWithValue(FakeSearchGateway()),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(searchViewModelProvider.notifier);
      notifier.setCategory(SearchCategory.groups);
      notifier.onQueryChanged('测试');
      async.elapse(const Duration(milliseconds: 300));

      final state = container.read(searchViewModelProvider);
      expect(state.searching, isFalse);
      expect(state.groupResults, hasLength(1));
    });
  });

  test('搜索失败时写入中文错误', () {
    fakeAsync((async) {
      final container = ProviderContainer(
        overrides: [
          searchGatewayProvider.overrideWithValue(
            FakeSearchGateway(shouldFail: true),
          ),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(searchViewModelProvider.notifier);
      notifier.onQueryChanged('x');
      async.elapse(const Duration(milliseconds: 300));

      final state = container.read(searchViewModelProvider);
      expect(state.searching, isFalse);
      expect(state.error, contains('搜索失败'));
    });
  });

  test('清空关键词会清空结果', () {
    fakeAsync((async) {
      final container = ProviderContainer(
        overrides: [
          searchGatewayProvider.overrideWithValue(FakeSearchGateway()),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(searchViewModelProvider.notifier);
      notifier.setCategory(SearchCategory.contacts);
      notifier.onQueryChanged('张');
      async.elapse(const Duration(milliseconds: 300));
      expect(
        container.read(searchViewModelProvider).friendResults,
        hasLength(1),
      );

      notifier.onQueryChanged('');
      final state = container.read(searchViewModelProvider);
      expect(state.query, isEmpty);
      expect(state.friendResults, isEmpty);
    });
  });

  test('会话搜索成功后更新会话结果', () {
    fakeAsync((async) {
      final container = ProviderContainer(
        overrides: [
          searchGatewayProvider.overrideWithValue(FakeSearchGateway()),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(searchViewModelProvider.notifier);
      notifier.setCategory(SearchCategory.conversations);
      notifier.onQueryChanged('测试');
      async.elapse(const Duration(milliseconds: 300));

      final state = container.read(searchViewModelProvider);
      expect(state.searching, isFalse);
      expect(state.error, isNull);
      expect(state.conversationResults, hasLength(1));
      expect(state.conversationResults.first.conversationId, 'sg_g1');
    });
  });

  test('搜索历史去重、最多 10 条、可持久化与清空', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer(
      overrides: [searchGatewayProvider.overrideWithValue(FakeSearchGateway())],
    );
    addTearDown(container.dispose);
    final notifier = container.read(searchViewModelProvider.notifier);

    for (var i = 0; i < 12; i++) {
      await notifier.recordHistory('关键词$i');
    }
    await notifier.recordHistory('关键词5');

    var state = container.read(searchViewModelProvider);
    expect(state.history, hasLength(10), reason: '最多保留 10 条');
    expect(state.history.first, '关键词5', reason: '重复关键词应移到最前');
    expect(state.history.where((q) => q == '关键词5'), hasLength(1));

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('search_history_v1')?.first, '关键词5');

    await notifier.clearHistory();
    state = container.read(searchViewModelProvider);
    expect(state.history, isEmpty);
    expect(prefs.getStringList('search_history_v1'), isNull);
  });
}
