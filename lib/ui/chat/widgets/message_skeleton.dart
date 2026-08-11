import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// 消息加载时的骨架屏
class MessageSkeleton extends StatelessWidget {
  const MessageSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      reverse: true,
      children: const [
        SkeletonBubble(width: 180, alignRight: true),
        SizedBox(height: 12),
        SkeletonBubble(width: 220, alignRight: false),
        SizedBox(height: 12),
        SkeletonBubble(width: 160, alignRight: true),
        SizedBox(height: 12),
        SkeletonBubble(width: 260, alignRight: false),
        SizedBox(height: 12),
        SkeletonBubble(width: 140, alignRight: true),
      ],
    );
  }
}

/// 单个骨架气泡
class SkeletonBubble extends StatelessWidget {
  const SkeletonBubble({
    super.key,
    required this.width,
    required this.alignRight,
  });

  final double width;
  final bool alignRight;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Align(
      alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        width: width,
        height: 48,
        decoration: BoxDecoration(
          color: colors.surfaceMuted,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(alignRight ? 18 : 4),
            bottomRight: Radius.circular(alignRight ? 4 : 18),
          ),
        ),
      ),
    );
  }
}
