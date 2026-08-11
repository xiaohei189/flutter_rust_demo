import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_rust_demo/domain/models/group.dart';
import 'package:flutter_rust_demo/ui/groups/providers/group_provider.dart';
import 'package:flutter_rust_demo/ui/groups/view_models/group_list_view_model.dart';
import '../../support/fakes/fake_group_repository.dart';

class FakeGroupRepository extends BaseFakeGroupRepository {
  FakeGroupRepository({this.groups = const [], this.shouldFail = false});

  final List<Group> groups;
  final bool shouldFail;
  int loadCount = 0;
  int? lastOffset;

  @override
  Future<List<Group>> loadGroups({int offset = 0, int count = 50}) async {
    loadCount++;
    lastOffset = offset;
    if (shouldFail) {
      throw Exception('加载失败');
    }
    return groups;
  }
}

const _group = Group(
  groupId: 'g1',
  groupName: '测试群',
  faceUrl: '',
  introduction: '',
  notification: '',
  ownerUserId: 'u1',
  memberCount: 3,
  status: 0,
);

void main() {
  GroupListViewModel buildViewModel(FakeGroupRepository repository) {
    final container = ProviderContainer(
      overrides: [groupRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    return container.read(groupListProvider.notifier);
  }

  group('GroupListViewModel', () {
    test('loadGroups 成功时更新群组列表', () async {
      final repository = FakeGroupRepository(groups: [_group]);
      final viewModel = buildViewModel(repository);

      await viewModel.loadGroups();

      expect(viewModel.state.isLoading, isFalse);
      expect(viewModel.state.error, isNull);
      expect(viewModel.state.groups, hasLength(1));
      expect(repository.lastOffset, 0);
    });

    test('loadGroups 失败时写入中文错误', () async {
      final repository = FakeGroupRepository(shouldFail: true);
      final viewModel = buildViewModel(repository);

      await viewModel.loadGroups();

      expect(viewModel.state.isLoading, isFalse);
      expect(viewModel.state.error, contains('加载群组列表失败'));
    });

    test('loadMoreGroups 追加下一页结果', () async {
      final page = List.generate(
        50,
        (i) => Group(
          groupId: 'g$i',
          groupName: '群$i',
          faceUrl: '',
          introduction: '',
          notification: '',
          ownerUserId: 'u1',
          memberCount: 1,
          status: 0,
        ),
      );
      final repository = FakeGroupRepository(groups: page);
      final viewModel = buildViewModel(repository);

      await viewModel.loadGroups();
      await viewModel.loadMoreGroups();

      expect(repository.loadCount, 3);
      expect(repository.lastOffset, 50);
      expect(viewModel.state.groups, hasLength(100));
    });
  });
}
