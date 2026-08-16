import 'package:flutter/widget_previews.dart';

import '../core/theme/app_theme.dart';

/// 统一预览注解：为预览注入 AppTheme 浅色/深色主题，
/// 保证预览颜色与 App 运行效果一致，并支持明暗两套主题切换。
///
/// 用法（替换普通 `@Preview`）：
/// ```dart
/// @AppThemePreview(name: '基础标题', group: 'SectionTitle')
/// Widget sectionTitlePreview() => const SectionTitle(title: '好友动态');
/// ```
final class AppThemePreview extends Preview {
  const AppThemePreview({
    super.name,
    super.group,
    super.size,
    super.brightness,
    super.textScaleFactor,
    super.wrapper,
  });

  PreviewThemeData _themeBuilder() {
    return PreviewThemeData(
      materialLight: AppTheme.lightTheme,
      materialDark: AppTheme.darkTheme,
    );
  }

  @override
  Preview transform() {
    final builder = super.transform().toBuilder();
    builder.theme = _themeBuilder;
    return builder.build();
  }
}
