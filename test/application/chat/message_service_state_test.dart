import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_rust_demo/application/chat/message_service_state.dart';

void main() {
  test('copyWith 未变更的领域复用原 Store 实例', () {
    final state = MessageServiceState(
      currentUserId: 'u1',
      conversations: const [],
      messages: const {},
    );

    final next = state.copyWith(isConnected: true);

    expect(next.isConnected, isTrue);
    // 仅连接领域变化，其余 Store 直接复用，避免每次状态更新重建 5 个 Store。
    expect(identical(next.connection, state.connection), isFalse);
    expect(identical(next.conversation, state.conversation), isTrue);
    expect(identical(next.message, state.message), isTrue);
    expect(identical(next.userProfile, state.userProfile), isTrue);
    expect(identical(next.social, state.social), isTrue);
  });

  test('copyWith 无参数时全部 Store 复用', () {
    final state = MessageServiceState(currentUserId: 'u1');
    final next = state.copyWith();

    expect(identical(next.connection, state.connection), isTrue);
    expect(identical(next.conversation, state.conversation), isTrue);
    expect(identical(next.message, state.message), isTrue);
    expect(identical(next.userProfile, state.userProfile), isTrue);
    expect(identical(next.social, state.social), isTrue);
  });

  test('领域 Store 的 copyWith 无变更时返回自身', () {
    final state = MessageServiceState(currentUserId: 'u1');

    expect(identical(state.connection.copyWith(), state.connection), isTrue);
    expect(identical(state.conversation.copyWith(), state.conversation), isTrue);
    expect(identical(state.message.copyWith(), state.message), isTrue);
    expect(identical(state.userProfile.copyWith(), state.userProfile), isTrue);
    expect(identical(state.social.copyWith(), state.social), isTrue);
  });
}
