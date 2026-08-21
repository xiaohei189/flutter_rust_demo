import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_rust_demo/ui/chat/widgets/list/forward_progress_banner.dart';

void main() {
  testWidgets('转发进度横幅展示进度并响应取消', (tester) async {
    var cancelled = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ForwardProgressBanner(
            done: 1,
            total: 2,
            onCancel: () => cancelled = true,
          ),
        ),
      ),
    );

    expect(find.text('转发中 1/2'), findsOneWidget);
    final progress = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(progress.value, 0.5);

    await tester.tap(find.text('取消'));
    expect(cancelled, isTrue);
  });
}
