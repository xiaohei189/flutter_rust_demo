import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_rust_demo/domain/models/conversation.dart';
import 'package:flutter_rust_demo/domain/models/group.dart';
import 'package:flutter_rust_demo/domain/models/group_member.dart';
import 'package:flutter_rust_demo/ui/chat/providers/conversation_provider.dart';
import 'package:flutter_rust_demo/ui/chat/view_models/conversation_view_model.dart';
import 'package:flutter_rust_demo/ui/groups/providers/group_info_provider.dart';
import 'package:flutter_rust_demo/ui/groups/providers/group_provider.dart';
import 'package:flutter_rust_demo/ui/groups/view_models/group_info_view_model.dart';

import '../../support/fakes/fake_group_repository.dart';

class FakeGroupRepository extends BaseFakeGroupRepository {
  FakeGroupRepository({this.shouldFail = false});

  bool shouldFail;
  final List<String> groupNameUpdates = [];
  final List<String> descriptionUpdates = [];
  final List<String> avatarUpdates = [];
  final List<String> kickedUserIds = [];

  @override
  Future<List<GroupMember>> loadMembers(String groupId) async => const [];

  @override
  Future<List<Group>> loadGroups({int offset = 0, int count = 50}) async =>
      const [];

  @override
  Future<void> setGroupInfo(
    String groupId, {
    String? groupName,
    String? faceUrl,
    String? introduction,
    String? notification,
  }) async {
    if (shouldFail) throw Exception('更新失败');
    if (groupName != null) groupNameUpdates.add(groupName);
    if (introduction != null) descriptionUpdates.add(introduction);
    if (faceUrl != null) avatarUpdates.add(faceUrl);
  }

  @override
  Future<void> kickMembers(String groupId, List<String> memberIds) async {
    if (shouldFail) throw Exception('踢出失败');
    kickedUserIds.addAll(memberIds);
  }
}

class FakeConversationListNotifier extends ConversationListNotifier {
  FakeConversationListNotifier(this.conversation);

  final Conversation conversation;

  @override
  ConversationListState build() =>
      ConversationListState(conversations: [conversation]);
}

Conversation _makeGroupConversation() => const Conversation(
  conversationId: 'conv1',
  conversationType: 2,
  userId: '',
  groupId: 'g1',
  showName: '测试群',
  faceUrl: 'http://example.com/avatar.png',
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
);

GroupInfoViewModel buildViewModel(FakeGroupRepository repository) {
  final container = ProviderContainer(
    overrides: [
      groupRepositoryProvider.overrideWithValue(repository),
      conversationListProvider.overrideWith(
        () => FakeConversationListNotifier(_makeGroupConversation()),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container.read(groupInfoViewModelProvider('conv1').notifier);
}

void main() {
  group('GroupInfoViewModel', () {
    test('load 初始化群名称与描述', () async {
      final viewModel = buildViewModel(FakeGroupRepository());

      await viewModel.load();

      expect(viewModel.currentState.groupName, '测试群');
      expect(viewModel.currentState.groupDescription, '暂无描述');
      expect(viewModel.groupId, 'g1');
    });

    test('updateGroupName 成功时更新状态并调用仓库', () async {
      final repository = FakeGroupRepository();
      final viewModel = buildViewModel(repository);

      final ok = await viewModel.updateGroupName('新群名');

      expect(ok, isTrue);
      expect(repository.groupNameUpdates, ['新群名']);
      expect(viewModel.currentState.groupName, '新群名');
    });

    test('updateGroupName 失败时写入错误', () async {
      final viewModel = buildViewModel(FakeGroupRepository(shouldFail: true));

      final ok = await viewModel.updateGroupName('新群名');

      expect(ok, isFalse);
      expect(viewModel.currentState.error, contains('群名称更新失败'));
    });

    test('updateGroupDescription 成功时更新状态', () async {
      final repository = FakeGroupRepository();
      final viewModel = buildViewModel(repository);

      final ok = await viewModel.updateGroupDescription('新描述');

      expect(ok, isTrue);
      expect(repository.descriptionUpdates, ['新描述']);
      expect(viewModel.currentState.groupDescription, '新描述');
    });

    test('updateGroupAvatar 成功时调用仓库', () async {
      final repository = FakeGroupRepository();
      final viewModel = buildViewModel(repository);

      final ok = await viewModel.updateGroupAvatar(
        'http://example.com/new.png',
      );

      expect(ok, isTrue);
      expect(repository.avatarUpdates, ['http://example.com/new.png']);
    });

    test('kickMember 成功时转发给群成员仓库', () async {
      final repository = FakeGroupRepository();
      final viewModel = buildViewModel(repository);

      final ok = await viewModel.kickMember('u2');

      expect(ok, isTrue);
      expect(repository.kickedUserIds, ['u2']);
    });
  });
}
