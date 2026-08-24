import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_rust_demo/data/services/user_avatar_store.dart';

void main() {
  final store = UserAvatarStore();

  test('isValidAvatarUrl 只接受真实 HTTP URL', () {
    expect(store.isValidAvatarUrl('https://a.com/1.png'), isTrue);
    expect(store.isValidAvatarUrl('http://a.com/1.png'), isTrue);
    expect(store.isValidAvatarUrl('example.com/1.png'), isFalse);
    expect(store.isValidAvatarUrl('C:\\tmp\\a.png'), isFalse);
    expect(store.isValidAvatarUrl(''), isFalse);
    expect(store.isValidAvatarUrl(null), isFalse);
  });

  test('extractFileName 从 URL 提取最后一段', () {
    expect(store.extractFileName('https://a.com/dir/avatar.jpg'), 'avatar.jpg');
    expect(store.extractFileName(''), '');
  });

  test('addCacheBuster 兼容带查询参数的 URL', () {
    expect(store.addCacheBuster('https://a.com/a.png'), contains('_t='));
    expect(store.addCacheBuster('https://a.com/a.png?v=1'), contains('&_t='));
  });

  test('resolveDisplayUrl 本地路径不存在时回退服务器 URL', () {
    expect(
      store.resolveDisplayUrl(
        localAvatarPath: 'Z:/not_exist/avatar.jpg',
        faceUrl: 'https://a.com/a.png',
      ),
      'https://a.com/a.png',
    );
  });
}
