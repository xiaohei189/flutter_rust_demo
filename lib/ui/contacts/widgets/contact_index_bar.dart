import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// 通讯录右侧 A–Z 索引条。
///
/// 点按或上下滑动都会回调 [onLetterSelected]；拖动过程中由页面负责把当前字母
/// 放大显示（对齐飞书：拖到哪个字母，屏幕中间浮出那个字母）。
class ContactIndexBar extends StatelessWidget {
  const ContactIndexBar({
    super.key,
    required this.letters,
    required this.onLetterSelected,
    this.onInteractionEnd,
    this.activeLetter,
  });

  /// 需要展示的字母（已按 A→Z + 「#」排好），只显示实际存在的分组。
  final List<String> letters;

  final ValueChanged<String> onLetterSelected;

  /// 拖动/点按结束（页面据此收起浮层字母）。
  final VoidCallback? onInteractionEnd;

  final String? activeLetter;

  /// 单个字母的占位高度，用于把拖动坐标换算成字母下标。
  static const double _itemExtent = 16;

  @override
  Widget build(BuildContext context) {
    if (letters.isEmpty) return const SizedBox.shrink();
    final colors = context.appColors;
    final height = _itemExtent * letters.length;

    void selectAt(Offset localPosition) {
      final index = (localPosition.dy / _itemExtent).floor().clamp(
        0,
        letters.length - 1,
      );
      onLetterSelected(letters[index]);
    }

    return SizedBox(
      width: 24,
      height: height,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (details) {
          selectAt(details.localPosition);
          onInteractionEnd?.call();
        },
        onVerticalDragStart: (details) => selectAt(details.localPosition),
        onVerticalDragUpdate: (details) => selectAt(details.localPosition),
        onVerticalDragEnd: (_) => onInteractionEnd?.call(),
        onVerticalDragCancel: () => onInteractionEnd?.call(),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final letter in letters)
              SizedBox(
                height: _itemExtent,
                child: Center(
                  child: Text(
                    letter,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: letter == activeLetter
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: letter == activeLetter
                          ? colors.primary
                          : colors.textSecondary,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 拖动索引条时屏幕中央浮出的字母提示。
class ContactIndexBubble extends StatelessWidget {
  const ContactIndexBubble({super.key, required this.letter});

  final String letter;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return IgnorePointer(
      child: Center(
        child: Container(
          width: 64,
          height: 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colors.textPrimary.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(AppTheme.radiusSheet),
          ),
          child: Text(
            letter,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w600,
              color: colors.onPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
