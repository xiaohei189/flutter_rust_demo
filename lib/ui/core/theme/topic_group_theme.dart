import 'dart:convert';

import 'package:flutter/material.dart';

/// 话题群自己的视觉主题。
///
/// 飞书普通页面使用统一的品牌蓝，但话题群头部会按群展示独立主题色。
/// 当前协议尚未提供可编辑主题字段，因此优先读取
/// `Group.ex.openim_topic.themeColor`，没有配置时按 groupId 稳定选色。
class TopicGroupVisualTheme {
  const TopicGroupVisualTheme({
    required this.headerColor,
    required this.foregroundColor,
  });

  final Color headerColor;
  final Color foregroundColor;

  bool get useLightStatusBar => headerColor.computeLuminance() < 0.58;

  factory TopicGroupVisualTheme.forGroup({
    required String groupId,
    String groupEx = '',
    Brightness brightness = Brightness.light,
  }) {
    final configured = _configuredColor(groupEx);
    final base =
        configured ??
        _fallbackPalette[_stableHash(groupId) % _fallbackPalette.length];
    final color = brightness == Brightness.dark && configured == null
        ? Color.lerp(base, const Color(0xFF000000), 0.16)!
        : base;
    return TopicGroupVisualTheme(
      headerColor: color,
      foregroundColor: color.computeLuminance() > 0.58
          ? const Color(0xFF1A1A1A)
          : const Color(0xFFFFFFFF),
    );
  }

  static const _fallbackPalette = <Color>[
    Color(0xFF665AA8),
    Color(0xFF7B533E),
    Color(0xFF3F5D77),
    Color(0xFF286A68),
    Color(0xFF4F5A8A),
    Color(0xFF476747),
  ];

  static Color? _configuredColor(String ex) {
    if (ex.trim().isEmpty) return null;
    try {
      final root = jsonDecode(ex);
      if (root is! Map) return null;
      final topic = root['openim_topic'];
      if (topic is! Map) return null;
      final raw = topic['themeColor'] ?? topic['theme_color'];
      if (raw is! String) return null;
      final match = RegExp(r'^#?([0-9a-fA-F]{6})$').firstMatch(raw.trim());
      if (match == null) return null;
      return Color(0xFF000000 | int.parse(match.group(1)!, radix: 16));
    } catch (_) {
      return null;
    }
  }

  static int _stableHash(String value) {
    var hash = 0x811C9DC5;
    for (final codeUnit in value.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0x7FFFFFFF;
    }
    return hash;
  }
}
