import 'package:flutter/material.dart';

/// 应用主题配置
class AppTheme {
  // 主题色
  static const Color primaryColor = Color(0xFF1E88E5);
  static const Color secondaryColor = Color(0xFF42A5F5);
  static const Color accentColor = Color(0xFFFF6F00);
  
  // 聊天相关颜色
  static const Color myMessageColor = Color(0xFF1E88E5);
  static const Color otherMessageColor = Color(0xFFEEEEEE);
  static const Color backgroundColor = Color(0xFFF5F5F5);
  
  // 文字颜色
  static const Color textPrimaryColor = Color(0xFF212121);
  static const Color textSecondaryColor = Color(0xFF757575);
  
  // 主题数据
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    primaryColor: primaryColor,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: Colors.white,
    appBarTheme: const AppBarTheme(
      elevation: 1,
      centerTitle: true,
      backgroundColor: Colors.white,
      foregroundColor: textPrimaryColor,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      selectedItemColor: primaryColor,
      unselectedItemColor: textSecondaryColor,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(25),
        borderSide: BorderSide.none,
      ),
      filled: true,
      fillColor: Colors.grey[100],
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    ),
  );
}



