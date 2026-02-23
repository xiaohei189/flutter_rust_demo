import 'package:flutter/material.dart';

/// 未读数角标（与 openim-flutter-demo UnreadCountView 对齐）
class UnreadCountView extends StatelessWidget {
  const UnreadCountView({
    super.key,
    this.count = 0,
    this.size = 18,
  });

  final int count;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    final text = count > 99 ? '99+' : '$count';
    return Container(
      alignment: Alignment.center,
      constraints: BoxConstraints(
        minWidth: size,
        minHeight: size,
        maxWidth: count > 99 ? size * 1.8 : size,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFF381F),
        shape: count > 99 ? BoxShape.rectangle : BoxShape.circle,
        borderRadius: count > 99 ? BorderRadius.circular(size / 2) : null,
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
