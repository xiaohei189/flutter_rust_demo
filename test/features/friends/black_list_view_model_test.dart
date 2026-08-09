import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_rust_demo/data/repositories/blacklist_repository.dart';
import 'package:flutter_rust_demo/domain/models/blacklist_user.dart';
import 'package:flutter_rust_demo/ui/features/contacts/view_models/black_list_view_model.dart';

class FakeBlacklistRepository implements BlacklistRepository {
  FakeBlacklistRepository({this.users = const [], this.shouldFail = false});

  final List<BlacklistUser> users;
  final bool shouldFail;
  final List<String> removedUserIds = [];
  int loadCount = 0;

  @override
  Future<List<BlacklistUser>> load() async {
    loadCount++;
    if (shouldFail) {
      throw Exception('加载失败');
    }
    return users;
  }

  @override
  Future<void> add(String userId) async {
    if (shouldFail) {
      throw Exception('加入失败');
    }
  }

  @override
  Future<void> remove(String userId) async {
    if (shouldFail) {
      throw Exception('移出失败');
    }
    removedUserIds.add(userId);
  }
}

const _user = BlacklistUser(userId: 'u1', nickname: '张三', faceUrl: '');

void main() {
  group('BlackListViewModel', () {
    test('load 成功时更新黑名单用户', () async {
      final repository = FakeBlacklistRepository(users: [_user]);
      final viewModel = BlackListViewModel(repository: repository);

      await viewModel.load();

      expect(viewModel.state.isLoading, isFalse);
      expect(viewModel.state.error, isNull);
      expect(viewModel.state.users, hasLength(1));
      expect(viewModel.state.count, 1);
    });

    test('load 失败时写入中文错误', () async {
      final repository = FakeBlacklistRepository(shouldFail: true);
      final viewModel = BlackListViewModel(repository: repository);

      await viewModel.load();

      expect(viewModel.state.isLoading, isFalse);
      expect(viewModel.state.error, contains('加载黑名单失败'));
    });

    test('remove 成功后重新加载列表', () async {
      final repository = FakeBlacklistRepository(users: [_user]);
      final viewModel = BlackListViewModel(repository: repository);

      await viewModel.load();
      final ok = await viewModel.remove(_user.userId);

      expect(ok, isTrue);
      expect(repository.removedUserIds, [_user.userId]);
      expect(repository.loadCount, 2);
    });

    test('remove 失败时返回 false 并写入错误', () async {
      final repository = FakeBlacklistRepository(shouldFail: true);
      final viewModel = BlackListViewModel(repository: repository);

      final ok = await viewModel.remove(_user.userId);

      expect(ok, isFalse);
      expect(viewModel.state.error, contains('移出黑名单失败'));
    });
  });
}
