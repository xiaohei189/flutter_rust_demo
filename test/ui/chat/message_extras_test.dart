import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_rust_demo/domain/models/message_extras.dart';
import 'package:flutter_rust_demo/ui/chat/providers/message_extras_provider.dart';

/// 消息级本地扩展（表情回复 / 置顶消息）的编解码与持久化。
Future<ProviderContainer> _containerWith(Map<String, dynamic> raw) async {
  SharedPreferences.setMockInitialValues({
    if (raw.isNotEmpty) 'message_extras_v1': jsonEncode(raw),
  });
  final container = ProviderContainer();
  addTearDown(container.dispose);
  container.read(messageExtrasProvider);
  await Future<void>.delayed(const Duration(milliseconds: 50));
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('MessageExtras JSON 往返只保留有内容的字段', () {
    expect(MessageExtras.empty.toJson(), isEmpty);

    const extras = MessageExtras(
      reactions: {'👍', '🎉'},
      pinned: true,
      pinnedAt: 1700000000000,
    );
    final restored = MessageExtras.fromJson(extras.toJson());
    expect(restored, extras);
    expect(restored.reactions, containsAll(<String>['👍', '🎉']));
  });

  test('表情回复可加可减，写入后落盘，空扩展会被清掉', () async {
    final container = await _containerWith({});
    final notifier = container.read(messageExtrasProvider.notifier);

    await notifier.toggleReaction('si_a_b', 'm1', '👍');
    expect(notifier.extrasOf('si_a_b', 'm1').reactions, {'👍'});

    // 新容器 = 重启：从本地存储读回来
    final restarted = ProviderContainer();
    addTearDown(restarted.dispose);
    restarted.read(messageExtrasProvider);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(
      restarted.read(messageExtrasProvider.notifier).extrasOf('si_a_b', 'm1').reactions,
      {'👍'},
    );

    await notifier.toggleReaction('si_a_b', 'm1', '👍');
    expect(notifier.extrasOf('si_a_b', 'm1').isEmpty, isTrue);
    expect(container.read(messageExtrasProvider), isEmpty);
  });

  test('置顶消息带时间戳，pinnedMessageIds 按置顶时间从新到旧', () async {
    final container = await _containerWith({});
    final notifier = container.read(messageExtrasProvider.notifier);

    await notifier.setPinned('sg_g1', 'm1', true);
    // pinnedAt 是毫秒时间戳：同一毫秒内的两次置顶无法排序，测试里错开一点
    await Future<void>.delayed(const Duration(milliseconds: 2));
    await notifier.setPinned('sg_g1', 'm2', true);
    expect(notifier.pinnedMessageIds('sg_g1').first, 'm2');

    await notifier.setPinned('sg_g1', 'm2', false);
    expect(notifier.pinnedMessageIds('sg_g1'), ['m1']);
    expect(notifier.extrasOf('sg_g1', 'm2').pinned, isFalse);
  });

  test('旧数据里的非法 JSON 不会影响加载', () async {
    SharedPreferences.setMockInitialValues({
      'message_extras_v1': '{not-json',
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(messageExtrasProvider);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(container.read(messageExtrasProvider), isEmpty);
  });
}
