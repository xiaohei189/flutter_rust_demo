import 'package:flutter/material.dart';

import '../../previews/app_theme_preview.dart';
import '../theme/app_theme.dart';

/// 分段控制器：灰底圆角容器，当前主题色滑块平滑滑动。
///
/// 撑满父容器宽度，各段 [Expanded] 严格等宽；选中段白色浮起滑块。
/// 可通过 [activeColor] 覆盖选中态文字颜色（默认取 `appColors.primary`）。
class SegmentedToggle extends StatelessWidget {
  const SegmentedToggle({
    super.key,
    required this.segments,
    required this.selectedIndex,
    required this.onChanged,
    this.activeColor,
    this.height = 34,
  });

  final List<String> segments;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  /// 选中态文字/滑块颜色；为 null 时使用 `appColors.primary`。
  final Color? activeColor;

  /// 控件高度（参考飞书分段控件更高更圆润）。
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final active = activeColor ?? colors.primary;
    final count = segments.length;
    return Container(
      height: height,
      decoration: BoxDecoration(
        // 对齐飞书分段控件：轨道为更明显的浅灰（默认 surfaceMuted 偏白，分段不突出）。
        color: const Color(0xFFF0F1F4),
        borderRadius: BorderRadius.circular(height / 2),
      ),
      padding: const EdgeInsets.all(2),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final segWidth = constraints.maxWidth / count;
          return Stack(
            children: [
              // 选中滑块
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
                    borderRadius: BorderRadius.circular((height - 4) / 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
              // 等宽分段
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
                            fontSize: 14,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: isSelected
                                ? active
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
    );
  }
}

@AppThemePreview(name: '两段 - 选中第一项', group: 'SegmentedToggle')
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

@AppThemePreview(name: '两段 - 选中第二项', group: 'SegmentedToggle')
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

@AppThemePreview(name: '三段 - 选中中间', group: 'SegmentedToggle')
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
