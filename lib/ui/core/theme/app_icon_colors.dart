import 'package:flutter/material.dart';

/// 功能入口的图标装饰色板（飞书稿：每个入口一个颜色）。
///
/// 这是**装饰色**，与 `AppColors` 的语义色分工不同：
/// - 只用于图标（通常配同色 10% 底色的圆角块），不参与 light/dark 语义；
/// - 不允许用于文字、按钮、状态（那些一律取 `context.appColors.*`）。
///
/// 蓝色与 `AppColors.primary` 的浅色取值一致，避免应用里出现第二个蓝
/// （历史遗留的 `#3370FF` 已并入）。附件面板、通讯录、工作台共用这一份，
/// 不要再在页面里各写一遍色值。
abstract final class AppIconColors {
  static const blue = Color(0xFF007AFF);
  static const green = Color(0xFF07C160);
  static const orange = Color(0xFFFF8A00);
  static const purple = Color(0xFF9B5DE5);
  static const teal = Color(0xFF00B8A9);

  /// 图标色块底：同色 10% 透明（飞书通讯录/工作台的图标底座）。
  static Color tint(Color color) => color.withValues(alpha: 0.1);
}
