import 'package:flutter/material.dart';

import '../../previews/app_theme_preview.dart';
import '../theme/app_theme.dart';

/// 设置类页面的「分组」：**无卡片外壳**，整幅白底直接铺行，分组之间用留白分层
/// （与会话列表同一套语汇，见 docs/conventions.md「主题/颜色」）。
///
/// 命名沿用历史（原为带圆角的卡片）；现在只剩分组语义，不要再加 margin/圆角/底色。
class CardLayout extends StatelessWidget {
  const CardLayout({
    super.key,
    required this.children,
  });

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}

/// 带标题的卡片布局
class CardLayoutWithTitle extends StatelessWidget {
  const CardLayoutWithTitle({
    super.key,
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return CardLayout(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colors.textSecondary.withValues(alpha: 0.8),
            ),
          ),
        ),
        ...children,
      ],
    );
  }
}

@AppThemePreview(name: '基础卡片', group: 'CardLayout')
Widget cardLayoutPreview() {
  return const CardLayout(
    children: [Text('第一行内容'), SizedBox(height: 8), Text('第二行内容')],
  );
}

@AppThemePreview(name: '带标题卡片', group: 'CardLayout')
Widget cardLayoutWithTitlePreview() {
  return const CardLayoutWithTitle(
    title: '账号信息',
    children: [
      ListTile(leading: Icon(Icons.person_outline), title: Text('用户名')),
      ListTile(leading: Icon(Icons.phone_outlined), title: Text('手机号')),
    ],
  );
}
