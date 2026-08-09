import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_rust_demo/data/repositories/friend_repository.dart';
import 'package:flutter_rust_demo/domain/models/friend.dart';
import 'package:flutter_rust_demo/ui/features/contacts/view_models/friend_list_view_model.dart';

class FakeFriendRepository implements FriendRepository {
  FakeFriendRepository({List<Friend>? friends, this.shouldFail = false})
    : friends = friends ?? [];

  List<Friend> friends;
  final bool shouldFail;
  final List<String> deletedUserIds = [];
  int loadCount = 0;

  @override
  Future<List<Friend>> loadFriends() async {
    loadCount++;
    if (shouldFail) {
      throw Exception('加载失败');
    }
    return List.of(friends);
  }

  @override
  Future<List<Friend>> searchFriends(String keyword) async {
    if (keyword.trim().isEmpty) {
      return loadFriends();
    }
    if (shouldFail) {
      throw Exception('搜索失败');
    }
    final kw = keyword.toLowerCase();
    return friends.where((f) => f.nickname.toLowerCase().contains(kw)).toList();
  }

  @override
  Future<void> deleteFriend(String userId) async {
    if (shouldFail) {
      throw Exception('删除失败');
    }
    deletedUserIds.add(userId);
  }

  @override
  Future<void> updateFriends(String userId, {String? remark}) async {
    if (shouldFail) {
      throw Exception('更新失败');
    }
  }

  @override
  Future<bool> isFriend(String userId) async => true;
}

const _friendA = Friend(
  userId: 'u1',
  nickname: '张三',
  faceUrl: '',
  gender: 1,
  remark: '阿三',
  addSource: '',
  ex: '',
);

const _friendB = Friend(
  userId: 'u2',
  nickname: '李四',
  faceUrl: '',
  gender: 2,
  remark: '',
  addSource: '',
  ex: '',
);

void main() {
  group('FriendListViewModel', () {
    test('loadFriends 成功时更新列表并结束加载', () async {
      final repository = FakeFriendRepository(friends: [_friendA, _friendB]);
      final viewModel = FriendListViewModel(repository: repository);

      await viewModel.loadFriends();

      expect(viewModel.state.isLoading, isFalse);
      expect(viewModel.state.error, isNull);
      expect(viewModel.state.friends, hasLength(2));
      expect(viewModel.state.friendCount, 2);
    });

    test('loadFriends 失败时写入中文错误', () async {
      final repository = FakeFriendRepository(shouldFail: true);
      final viewModel = FriendListViewModel(repository: repository);

      await viewModel.loadFriends();

      expect(viewModel.state.isLoading, isFalse);
      expect(viewModel.state.error, contains('加载好友列表失败'));
    });

    test('searchFriends 空关键字时重新加载完整列表', () async {
      final repository = FakeFriendRepository(friends: [_friendA, _friendB]);
      final viewModel = FriendListViewModel(repository: repository);

      await viewModel.loadFriends();
      await viewModel.searchFriends('  ');

      expect(repository.loadCount, 2);
      expect(viewModel.state.friends, hasLength(2));
    });

    test('deleteFriend 成功后重新加载列表', () async {
      final repository = FakeFriendRepository(friends: [_friendA, _friendB]);
      final viewModel = FriendListViewModel(repository: repository);

      await viewModel.loadFriends();
      final ok = await viewModel.deleteFriend(_friendA.userId);

      expect(ok, isTrue);
      expect(repository.deletedUserIds, [_friendA.userId]);
      expect(repository.loadCount, 2);
      expect(viewModel.state.friends, hasLength(2));
    });

    test('deleteFriend 失败时返回 false 并写入错误', () async {
      final repository = FakeFriendRepository(shouldFail: true);
      final viewModel = FriendListViewModel(repository: repository);

      final ok = await viewModel.deleteFriend(_friendA.userId);

      expect(ok, isFalse);
      expect(viewModel.state.error, contains('删除好友失败'));
    });
  });
}
