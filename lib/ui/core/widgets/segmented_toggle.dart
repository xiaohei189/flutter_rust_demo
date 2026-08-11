import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

import '../theme/app_theme.dart';

/// 分段控制器：灰底圆角容器，当前主题色滑块平滑滑动。
class SegmentedToggle extends StatelessWidget {
  const SegmentedToggle({
    super.key,
    required this.segments,
    required this.selectedIndex,
    required this.onChanged,
  });

  final List<String> segments;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final count = segments.length;
    return Container(
      height: 34,
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: BorderRadius.circular(17),
      ),
      padding: const EdgeInsets.all(2),
      child: IntrinsicWidth(
        child: Stack(
          children: [
            Visibility(
              visible: false,
              maintainSize: true,
              maintainAnimation: true,
              maintainState: true,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  count,
                  (i) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      segments[i],
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final segWidth = constraints.maxWidth / count;
                  return Stack(
                    children: [
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeInOut,
                        left: segWidth * selectedIndex,
                        top: 0,
                        bottom: 0,
                        width: segWidth,
                        child: Container(
                          decoration: BoxDecoration(
                            color: colors.surface,
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                      ),
                      Row(
                        children: List.generate(count, (i) {
                          final isSelected = i == selectedIndex;
                          return Expanded(
                            child: GestureDetector(
                              onTap: () => onChanged(i),
                              behavior: HitTestBehavior.opaque,
                              child: Center(
                                child: Text(
                                  segments[i],
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                    color: isSelected
                                        ? colors.primary
                                        : colors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

@Preview(name: '两段 - 选中第一项', group: 'SegmentedToggle')
Widget segmentedToggleTwoFirstPreview() {
  return Padding(
    padding: const EdgeInsets.all(16),
    child: SegmentedToggle(
      segments: const ['聊天', '群组'],
      selectedIndex: 0,
      onChanged: (_) {},
    ),
  );
}

@Preview(name: '两段 - 选中第二项', group: 'SegmentedToggle')
Widget segmentedToggleTwoSecondPreview() {
  return Padding(
    padding: const EdgeInsets.all(16),
    child: SegmentedToggle(
      segments: const ['聊天', '群组'],
      selectedIndex: 1,
      onChanged: (_) {},
    ),
  );
}

@Preview(name: '三段 - 选中中间', group: 'SegmentedToggle')
Widget segmentedToggleThreePreview() {
  return Padding(
    padding: const EdgeInsets.all(16),
    child: SegmentedToggle(
      segments: const ['全部', '未读', '群组'],
      selectedIndex: 1,
      onChanged: (_) {},
    ),
  );
}
