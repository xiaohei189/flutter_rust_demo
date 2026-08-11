import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_rust_demo/domain/models/friend.dart';
import 'package:flutter_rust_demo/domain/models/group.dart';
import 'package:flutter_rust_demo/ui/contacts/providers/contact_picker_provider.dart';
import 'package:flutter_rust_demo/ui/contacts/view_models/contact_picker_view_model.dart';
import 'package:flutter_rust_demo/ui/contacts/widgets/contact_pick_item.dart';

ContactPickerViewModel buildViewModel() {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  return container.read(contactPickerViewModelProvider.notifier);
}

void main() {
  group('ContactPickerViewModel', () {
    test('initialize 写入多选与排除列表', () {
      final viewModel = buildViewModel();

      viewModel.initialize(multiSelect: true, excludeIds: ['u1']);

      expect(viewModel.state.multiSelect, isTrue);
      expect(viewModel.state.excludeIds, ['u1']);
    });

    test('filteredFriends 按关键字与排除列表过滤', () {
      final viewModel = buildViewModel();
      viewModel.initialize(multiSelect: false, excludeIds: ['u1']);
      viewModel.setKeyword('张');
      final friends = [
        const Friend(
          userId: 'u1',
          nickname: '张三',
          faceUrl: '',
          gender: 1,
          remark: '',
          addSource: '',
          ex: '',
        ),
        const Friend(
          userId: 'u2',
          nickname: '张三丰',
          faceUrl: '',
          gender: 1,
          remark: '',
          addSource: '',
          ex: '',
        ),
        const Friend(
          userId: 'u3',
          nickname: '李四',
          faceUrl: '',
          gender: 2,
          remark: '',
          addSource: '',
          ex: '',
        ),
      ];

      final result = viewModel.filteredFriends(friends);

      expect(result.map((f) => f.userId), ['u2']);
    });

    test('filteredGroups 按关键字过滤', () {
      final viewModel = buildViewModel();
      viewModel.setKeyword('产品');
      final groups = [
        const Group(
          groupId: 'g1',
          groupName: '产品群',
          faceUrl: '',
          introduction: '',
          notification: '',
          ownerUserId: 'u1',
          memberCount: 3,
          status: 0,
        ),
        const Group(
          groupId: 'g2',
          groupName: '闲聊群',
          faceUrl: '',
          introduction: '',
          notification: '',
          ownerUserId: 'u1',
          memberCount: 2,
          status: 0,
        ),
      ];

      final result = viewModel.filteredGroups(groups);

      expect(result.map((g) => g.groupId), ['g1']);
    });

    test('多选模式 toggleSelection 累计选中', () {
      final viewModel = buildViewModel();
      viewModel.initialize(multiSelect: true);

      final first = viewModel.toggleSelection(
        const ContactPickItem(
          id: 'u1',
          name: '张三',
          avatarUrl: '',
          isGroup: false,
        ),
      );
      viewModel.toggleSelection(
        const ContactPickItem(
          id: 'g1',
          name: '群聊',
          avatarUrl: '',
          isGroup: true,
        ),
      );

      expect(first, isFalse);
      expect(viewModel.state.selectedIds, {'u1', 'g1'});
    });

    test('单选模式 toggleSelection 返回可关闭页面', () {
      final viewModel = buildViewModel();
      viewModel.initialize(multiSelect: false);

      final shouldPop = viewModel.toggleSelection(
        const ContactPickItem(
          id: 'u1',
          name: '张三',
          avatarUrl: '',
          isGroup: false,
        ),
      );

      expect(shouldPop, isTrue);
      expect(viewModel.state.selectedIds, {'u1'});
    });
  });
}
