import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_rust_demo/domain/models/group_member.dart';
import 'package:flutter_rust_demo/providers/group_provider.dart';
import 'package:flutter_rust_demo/ui/groups/view_models/group_member_view_model.dart';
import 'fake_group_repository.dart';

class FakeGroupRepository extends BaseFakeGroupRepository {
  FakeGroupRepository({this.members = const [], this.shouldFail = false});

  final List<GroupMember> members;
  final bool shouldFail;
  final List<String> kickedUserIds = [];
  final List<String> transferredUserIds = [];
  int loadCount = 0;

  @override
  Future<List<GroupMember>> loadMembers(String groupId) async {
    loadCount++;
    if (shouldFail) {
      throw Exception('加载失败');
    }
    return members;
  }

  @override
  Future<void> kickMembers(String groupId, List<String> memberIds) async {
    if (shouldFail) {
      throw Exception('踢出失败');
    }
    kickedUserIds.addAll(memberIds);
  }

  @override
  Future<void> transferOwner(String groupId, String newOwnerUserId) async {
    if (shouldFail) {
      throw Exception('转让失败');
    }
    transferredUserIds.add(newOwnerUserId);
  }
}

const _member = GroupMember(
  groupId: 'g1',
  userId: 'u1',
  nickname: '张三',
  faceUrl: '',
  roleLevel: 1,
  joinSource: '',
);

void main() {
  GroupMemberViewModel buildViewModel(
    FakeGroupRepository repository,
    String groupId,
  ) {
    final container = ProviderContainer(
      overrides: [groupRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    return container.read(groupMemberProvider(groupId).notifier);
  }

  group('GroupMemberViewModel', () {
    test('loadMembers 成功时更新成员列表', () async {
      final repository = FakeGroupRepository(members: [_member]);
      final viewModel = buildViewModel(repository, _member.groupId);

      await viewModel.loadMembers();

      expect(viewModel.state.isLoading, isFalse);
      expect(viewModel.state.error, isNull);
      expect(viewModel.state.members, hasLength(1));
    });

    test('loadMembers 失败时写入中文错误', () async {
      final repository = FakeGroupRepository(shouldFail: true);
      final viewModel = buildViewModel(repository, 'g1');

      await viewModel.loadMembers();

      expect(viewModel.state.error, contains('加载群成员失败'));
    });

    test('kickMembers 成功后重新加载成员列表', () async {
      final repository = FakeGroupRepository(members: [_member]);
      final viewModel = buildViewModel(repository, _member.groupId);

      await viewModel.loadMembers();
      final ok = await viewModel.kickMembers([_member.userId]);

      expect(ok, isTrue);
      expect(repository.kickedUserIds, [_member.userId]);
      expect(repository.loadCount, 2);
    });

    test('transferOwner 失败时返回 false 并写入错误', () async {
      final repository = FakeGroupRepository(shouldFail: true);
      final viewModel = buildViewModel(repository, 'g1');

      final ok = await viewModel.transferOwner('u2');

      expect(ok, isFalse);
      expect(viewModel.state.error, contains('转让群主失败'));
    });
  });
}
