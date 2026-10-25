import 'package:flutter/material.dart';

/// 底部弹窗内容容器：装得下按内容高度，装不下可滚动。
///
/// `showModalBottomSheet` 默认高度上限约为屏高的 9/16：横屏或小窗口下
/// 3 项以上的弹窗很容易把最后一项挤出屏幕（真机横屏 344dp 时「群管理」
/// 曾出现 `RenderFlex overflowed by 57 pixels`，「解散群组」不可点击）。
class ScrollableSheetBody extends StatelessWidget {
  const ScrollableSheetBody({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: children),
      ),
    );
  }
}
