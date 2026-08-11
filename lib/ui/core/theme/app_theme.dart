import 'package:flutter/material.dart';

/// 语义化颜色 token，随 light/dark 主题切换。
class AppColors extends ThemeExtension<AppColors> {
  final Color background;
  final Color surface;
  final Color surfaceMuted;
  final Color textPrimary;
  final Color textSecondary;
  final Color divider;
  final Color primary;
  final Color bubbleMine;
  final Color bubbleOther;
  final Color bubbleOtherText;
  final Color danger;
  final Color warning;
  final Color inputBackground;
  final Color attachmentBackground;
  final Color formatBarBackground;
  final Color shadow;

  const AppColors({
    required this.background,
    required this.surface,
    required this.surfaceMuted,
    required this.textPrimary,
    required this.textSecondary,
    required this.divider,
    required this.primary,
    required this.bubbleMine,
    required this.bubbleOther,
    required this.bubbleOtherText,
    required this.danger,
    required this.warning,
    required this.inputBackground,
    required this.attachmentBackground,
    required this.formatBarBackground,
    required this.shadow,
  });

  static const light = AppColors(
    background: Color(0xFFF5F5F5),
    surface: Colors.white,
    surfaceMuted: Color(0xFFF7F8FA),
    textPrimary: Color(0xFF1A1A1A),
    textSecondary: Color(0xFF8E8E93),
    divider: Color(0xFFE5E5EA),
    primary: Color(0xFF007AFF),
    bubbleMine: Color(0xFF007AFF),
    bubbleOther: Color(0xFFE5E5EA),
    bubbleOtherText: Color(0xFF1A1A1A),
    danger: Color(0xFFFF3B30),
    warning: Color(0xFFFF9500),
    inputBackground: Color(0xFFF5F5F7),
    attachmentBackground: Color(0xFFF8F8F8),
    formatBarBackground: Color(0xFFF0F0F5),
    shadow: Color(0x14000000),
  );

  static const dark = AppColors(
    background: Color(0xFF111214),
    surface: Color(0xFF1C1D1F),
    surfaceMuted: Color(0xFF26282B),
    textPrimary: Color(0xFFF2F2F7),
    textSecondary: Color(0xFF9A9AA2),
    divider: Color(0xFF303236),
    primary: Color(0xFF4C9EFF),
    bubbleMine: Color(0xFF0A84FF),
    bubbleOther: Color(0xFF2C2C2E),
    bubbleOtherText: Color(0xFFF2F2F7),
    danger: Color(0xFFFF453A),
    warning: Color(0xFFFF9F0A),
    inputBackground: Color(0xFF232326),
    attachmentBackground: Color(0xFF1C1D1F),
    formatBarBackground: Color(0xFF26282B),
    shadow: Color(0x52000000),
  );

  @override
  AppColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceMuted,
    Color? textPrimary,
    Color? textSecondary,
    Color? divider,
    Color? primary,
    Color? bubbleMine,
    Color? bubbleOther,
    Color? bubbleOtherText,
    Color? danger,
    Color? warning,
    Color? inputBackground,
    Color? attachmentBackground,
    Color? formatBarBackground,
    Color? shadow,
  }) {
    return AppColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      divider: divider ?? this.divider,
      primary: primary ?? this.primary,
      bubbleMine: bubbleMine ?? this.bubbleMine,
      bubbleOther: bubbleOther ?? this.bubbleOther,
      bubbleOtherText: bubbleOtherText ?? this.bubbleOtherText,
      danger: danger ?? this.danger,
      warning: warning ?? this.warning,
      inputBackground: inputBackground ?? this.inputBackground,
      attachmentBackground: attachmentBackground ?? this.attachmentBackground,
      formatBarBackground: formatBarBackground ?? this.formatBarBackground,
      shadow: shadow ?? this.shadow,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      bubbleMine: Color.lerp(bubbleMine, other.bubbleMine, t)!,
      bubbleOther: Color.lerp(bubbleOther, other.bubbleOther, t)!,
      bubbleOtherText: Color.lerp(bubbleOtherText, other.bubbleOtherText, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      inputBackground: Color.lerp(inputBackground, other.inputBackground, t)!,
      attachmentBackground: Color.lerp(
        attachmentBackground,
        other.attachmentBackground,
        t,
      )!,
      formatBarBackground: Color.lerp(
        formatBarBackground,
        other.formatBarBackground,
        t,
      )!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
    );
  }

  List<BoxShadow> get cardShadow => [
    BoxShadow(color: shadow, blurRadius: 12, offset: const Offset(0, 4)),
  ];
}

extension AppColorsContext on BuildContext {
  AppColors get appColors =>
      Theme.of(this).extension<AppColors>() ?? AppColors.light;
}

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

  /// 输入区（飞书风格）
  static const double inputBarHeight = 48.0;
  static const double formatBarHeight = 40.0;
  static const Color feishuInputBg = Color(0xFFF5F5F7);
  static const Color attachmentPanelBg = Color(0xFFF8F8F8);
  static const Color formatBarBg = Color(0xFFF0F0F5);

  /// 圆角与间距 token
  static const double radiusSm = 4;
  static const double radiusMd = 8;
  static const double radiusLg = 12;
  static const double spacingXs = 4;
  static const double spacingSm = 8;
  static const double spacingMd = 12;
  static const double spacingLg = 16;
  static const double spacingXl = 20;

  /// 字体 token
  static const double fontSizeCaption = 11;
  static const double fontSizeSmall = 13;
  static const double fontSizeBody = 15;
  static const double fontSizeTitle = 17;
  static const double fontSizeHeadline = 20;

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
    extensions: const [AppColors.light],
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: AppColors.dark.primary,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.dark.primary,
      brightness: Brightness.dark,
      primary: AppColors.dark.primary,
    ),
    scaffoldBackgroundColor: AppColors.dark.background,
    appBarTheme: AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      backgroundColor: AppColors.dark.surface,
      foregroundColor: AppColors.dark.textPrimary,
      titleTextStyle: TextStyle(
        color: AppColors.dark.textPrimary,
        fontSize: 17,
        fontWeight: FontWeight.w600,
      ),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      selectedItemColor: AppColors.dark.primary,
      unselectedItemColor: AppColors.dark.textSecondary,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
      backgroundColor: AppColors.dark.surface,
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      filled: true,
      fillColor: AppColors.dark.inputBackground,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      hintStyle: TextStyle(color: AppColors.dark.textSecondary),
    ),
    extensions: const [AppColors.dark],
  );
}
