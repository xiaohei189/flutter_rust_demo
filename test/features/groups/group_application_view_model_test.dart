import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_rust_demo/domain/models/group_application.dart';
import 'package:flutter_rust_demo/providers/group_provider.dart';
import 'package:flutter_rust_demo/ui/groups/view_models/group_application_view_model.dart';
import 'fake_group_repository.dart';

class FakeGroupRepository extends BaseFakeGroupRepository {
  FakeGroupRepository({
    this.received = const [],
    this.sent = const [],
    this.shouldFail = false,
  });

  final List<GroupApplication> received;
  final List<GroupApplication> sent;
  final bool shouldFail;
  int loadCount = 0;

  @override
  Future<({List<GroupApplication> received, List<GroupApplication> sent})>
  loadApplications() async {
    loadCount++;
    if (shouldFail) {
      throw Exception('加载失败');
    }
    return (received: received, sent: sent);
  }

  @override
  Future<void> acceptGroupApplication({
    required String groupId,
    required String userId,
    String? handleMsg,
  }) async {
    if (shouldFail) {
      throw Exception('接受失败');
    }
  }

  @override
  Future<void> refuseGroupApplication({
    required String groupId,
    required String userId,
    String? handleMsg,
  }) async {
    if (shouldFail) {
      throw Exception('拒绝失败');
    }
  }
}

const _application = GroupApplication(
  groupId: 'g1',
  userId: 'u1',
  nickname: '张三',
  faceUrl: '',
  reason: '想加入',
  handleResult: 0,
);

void main() {
  GroupApplicationViewModel buildViewModel(
    FakeGroupRepository repository,
  ) {
    final container = ProviderContainer(
      overrides: [groupRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    return container.read(groupApplicationProvider.notifier);
  }

  group('GroupApplicationViewModel', () {
    test('loadApplications 成功时更新收到和发出列表', () async {
      final repository = FakeGroupRepository(
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
      final repository = FakeGroupRepository(shouldFail: true);
      final viewModel = buildViewModel(repository);

      await viewModel.loadApplications();

      expect(viewModel.state.error, contains('加载群申请列表失败'));
    });

    test('acceptApplication 成功后重新加载列表', () async {
      final repository = FakeGroupRepository(received: [_application]);
      final viewModel = buildViewModel(repository);

      await viewModel.loadApplications();
      final ok = await viewModel.acceptApplication(
        groupId: _application.groupId,
        userId: _application.userId,
      );

      expect(ok, isTrue);
      expect(repository.loadCount, 2);
    });
  });
}
