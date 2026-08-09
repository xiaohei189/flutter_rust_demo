import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_rust_demo/data/repositories/friend_search_repository.dart';
import 'package:flutter_rust_demo/domain/models/friend_search_result.dart';
import 'package:flutter_rust_demo/ui/features/contacts/view_models/friend_search_view_model.dart';

class FakeFriendSearchRepository implements FriendSearchRepository {
  FakeFriendSearchRepository({
    this.results = const [],
    this.shouldFail = false,
  });

  final List<FriendSearchResult> results;
  final bool shouldFail;
  final List<String> requestedUserIds = [];

  @override
  Future<List<FriendSearchResult>> search(String keyword) async {
    if (keyword.trim().isEmpty) {
      return const [];
    }
    if (shouldFail) {
      throw Exception('搜索失败');
    }
    return results;
  }

  @override
  Future<void> sendFriendRequest(String userId, String reqMsg) async {
    if (shouldFail) {
      throw Exception('发送失败');
    }
    requestedUserIds.add(userId);
  }
}

const _result = FriendSearchResult(
  userId: 'u1',
  nickname: '张三',
  faceUrl: '',
  remark: '备注',
  ex: '',
  relationship: 0,
);

void main() {
  group('FriendSearchViewModel', () {
    test('search 成功时更新结果并结束加载', () async {
      final repository = FakeFriendSearchRepository(results: [_result]);
      final viewModel = FriendSearchViewModel(repository: repository);

      await viewModel.search('张');

      expect(viewModel.state.isLoading, isFalse);
      expect(viewModel.state.error, isNull);
      expect(viewModel.state.results, hasLength(1));
    });

    test('空关键字时清空结果', () async {
      final repository = FakeFriendSearchRepository(results: [_result]);
      final viewModel = FriendSearchViewModel(repository: repository);

      await viewModel.search('   ');

      expect(viewModel.state.results, isEmpty);
    });

    test('search 失败时写入中文错误', () async {
      final repository = FakeFriendSearchRepository(shouldFail: true);
      final viewModel = FriendSearchViewModel(repository: repository);

      await viewModel.search('张');

      expect(viewModel.state.error, contains('搜索好友失败'));
    });

    test('sendFriendRequest 成功时返回 true', () async {
      final repository = FakeFriendSearchRepository();
      final viewModel = FriendSearchViewModel(repository: repository);

      final ok = await viewModel.sendFriendRequest(_result.userId, '你好');

      expect(ok, isTrue);
      expect(repository.requestedUserIds, [_result.userId]);
    });
  });
}
