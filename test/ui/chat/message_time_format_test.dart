import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_rust_demo/ui/chat/mappers/message_display.dart'
    show formatMessageTime;

void main() {
  // 2026-09-10 是周四
  final now = DateTime(2026, 9, 10, 15, 30);

  test('今天只显示时分', () {
    expect(formatMessageTime(DateTime(2026, 9, 10, 8, 5), now: now), '08:05');
  });

  test('昨天显示「昨天 HH:mm」', () {
    expect(
      formatMessageTime(DateTime(2026, 9, 9, 8, 5), now: now),
      '昨天 08:05',
    );
  });

  test('一周内显示周几', () {
    expect(
      formatMessageTime(DateTime(2026, 9, 7, 8, 5), now: now),
      '周一 08:05',
    );
  });

  test('同年超过一周显示月日', () {
    expect(
      formatMessageTime(DateTime(2026, 1, 2, 8, 5), now: now),
      '01月02日 08:05',
    );
  });

  test('往年显示完整日期', () {
    expect(
      formatMessageTime(DateTime(2025, 1, 2, 8, 5), now: now),
      '2025年01月02日 08:05',
    );
  });

  test('相同发送时间命中缓存并返回同一实例', () {
    final sendTime = DateTime(2026, 9, 9, 8, 5);
    final first = formatMessageTime(sendTime, now: now);
    final second = formatMessageTime(sendTime, now: now);
    expect(identical(first, second), isTrue);
  });

  test('跨天后缓存失效并按新日期重算', () {
    final sendTime = DateTime(2026, 9, 9, 8, 5);
    expect(formatMessageTime(sendTime, now: now), '昨天 08:05');
    // 同一天内仍命中缓存
    expect(
      formatMessageTime(sendTime, now: DateTime(2026, 9, 10, 23, 59)),
      '昨天 08:05',
    );
    // 次日重新计算：从「昨天」变成「周三」
    expect(
      formatMessageTime(sendTime, now: DateTime(2026, 9, 11, 0, 1)),
      '周三 08:05',
    );
  });
}
