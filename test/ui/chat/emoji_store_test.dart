import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_rust_demo/data/services/emoji_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('recordUse 置顶去重', () async {
    await EmojiStore.recordUse('😀');
    await EmojiStore.recordUse('👍');
    await EmojiStore.recordUse('😀');

    final recent = await EmojiStore.loadRecent();
    expect(recent.first, '😀', reason: '重复使用应置顶');
    expect(recent.length, 2, reason: '重复项应去重');
  });

  test('recordUse 超过上限时裁剪', () async {
    for (var i = 0; i < 40; i++) {
      await EmojiStore.recordUse('e$i');
    }
    final recent = await EmojiStore.loadRecent();
    expect(recent.length, 30, reason: '最近使用最多保留 30 个');
    expect(recent.first, 'e39', reason: '最新的排最前');
  });

  test('toggleFavorite 收藏与取消', () async {
    await EmojiStore.toggleFavorite('❤️');
    expect(await EmojiStore.loadFavorites(), ['❤️']);

    await EmojiStore.toggleFavorite('❤️');
    expect(await EmojiStore.loadFavorites(), isEmpty, reason: '再次点击取消收藏');
  });

  test('loadRecent 无记录时返回空列表', () async {
    expect(await EmojiStore.loadRecent(), isEmpty);
  });
}
