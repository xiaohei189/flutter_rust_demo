import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_rust_demo/domain/models/conversation.dart';
import 'package:flutter_rust_demo/ui/chat/providers/chat_list_provider.dart';
import 'package:flutter_rust_demo/ui/chat/view_models/chat_list_view_model.dart';
import 'package:flutter_rust_demo/ui/chat/widgets/group_filter_panel.dart';

Conversation _conversation({
  required String id,
  int type = 1,
  int unreadCount = 0,
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
  ex: '',
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

void main() {
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
  });
}
