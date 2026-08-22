import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_rust_demo/data/services/conversation_folder_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('save/load 往返保留分组与成员', () async {
    SharedPreferences.setMockInitialValues({});
    final store = ConversationFolderStore();

    await store.save({
      '工作': ['si_a_b'],
      '家庭': ['si_c_d', 'sg_group_1'],
    });

    final loaded = await store.load();
    expect(loaded['工作'], ['si_a_b']);
    expect(loaded['家庭'], ['si_c_d', 'sg_group_1']);
  });

  test('空分组在保存时被清理', () async {
    SharedPreferences.setMockInitialValues({});
    final store = ConversationFolderStore();

    await store.save({
      '工作': [],
      '家庭': ['si_a_b'],
    });

    final loaded = await store.load();
    expect(loaded.containsKey('工作'), isFalse);
    expect(loaded['家庭'], ['si_a_b']);
  });

  test('无数据时返回空 Map', () async {
    SharedPreferences.setMockInitialValues({});
    final store = ConversationFolderStore();

    expect(await store.load(), isEmpty);
  });
}
