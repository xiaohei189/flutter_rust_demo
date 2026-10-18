import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_rust_demo/data/services/audio_player_service.dart';

/// 语音缓存清理策略：先清过期，再按「最久未使用」淘汰到总量上限内。
void main() {
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('audio_cache_test');
  });

  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  File makeFile(String name, int bytes, DateTime modifiedAt) {
    final file = File('${dir.path}/$name')
      ..writeAsBytesSync(List<int>.filled(bytes, 0));
    file.setLastModifiedSync(modifiedAt);
    return file;
  }

  test('过期文件全部清理', () {
    final now = DateTime(2026, 10, 18, 12);
    final old = makeFile('old.aac', 10, now.subtract(const Duration(days: 30)));
    final fresh = makeFile('fresh.aac', 10, now.subtract(const Duration(hours: 1)));

    final evicted = AudioPlayerService.selectCacheEvictions(
      [old, fresh],
      maxBytes: 1024,
      maxAge: const Duration(days: 7),
      now: now,
    );

    expect(evicted, [old]);
  });

  test('总量超限时按最久未使用淘汰，直到不超过上限', () {
    final now = DateTime(2026, 10, 18, 12);
    final a = makeFile('a.aac', 40, now.subtract(const Duration(hours: 3)));
    final b = makeFile('b.aac', 40, now.subtract(const Duration(hours: 2)));
    final c = makeFile('c.aac', 40, now.subtract(const Duration(hours: 1)));

    final evicted = AudioPlayerService.selectCacheEvictions(
      [c, a, b],
      maxBytes: 100,
      maxAge: const Duration(days: 7),
      now: now,
    );

    // 120 > 100，至少淘汰最旧的 a；淘汰 a 后剩 80 已满足
    expect(evicted, [a]);
  });

  test('未过期且未超量时不清理', () {
    final now = DateTime(2026, 10, 18, 12);
    final files = [
      makeFile('a.aac', 10, now),
      makeFile('b.aac', 10, now.subtract(const Duration(days: 1))),
    ];

    final evicted = AudioPlayerService.selectCacheEvictions(
      files,
      maxBytes: 100,
      maxAge: const Duration(days: 7),
      now: now,
    );

    expect(evicted, isEmpty);
  });
}
