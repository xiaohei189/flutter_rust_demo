import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_rust_demo/data/repositories/message_repository.dart';
import 'package:flutter_rust_demo/domain/models/conversation.dart';
import 'package:flutter_rust_demo/domain/models/group.dart';
import 'package:flutter_rust_demo/domain/models/group_member.dart';
import 'package:flutter_rust_demo/domain/models/user_profile.dart';
import 'package:flutter_rust_demo/providers/current_user_provider.dart';
import 'package:flutter_rust_demo/ui/chat/providers/chat_settings_provider.dart';
import 'package:flutter_rust_demo/ui/chat/providers/conversation_provider.dart';
import 'package:flutter_rust_demo/ui/chat/providers/message_service_provider.dart';
import 'package:flutter_rust_demo/ui/chat/view_models/chat_settings_view_model.dart';
import 'package:flutter_rust_demo/ui/chat/view_models/conversation_view_model.dart';
import 'package:flutter_rust_demo/ui/groups/providers/group_provider.dart';
import 'package:flutter_rust_demo/ui/profile/providers/user_profile_provider.dart';
import 'package:flutter_rust_demo/ui/profile/view_models/user_profile_view_model.dart';

import '../../support/fakes/fake_group_repository.dart';

class FakeMessageRepository implements MessageRepository {
  FakeMessageRepository({this.shouldFail = false});

  bool shouldFail;
  final List<int> recvMsgOptCalls = [];
  final List<bool> pinCalls = [];
  final List<bool> privateCalls = [];
  int clearCount = 0;

  @override
  Future<void> setConversation({
    required String conversationId,
    int? recvMsgOpt,
    String? ex,
  }) async {
    if (shouldFail) throw Exception('设置失败');
    if (recvMsgOpt != null) recvMsgOptCalls.add(recvMsgOpt);
  }

  @override
  Future<void> setConversationPinned({
    required String conversationId,
    required bool isPinned,
  }) async {
    if (shouldFail) throw Exception('设置失败');
    pinCalls.add(isPinned);
  }

  @override
  Future<void> setConversationPrivate({
    required String conversationId,
    required bool isPrivate,
  }) async {
    if (shouldFail) throw Exception('设置失败');
    privateCalls.add(isPrivate);
  }

