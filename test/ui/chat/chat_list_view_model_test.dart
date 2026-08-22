import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_rust_demo/domain/models/conversation.dart';
import 'package:flutter_rust_demo/ui/chat/providers/chat_list_provider.dart';
import 'package:flutter_rust_demo/ui/chat/providers/conversation_folder_provider.dart';
import 'package:flutter_rust_demo/ui/chat/view_models/chat_list_view_model.dart';
import 'package:flutter_rust_demo/ui/chat/widgets/list/group_filter_panel.dart';

Conversation _conversation({
  required String id,
  int type = 1,
  int unreadCount = 0,
  String ex = '',
}) => Conversation(
  conversationId: id,
  conversationType: type,
  userId: 'u1',
  groupId: '',
  showName: '会话$id',
  faceUrl: '',
  latestMsg: '',
  latestMsgSendTime: 0,
  unreadCount: unreadCount,
  recvMsgOpt: 0,
  isPinned: false,
  isPrivateChat: false,
  burnDuration: 0,
  groupAtType: 0,
  isNotInGroup: false,
  updateUnreadCountTime: 0,
  attachedInfo: '',
  ex: ex,
  draftText: '',
  draftTextTime: 0,
  maxSeq: 0,
  minSeq: 0,
  isMsgDestruct: false,
  msgDestructTime: 0,
);

ChatListViewModel buildViewModel() {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  return container.read(chatListViewModelProvider.notifier);
}

/// 预置分组数据到 SharedPreferences，返回 buildViewModel 后的实例。
Future<ChatListViewModel> buildViewModelWithFolders(
  Map<String, List<String>> folders,
) async {
  SharedPreferences.setMockInitialValues({
    'conversation_folders_v1': jsonEncode(folders),
  });
  final container = ProviderContainer();
  addTearDown(container.dispose);
  // 先触发分组 Provider 加载，再等待异步完成。
  container.read(conversationFoldersProvider);
  await Future<void>.delayed(const Duration(milliseconds: 50));
  return container.read(chatListViewModelProvider.notifier);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ChatListViewModel', () {
    test('setFilter 更新筛选状态', () {
      final viewModel = buildViewModel();

      viewModel.setFilter(GroupFilter.unread);

      expect(viewModel.state.activeFilter, GroupFilter.unread);
    });

    test('filteredConversations 按未读筛选', () {
      final viewModel = buildViewModel();
      viewModel.setFilter(GroupFilter.unread);
      final conversations = [
        _conversation(id: 'c1', unreadCount: 1),
        _conversation(id: 'c2'),
      ];

      final result = viewModel.filteredConversations(conversations);

      expect(result.map((c) => c.conversationId), ['c1']);
    });

    test('filteredConversations 按群聊筛选', () {
      final viewModel = buildViewModel();
      viewModel.setFilter(GroupFilter.groupChat);
      final conversations = [
        _conversation(id: 'single'),
        _conversation(id: 'group', type: 2),
      ];

      final result = viewModel.filteredConversations(conversations);

      expect(result.map((c) => c.conversationId), ['group']);
    });

    test('未支持筛选返回空列表', () {
      final viewModel = buildViewModel();
      viewModel.setFilter(GroupFilter.atMe);

      final result = viewModel.filteredConversations([_conversation(id: 'c1')]);

      expect(result, isEmpty);
    });

    test('emptyStateLabel 与 isQuickTab 返回稳定结果', () {
      final viewModel = buildViewModel();

      expect(viewModel.emptyStateLabel(GroupFilter.groupChat), '群组');
      expect(viewModel.isQuickTab(GroupFilter.all), isTrue);
      expect(viewModel.isQuickTab(GroupFilter.atMe), isFalse);
    });

    test('effectiveUnreadCount：本地标未读时至少显示 1', () {
      final plain = _conversation(id: 'c1');
      final marked = _conversation(
        id: 'c2',
        ex: ChatListViewModel.updateFlags(
          _conversation(id: 'c2'),
          unread: true,
        ),
      );

      expect(ChatListViewModel.effectiveUnreadCount(plain), 0);
      expect(ChatListViewModel.effectiveUnreadCount(marked), 1);
    });

    test('updateFlags 保留其他标记 key', () {
      final base = _conversation(
        id: 'c1',
        ex: ChatListViewModel.flagsEx(flagged: true, done: false),
      );

      final ex = ChatListViewModel.updateFlags(base, unread: true);

      expect(ex, contains('"flagged":true'));
      expect(ex, contains('"unread":true'));
      expect(ex, isNot(contains('"done":true')));
    });

    test('filteredConversations：普通筛选排除归档，归档筛选只显示归档', () {
      final viewModel = buildViewModel();
      final normal = _conversation(id: 'c1');
      final archived = _conversation(
        id: 'c2',
        ex: ChatListViewModel.updateFlags(
          _conversation(id: 'c2'),
          archived: true,
        ),
      );
      final conversations = [normal, archived];

      viewModel.setFilter(GroupFilter.all);
      expect(
        viewModel
            .filteredConversations(conversations)
            .map((c) => c.conversationId),
        ['c1'],
      );

      viewModel.setFilter(GroupFilter.archived);
      expect(
        viewModel
            .filteredConversations(conversations)
            .map((c) => c.conversationId),
        ['c2'],
      );
    });

    test('未读筛选使用展示未读数（含本地标未读）', () {
      final viewModel = buildViewModel();
      viewModel.setFilter(GroupFilter.unread);
      final marked = _conversation(
        id: 'c1',
        ex: ChatListViewModel.updateFlags(
          _conversation(id: 'c1'),
          unread: true,
        ),
      );
      final conversations = [marked, _conversation(id: 'c2')];

      final result = viewModel.filteredConversations(conversations);

      expect(result.map((c) => c.conversationId), ['c1']);
    });

    test('setFolder 按分组筛选，且排除归档', () async {
      final viewModel = await buildViewModelWithFolders({
        '工作': ['c1', 'c2'],
      });
      final archived = _conversation(
        id: 'c2',
        ex: ChatListViewModel.updateFlags(
          _conversation(id: 'c2'),
          archived: true,
        ),
      );
      final conversations = [_conversation(id: 'c1'), archived];

      viewModel.setFolder('工作');

      final result = viewModel.filteredConversations(conversations);

      expect(viewModel.state.activeFolder, '工作');
      expect(result.map((c) => c.conversationId), ['c1']);
    });

    test('setFilter 清除分组筛选', () async {
      final viewModel = await buildViewModelWithFolders({
        '工作': ['c1'],
      });
      viewModel.setFolder('工作');
      viewModel.setFilter(GroupFilter.all);

      expect(viewModel.state.activeFolder, isNull);
    });
  });
}
