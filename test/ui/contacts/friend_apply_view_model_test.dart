import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_rust_demo/data/repositories/friend_application_repository.dart';
import 'package:flutter_rust_demo/domain/models/friend_application.dart';
import 'package:flutter_rust_demo/ui/contacts/providers/friend_provider.dart';
import 'package:flutter_rust_demo/ui/contacts/view_models/friend_apply_view_model.dart';

class FakeFriendApplicationRepository implements FriendApplicationRepository {
  FakeFriendApplicationRepository({
    this.received = const [],
    this.sent = const [],
    this.shouldFail = false,
  });

  final List<FriendApplication> received;
  final List<FriendApplication> sent;
  final bool shouldFail;
  final List<String> acceptedUserIds = [];
  final List<String> refusedUserIds = [];
  int loadCount = 0;

  @override
  Future<({List<FriendApplication> received, List<FriendApplication> sent})>
  loadApplications() async {
    loadCount++;
    if (shouldFail) {
      throw Exception('加载失败');
    }
    return (received: received, sent: sent);
  }

  @override
  Future<void> accept(String userId, {String? handleMsg}) async {
    if (shouldFail) {
      throw Exception('接受失败');
    }
    acceptedUserIds.add(userId);
  }

  @override
  Future<void> refuse(String userId, {String? handleMsg}) async {
    if (shouldFail) {
      throw Exception('拒绝失败');
    }
    refusedUserIds.add(userId);
  }
}

const _application = FriendApplication(
  userId: 'u1',
  nickname: '张三',
  faceUrl: '',
  gender: 1,
  addSource: 1,
  ex: '',
  handleResult: 0,
  reqMsg: '你好',
);

FriendApplyViewModel buildViewModel(
  FakeFriendApplicationRepository repository,
) {
  final container = ProviderContainer(
    overrides: [
      friendApplicationRepositoryProvider.overrideWithValue(repository),
    ],
  );
  addTearDown(container.dispose);
  return container.read(friendApplyProvider.notifier);
}

void main() {
  group('FriendApplyViewModel', () {
    test('loadApplications 成功时更新收到和发出列表', () async {
      final repository = FakeFriendApplicationRepository(
        received: [_application],
        sent: [_application],
      );
      final viewModel = buildViewModel(repository);

      await viewModel.loadApplications();

      expect(viewModel.state.isLoading, isFalse);
      expect(viewModel.state.error, isNull);
      expect(viewModel.state.received, hasLength(1));
      expect(viewModel.state.sent, hasLength(1));
      expect(viewModel.state.unhandledCount, 1);
    });

    test('loadApplications 失败时写入中文错误', () async {
      final repository = FakeFriendApplicationRepository(shouldFail: true);
      final viewModel = buildViewModel(repository);

      await viewModel.loadApplications();

      expect(viewModel.state.isLoading, isFalse);
      expect(viewModel.state.error, contains('加载好友申请失败'));
    });

    test('acceptApplication 成功后重新加载列表', () async {
      final repository = FakeFriendApplicationRepository(
        received: [_application],
      );
      final viewModel = buildViewModel(repository);

      await viewModel.loadApplications();
      final ok = await viewModel.acceptApplication(_application.userId);

      expect(ok, isTrue);
      expect(repository.acceptedUserIds, [_application.userId]);
      expect(repository.loadCount, 3);
    });

    test('refuseApplication 失败时返回 false 并写入错误', () async {
      final repository = FakeFriendApplicationRepository(shouldFail: true);
      final viewModel = buildViewModel(repository);

      final ok = await viewModel.refuseApplication(_application.userId);

      expect(ok, isFalse);
      expect(viewModel.state.error, contains('拒绝好友申请失败'));
    });
  });
}
