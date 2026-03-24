import 'package:flutter/material.dart';

/// IM 应用设计系统：简约、扁平化（类似微信的克制与 Telegram 的流畅）
class AppTheme {
  /// 主色：标准蓝，代表信任与沟通（可选 #07C160 微信绿）
  static const Color primaryColor = Color(0xFF007AFF);
  static const Color secondaryColor = Color(0xFF5AC8FA);
  static const Color accentColor = Color(0xFF007AFF);

  /// 背景
  static const Color backgroundColor = Color(0xFFF5F5F5);
  static const Color scaffoldBackgroundColor = Color(0xFFF5F5F5);

  /// 文字
  static const Color textPrimaryColor = Color(0xFF1A1A1A);
  static const Color textSecondaryColor = Color(0xFF8E8E93);

  /// 聊天气泡
  static const Color myMessageColor = Color(0xFF007AFF);
  static const Color otherMessageColor = Color(0xFFE5E5EA);
  static const Color otherMessageTextColor = Color(0xFF1A1A1A);

  /// 未读/草稿等
  static const Color unreadRed = Color(0xFFFF3B30);
  static const Color draftOrange = Color(0xFFFF9500);

  /// 分割线
  static const Color dividerColor = Color(0xFFE5E5EA);

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    primaryColor: primaryColor,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.light,
      primary: primaryColor,
    ),
    scaffoldBackgroundColor: scaffoldBackgroundColor,
    appBarTheme: const AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      backgroundColor: Colors.white,
      foregroundColor: textPrimaryColor,
      titleTextStyle: TextStyle(
        color: textPrimaryColor,
        fontSize: 17,
        fontWeight: FontWeight.w600,
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      selectedItemColor: primaryColor,
      unselectedItemColor: textSecondaryColor,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
      backgroundColor: Colors.white,
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      filled: true,
      fillColor: const Color(0xFFE5E5EA),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      hintStyle: const TextStyle(color: textSecondaryColor),
    ),
  );
}
