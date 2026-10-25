import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_rust_demo/ui/chat/widgets/composer/chat_input.dart';
import 'package:flutter_rust_demo/ui/chat/widgets/composer/voice_panel.dart';
import 'package:flutter_rust_demo/ui/core/theme/app_theme.dart';

/// 语音输入面板（对齐飞书）：点语音图标进面板、面板内有「按住说话」大圆按钮；
/// 再点一次收起回键盘。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Widget host(TextEditingController controller) => MaterialApp(
    home: Scaffold(
      body: Align(
        alignment: Alignment.bottomCenter,
        child: ChatInput(
          controller: controller,
          onSend: (_, _) {},
          onAtMention: () {},
          keyboardInset: 0,
        ),
      ),
    ),
  );

  testWidgets('轻点语音图标打开语音面板，再点收起', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(host(controller));
    await tester.pump();

    expect(find.byType(VoicePanel), findsNothing, reason: '未打开时不应构建面板');

    await tester.tap(find.byTooltip('语音（长按录音，上滑取消）'));
    await tester.pumpAndSettle();

    expect(find.byType(VoicePanel), findsOneWidget);
    expect(find.text('按住 说话'), findsOneWidget);
    expect(find.byType(VoicePanel), findsOneWidget);
    // 图标切到「键盘/语音激活」态，提示当前露出的是语音面板
    expect(find.byIcon(Icons.keyboard_voice), findsOneWidget);

    await tester.tap(find.byTooltip('语音（长按录音，上滑取消）'));
    await tester.pumpAndSettle();
    expect(find.text('按住 说话'), findsNothing, reason: '再点一次应收起面板');
  });

  testWidgets('横屏小高度下语音面板等比缩小且不溢出', (tester) async {
    // 真机横屏时输入区只给语音面板 ~160dp（设计高度 300dp），内容必须自适应
    tester.view.physicalSize = const Size(360, 160);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 160,
            child: VoicePanel(onRecordStart: (_) {}),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      tester.takeException(),
      isNull,
      reason: '小高度下不应 RenderFlex overflow',
    );
    final button = find.byKey(const ValueKey('voice_panel_record_button'));
    expect(button, findsOneWidget);
    expect(
      tester.getRect(button).height,
      lessThanOrEqualTo(160),
      reason: '录音按钮应缩放到可用高度内',
    );
    expect(find.text('按住 说话'), findsOneWidget);
  });

  testWidgets('语音面板里的大圆按钮存在且可长按（不抛异常）', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(host(controller));
    await tester.pump();
    await tester.tap(find.byTooltip('语音（长按录音，上滑取消）'));
    await tester.pumpAndSettle();

    final button = find.descendant(
      of: find.byType(VoicePanel),
      matching: find.byIcon(Icons.mic),
    );
    expect(button, findsOneWidget);

    // 测试环境没有 record 插件：长按会走「录音启动失败」分支并提示，
    // 这里只要求手势能到达录音逻辑且不抛异常。
    await tester.longPress(button);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('未录音时残留的 cancel 标记不会把面板染成取消态', (tester) async {
    // 回归：上滑取消后 controller 的 cancel 标记若未复位，面板会一直停在
    // 红色的「松开手指，取消发送」，看起来像卡住了。
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VoicePanel(
            recording: false,
            cancel: true,
            onRecordStart: (_) {},
          ),
        ),
      ),
    );

    final hint = find.text('按住 说话');
    expect(hint, findsOneWidget);
    expect(find.text('松开手指，取消发送'), findsNothing);
    final colors = tester.element(hint).appColors;
    expect(tester.widget<Text>(hint).style?.color, colors.textSecondary);
  });
}