  @override
  Future<void> clearConversationAndDeleteAllMsg(String conversationId) async {
    if (shouldFail) throw Exception('清空失败');
    clearCount++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

class FakeGroupRepository extends BaseFakeGroupRepository {
  FakeGroupRepository({this.shouldFail = false});

  bool shouldFail;
  final List<String> quitGroupIds = [];
  final List<String> memberInfoGroupIds = [];
  final List<String> memberInfoUserIds = [];
  final List<String> setInfoGroupIds = [];
  final List<String> invitedGroupIds = [];
  final List<List<String>> invitedMemberIds = [];
  String notification = '群公告';

  @override
  Future<List<GroupMember>> loadMembers(String groupId) async => const [];

  @override
  Future<void> quitGroup(String groupId) async {
    if (shouldFail) throw Exception('退出失败');
    quitGroupIds.add(groupId);
  }

  @override
  Future<void> setGroupMemberInfo(
    String groupId,
    String userId, {
    String? nickname,
    String? faceUrl,
    int? roleLevel,
    String? ex,
  }) async {
    if (shouldFail) throw Exception('更新失败');
    memberInfoGroupIds.add(groupId);
    memberInfoUserIds.add(userId);
  }

  @override
  Future<List<Group>> getGroupsInfo(List<String> groupIds) async {
    if (shouldFail) throw Exception('获取公告失败');
    return [
      Group(
        groupId: groupIds.first,
        groupName: '测试群',
        faceUrl: '',
        introduction: '',
        notification: notification,
        ownerUserId: 'u1',
        memberCount: 3,
        status: 0,
      ),
    ];
  }

  @override
  Future<void> setGroupInfo(
    String groupId, {
    String? groupName,
    String? faceUrl,
    String? introduction,
    String? notification,
  }) async {
    if (shouldFail) throw Exception('更新公告失败');
    setInfoGroupIds.add(groupId);
    this.notification = notification ?? this.notification;
  }

  @override
  Future<void> inviteMembers(String groupId, List<String> memberIds) async {
    if (shouldFail) throw Exception('邀请失败');
    invitedGroupIds.add(groupId);
    invitedMemberIds.add(List.of(memberIds));
  }
}

class FakeUserProfileNotifier extends UserProfileNotifier {
  FakeUserProfileNotifier(this.profile);

  final UserProfile profile;

  @override
  UserProfileLocalState build() => const UserProfileLocalState();
}

class FakeCurrentUserNotifier extends CurrentUserNotifier {
  @override
  String build() => 'u1';
}

class FakeConversationListNotifier extends ConversationListNotifier {
  FakeConversationListNotifier(this.conversation);

  final Conversation conversation;

  @override
  ConversationListState build() =>
      ConversationListState(conversations: [conversation]);
}

Conversation _makeConversation({
  bool group = false,
  String groupId = '',
  int recvMsgOpt = 0,
  bool isPinned = false,
  bool isPrivateChat = false,
}) {
  return Conversation(
    conversationId: 'conv1',
    conversationType: group ? 2 : 1,
    userId: group ? '' : 'u2',
    groupId: groupId,
    showName: group ? '测试群' : '张三',
    faceUrl: '',
    latestMsg: '',
    latestMsgSendTime: 0,
    unreadCount: 0,
    recvMsgOpt: recvMsgOpt,
    isPinned: isPinned,
    isPrivateChat: isPrivateChat,
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
}

ChatSettingsViewModel buildViewModel({
  FakeMessageRepository? messageRepository,
  FakeGroupRepository? groupRepository,
  UserProfile? profile,
  Conversation? conversation,
}) {
  final overrides = [
    currentUserIdProvider.overrideWith(() => FakeCurrentUserNotifier()),
    messageRepositoryProvider.overrideWithValue(
      messageRepository ?? FakeMessageRepository(),
    ),
    groupRepositoryProvider.overrideWithValue(
      groupRepository ?? FakeGroupRepository(),
    ),
    if (profile != null)
      userProfileProvider.overrideWith(() => FakeUserProfileNotifier(profile)),
    if (conversation != null)
      conversationListProvider.overrideWith(
        () => FakeConversationListNotifier(conversation),
      ),
  ];
  final container = ProviderContainer(overrides: overrides);
  addTearDown(container.dispose);
  return container.read(chatSettingsViewModelProvider('conv1').notifier);
}

const _profile = UserProfile(
  userId: 'u1',
  nickname: '我',
  faceUrl: '',
  gender: 1,
  telephone: '',
  email: '',
  remark: '',
  globalRecvMsgOpt: 0,
);

void main() {
  group('ChatSettingsViewModel', () {
    test('initialize 写入会话开关状态', () {
      final viewModel = buildViewModel(
        conversation: _makeConversation(
          recvMsgOpt: 1,
          isPinned: true,
          isPrivateChat: true,
        ),
      );

      viewModel.initialize(
        _makeConversation(recvMsgOpt: 1, isPinned: true, isPrivateChat: true),
      );

      expect(viewModel.state.initialized, isTrue);
      expect(viewModel.state.muteNotification, isTrue);
      expect(viewModel.state.pinChat, isTrue);
      expect(viewModel.state.privateChat, isTrue);
    });

    test('setMuteNotification 成功时调用仓库并保持状态', () async {
      final repository = FakeMessageRepository();
      final viewModel = buildViewModel(messageRepository: repository);

      await viewModel.setMuteNotification(true);

      expect(repository.recvMsgOptCalls, [1]);
      expect(viewModel.state.muteNotification, isTrue);
      expect(viewModel.state.error, isNull);
    });

    test('setMuteNotification 失败时写入错误', () async {
      final viewModel = buildViewModel(
        messageRepository: FakeMessageRepository(shouldFail: true),
      );

      await viewModel.setMuteNotification(true);

      expect(viewModel.state.error, contains('设置失败'));
    });

    test('setPinChat 成功时调用仓库并保持状态', () async {
      final repository = FakeMessageRepository();
      final viewModel = buildViewModel(messageRepository: repository);

      await viewModel.setPinChat(true);

      expect(repository.pinCalls, [true]);
      expect(viewModel.state.pinChat, isTrue);
      expect(viewModel.state.error, isNull);
    });

    test('setPinChat 失败时写入错误', () async {
      final viewModel = buildViewModel(
        messageRepository: FakeMessageRepository(shouldFail: true),
      );

      await viewModel.setPinChat(true);

      expect(viewModel.state.error, contains('设置失败'));
    });

    test('setPrivateChat 成功时调用仓库并保持状态', () async {
      final repository = FakeMessageRepository();
      final viewModel = buildViewModel(messageRepository: repository);

      await viewModel.setPrivateChat(true);

      expect(repository.privateCalls, [true]);
      expect(viewModel.state.privateChat, isTrue);
      expect(viewModel.state.error, isNull);
    });

    test('setPrivateChat 失败时写入错误', () async {
      final viewModel = buildViewModel(
        messageRepository: FakeMessageRepository(shouldFail: true),
      );

      await viewModel.setPrivateChat(true);

      expect(viewModel.state.error, contains('设置失败'));
    });

    test('quitGroup 成功时使用会话的群组 ID', () async {
      final repository = FakeGroupRepository();
      final viewModel = buildViewModel(
        groupRepository: repository,
        conversation: _makeConversation(group: true, groupId: 'g1'),
      );

      final ok = await viewModel.quitGroup();

      expect(ok, isTrue);
      expect(repository.quitGroupIds, ['g1']);
    });

    test('quitGroup 失败时返回 false 并写入错误', () async {
      final viewModel = buildViewModel(
        groupRepository: FakeGroupRepository(shouldFail: true),
      );

      final ok = await viewModel.quitGroup();

      expect(ok, isFalse);
      expect(viewModel.state.error, contains('退出群组失败'));
    });

    test('clearHistory 成功时清空会话记录', () async {
      final repository = FakeMessageRepository();
      final viewModel = buildViewModel(messageRepository: repository);

      final ok = await viewModel.clearHistory();

      expect(ok, isTrue);
      expect(repository.clearCount, 1);
    });

    test('clearHistory 失败时返回 false 并写入错误', () async {
      final viewModel = buildViewModel(
        messageRepository: FakeMessageRepository(shouldFail: true),
      );

      final ok = await viewModel.clearHistory();

      expect(ok, isFalse);
      expect(viewModel.state.error, contains('清空聊天记录失败'));
    });

    test('updateGroupNickname 使用群组 ID 与当前用户 ID', () async {
      final repository = FakeGroupRepository();
      final viewModel = buildViewModel(
        groupRepository: repository,
        profile: _profile,
        conversation: _makeConversation(group: true, groupId: 'g1'),
      );

      final ok = await viewModel.updateGroupNickname('新昵称');

      expect(ok, isTrue);
      expect(repository.memberInfoGroupIds, ['g1']);
      expect(repository.memberInfoUserIds, ['u1']);
    });

    test('currentGroupAnnouncement 返回群公告', () async {
      final repository = FakeGroupRepository();
      final viewModel = buildViewModel(
        groupRepository: repository,
        conversation: _makeConversation(group: true, groupId: 'g1'),
      );

      final current = await viewModel.currentGroupAnnouncement();

      expect(current, '群公告');
    });

    test('updateGroupAnnouncement 使用群组 ID', () async {
      final repository = FakeGroupRepository();
      final viewModel = buildViewModel(
        groupRepository: repository,
        conversation: _makeConversation(group: true, groupId: 'g1'),
      );

      final ok = await viewModel.updateGroupAnnouncement('新公告');

      expect(ok, isTrue);
      expect(repository.setInfoGroupIds, ['g1']);
      expect(repository.notification, '新公告');
    });

    test('inviteMembers 成功时转发给群成员仓库', () async {
      final repository = FakeGroupRepository();
      final viewModel = buildViewModel(
        groupRepository: repository,
        conversation: _makeConversation(group: true, groupId: 'g1'),
      );

      final ok = await viewModel.inviteMembers(['u2', 'u3']);

      expect(ok, isTrue);
      expect(repository.invitedGroupIds, ['g1']);
      expect(repository.invitedMemberIds, [
        ['u2', 'u3'],
      ]);
    });

    test('inviteMembers 失败时返回 false 并写入错误', () async {
      final viewModel = buildViewModel(
        groupRepository: FakeGroupRepository(shouldFail: true),
      );

      final ok = await viewModel.inviteMembers(['u2']);

      expect(ok, isFalse);
      expect(viewModel.state.error, contains('邀请成员失败'));
    });
  });
}
