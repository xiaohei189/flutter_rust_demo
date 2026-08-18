import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_rust_demo/data/repositories/blacklist_repository.dart';
import 'package:flutter_rust_demo/data/repositories/friend_repository.dart';
import 'package:flutter_rust_demo/data/repositories/message_repository.dart';
import 'package:flutter_rust_demo/domain/models/blacklist_user.dart';
import 'package:flutter_rust_demo/domain/models/conversation.dart';
import 'package:flutter_rust_demo/domain/models/friend.dart';
import 'package:flutter_rust_demo/generated/rust/constant/enums.dart'
    show SessionType;
import 'package:flutter_rust_demo/ui/chat/providers/conversation_provider.dart';
import 'package:flutter_rust_demo/ui/chat/providers/message_service_provider.dart';
import 'package:flutter_rust_demo/ui/chat/view_models/conversation_view_model.dart';
import 'package:flutter_rust_demo/ui/contacts/providers/friend_provider.dart';
import 'package:flutter_rust_demo/ui/contacts/providers/friend_setup_provider.dart';
import 'package:flutter_rust_demo/ui/contacts/view_models/friend_setup_view_model.dart';

class FakeMessageRepository implements MessageRepository {
  FakeMessageRepository({this.shouldFail = false, this.blacklisted = false});

  bool shouldFail;
  bool blacklisted;
  final List<int> muteCalls = [];
  final List<bool> pinCalls = [];

  @override
  Future<String> getConversationIdBySessionType({
    required String sourceId,
    required SessionType sessionType,
  }) async {
    if (shouldFail) throw Exception('加载失败');
    return 'si_$sourceId';
  }

  @override
  Future<bool> isInBlacklist(String userId) async {
    if (shouldFail) throw Exception('加载失败');
    return blacklisted;
  }

  @override
  Future<void> setConversation({
    required String conversationId,
    int? recvMsgOpt,
    String? ex,
  }) async {
    if (shouldFail) throw Exception('设置失败');
    if (recvMsgOpt != null) muteCalls.add(recvMsgOpt);
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
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

class FakeFriendRepository implements FriendRepository {
  FakeFriendRepository({this.shouldFail = false});

  bool shouldFail;
  final List<String> updatedUserIds = [];
  final List<String> updatedRemarks = [];
  final List<String> deletedUserIds = [];

  @override
  Future<List<Friend>> loadFriends() async => const [];

  @override
  Future<List<Friend>> searchFriends(String keyword) async => const [];

  @override
  Future<void> deleteFriend(String userId) async {
    if (shouldFail) throw Exception('删除失败');
    deletedUserIds.add(userId);
  }

  @override
  Future<void> updateFriends(String userId, {String? remark}) async {
    if (shouldFail) throw Exception('更新失败');
    updatedUserIds.add(userId);
    updatedRemarks.add(remark ?? '');
  }

  @override
  Future<bool> isFriend(String userId) async => true;
}

class FakeBlacklistRepository implements BlacklistRepository {
  FakeBlacklistRepository({this.shouldFail = false});

  bool shouldFail;
  final List<String> addedUserIds = [];
  final List<String> removedUserIds = [];

  @override
  Future<List<BlacklistUser>> load() async => const [];

  @override
  Future<void> add(String userId) async {
    if (shouldFail) throw Exception('加入失败');
    addedUserIds.add(userId);
  }

  @override
  Future<void> remove(String userId) async {
    if (shouldFail) throw Exception('移出失败');
    removedUserIds.add(userId);
  }
}

class FakeConversationListNotifier extends ConversationListNotifier {
  FakeConversationListNotifier(this.conversation);

  final Conversation conversation;

  @override
  ConversationListState build() =>
      ConversationListState(conversations: [conversation]);
}

Conversation _makeConversation({int recvMsgOpt = 0, bool isPinned = false}) {
  return Conversation(
    conversationId: 'si_u2',
    conversationType: 1,
    userId: 'u2',
    groupId: '',
    showName: '张三',
    faceUrl: '',
    latestMsg: '',
    latestMsgSendTime: 0,
    unreadCount: 0,
    recvMsgOpt: recvMsgOpt,
    isPinned: isPinned,
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
}

FriendSetupViewModel buildViewModel({
  FakeMessageRepository? messageRepository,
  FakeFriendRepository? friendRepository,
  FakeBlacklistRepository? blacklistRepository,
  Conversation? conversation,
}) {
  final container = ProviderContainer(
    overrides: [
      messageRepositoryProvider.overrideWithValue(
        messageRepository ?? FakeMessageRepository(),
      ),
      friendRepositoryProvider.overrideWithValue(
        friendRepository ?? FakeFriendRepository(),
      ),
      blackListRepositoryProvider.overrideWithValue(
        blacklistRepository ?? FakeBlacklistRepository(),
      ),
      if (conversation != null)
        conversationListProvider.overrideWith(
          () => FakeConversationListNotifier(conversation),
        ),
    ],
  );
  addTearDown(container.dispose);
  return container.read(friendSetupViewModelProvider('u2').notifier);
}

void main() {
  group('FriendSetupViewModel', () {
    test('load 读取会话设置与黑名单状态', () async {
      final messageRepository = FakeMessageRepository(blacklisted: true);
      final viewModel = buildViewModel(
        messageRepository: messageRepository,
        conversation: _makeConversation(recvMsgOpt: 1, isPinned: true),
      );

      await viewModel.load();

      expect(viewModel.currentState.conversationId, 'si_u2');
      expect(viewModel.currentState.isMuted, isTrue);
      expect(viewModel.currentState.isPinned, isTrue);
      expect(viewModel.currentState.isBlacklisted, isTrue);
    });

    test('updateRemark 成功时调用好友仓库', () async {
      final repository = FakeFriendRepository();
      final viewModel = buildViewModel(friendRepository: repository);

      final ok = await viewModel.updateRemark('新备注');

      expect(ok, isTrue);
      expect(repository.updatedUserIds, ['u2']);
      expect(repository.updatedRemarks, ['新备注']);
    });

    test('setMuted 成功时调用消息仓库', () async {
      final repository = FakeMessageRepository();
      final viewModel = buildViewModel(messageRepository: repository);
      await viewModel.load();

      final ok = await viewModel.setMuted(true);

      expect(ok, isTrue);
      expect(repository.muteCalls, [1]);
      expect(viewModel.currentState.isMuted, isTrue);
    });

    test('setPinned 成功时调用消息仓库', () async {
      final repository = FakeMessageRepository();
      final viewModel = buildViewModel(messageRepository: repository);
      await viewModel.load();

      final ok = await viewModel.setPinned(true);

      expect(ok, isTrue);
      expect(repository.pinCalls, [true]);
      expect(viewModel.currentState.isPinned, isTrue);
    });

    test('setBlacklisted 成功时加入黑名单', () async {
      final repository = FakeBlacklistRepository();
      final viewModel = buildViewModel(blacklistRepository: repository);

      final ok = await viewModel.setBlacklisted(true);

      expect(ok, isTrue);
      expect(repository.addedUserIds, ['u2']);
      expect(viewModel.currentState.isBlacklisted, isTrue);
    });

    test('deleteFriend 成功时删除好友', () async {
      final repository = FakeFriendRepository();
      final viewModel = buildViewModel(friendRepository: repository);

      final ok = await viewModel.deleteFriend();

      expect(ok, isTrue);
      expect(repository.deletedUserIds, ['u2']);
    });
  });
}
