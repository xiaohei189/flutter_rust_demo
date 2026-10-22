import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_rust_demo/ui/chat/widgets/composer/input_toolbar_icon.dart';

/// 工具栏图标的手势穿透：Tooltip 默认以「长按」触发，
/// 若它被放在 GestureDetector 内层就会抢走长按，导致语音按钮「按了没反应」。
void main() {
  Widget host({
    required VoidCallback onTap,
    void Function(LongPressStartDetails)? onLongPressStart,
    void Function(LongPressEndDetails)? onLongPressEnd,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: InputToolbarIcon(
            icon: Icons.mic_none,
            tooltip: '语音（长按录音，上滑取消）',
            onTap: onTap,
            onLongPressStart: onLongPressStart,
            onLongPressEnd: onLongPressEnd,
          ),
        ),
      ),
    );
  }

  testWidgets('长按语音按钮能触发录音回调（Tooltip 不抢手势）', (tester) async {
    var longPressStarted = false;
    var longPressEnded = false;
    await tester.pumpWidget(
      host(
        onTap: () {},
        onLongPressStart: (_) => longPressStarted = true,
        onLongPressEnd: (_) => longPressEnded = true,
      ),
    );

    await tester.longPress(find.byType(InputToolbarIcon));
    await tester.pumpAndSettle();

    expect(longPressStarted, isTrue, reason: '长按必须传到录音逻辑，不能被 Tooltip 吃掉');
    expect(longPressEnded, isTrue, reason: '松手要结束录音');
  });

  testWidgets('轻点语音按钮走 onTap（聚焦输入框）', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      host(
        onTap: () => tapped = true,
        onLongPressStart: (_) {},
      ),
    );

    await tester.tap(find.byType(InputToolbarIcon));
    await tester.pump(const Duration(milliseconds: 50));

    expect(tapped, isTrue);
  });

  testWidgets('没有长按回调的图标仍然可点（相册/@ 等）', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: InputToolbarIcon(
              icon: Icons.image_outlined,
              tooltip: '相册',
              onTap: () => tapped = true,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(InputToolbarIcon));
    await tester.pump(const Duration(milliseconds: 50));

    expect(tapped, isTrue);
  });
}
