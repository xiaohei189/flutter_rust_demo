import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_rust_demo/domain/models/group.dart';
import 'package:flutter_rust_demo/ui/groups/providers/group_provider.dart';
import 'package:flutter_rust_demo/ui/groups/view_models/create_group_view_model.dart';
import '../../support/fakes/fake_group_repository.dart';

class FakeGroupRepository extends BaseFakeGroupRepository {
  FakeGroupRepository({this.shouldFail = false});

  final bool shouldFail;

  @override
  Future<Group> createGroup({
    required String groupName,
    required int groupType,
    required List<String> memberIds,
  }) async {
    if (shouldFail) {
      throw Exception('创建失败');
    }
    return Group(
      groupId: 'new_group',
      groupName: groupName,
      faceUrl: '',
      introduction: '',
      notification: '',
      ownerUserId: 'u1',
      memberCount: memberIds.length + 1,
      status: 0,
    );
  }
}

void main() {
  CreateGroupViewModel buildViewModel(FakeGroupRepository repository) {
    final container = ProviderContainer(
      overrides: [groupRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    return container.read(createGroupProvider.notifier);
  }

  group('CreateGroupViewModel', () {
    test('createGroup 成功时返回创建的群组', () async {
      final repository = FakeGroupRepository();
      final viewModel = buildViewModel(repository);
      viewModel.addSelectedMember('u2');

      final group = await viewModel.createGroup(groupName: '新群', groupType: 2);

      expect(group, isNotNull);
      expect(group!.groupId, 'new_group');
      expect(viewModel.state.isCreating, isFalse);
      expect(viewModel.state.selectedMemberIds, isEmpty);
    });

    test('没有选择成员时返回 null 并写入错误', () async {
      final repository = FakeGroupRepository();
      final viewModel = buildViewModel(repository);

      final group = await viewModel.createGroup(groupName: '新群', groupType: 2);

      expect(group, isNull);
      expect(viewModel.state.error, contains('请至少选择一名成员'));
    });

    test('createGroup 失败时返回 null 并写入中文错误', () async {
      final repository = FakeGroupRepository(shouldFail: true);
      final viewModel = buildViewModel(repository);
      viewModel.addSelectedMember('u2');

      final group = await viewModel.createGroup(groupName: '新群', groupType: 2);

      expect(group, isNull);
      expect(viewModel.state.error, contains('创建群组失败'));
    });
  });
}
