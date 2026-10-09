import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_rust_demo/ui/chat/providers/message_extras_provider.dart';

/// 表情回复：改为落在消息本地扩展（MessageExtras）里，语义从「模拟他人 reaction」
/// 收敛为「当前用户对这条消息的表情」——服务端不提供 reaction 数据。
Future<MessageExtrasNotifier> _notifier() async {
  SharedPreferences.setMockInitialValues({});
  final container = ProviderContainer();
  addTearDown(container.dispose);
  final notifier = container.read(messageExtrasProvider.notifier);
  await Future<void>.delayed(const Duration(milliseconds: 50));
  return notifier;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('首次点击添加表情回复', () async {
    final notifier = await _notifier();

    await notifier.toggleReaction('si_a_b', 'm1', '👍');

    expect(notifier.extrasOf('si_a_b', 'm1').reactions, {'👍'});
  });

  test('再次点击同一个表情即移除', () async {
    final notifier = await _notifier();
    await notifier.toggleReaction('si_a_b', 'm1', '👍');

    await notifier.toggleReaction('si_a_b', 'm1', '👍');

    expect(notifier.extrasOf('si_a_b', 'm1').reactions, isEmpty);
  });

  test('多个表情可以并存，且只影响当前消息', () async {
    final notifier = await _notifier();

    await notifier.toggleReaction('si_a_b', 'm1', '👍');
    await notifier.toggleReaction('si_a_b', 'm1', '🎉');

    expect(notifier.extrasOf('si_a_b', 'm1').reactions, {'👍', '🎉'});
    expect(notifier.extrasOf('si_a_b', 'm2').reactions, isEmpty);
  });
}
