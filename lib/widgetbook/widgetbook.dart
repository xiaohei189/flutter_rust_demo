import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

import '../ui/chat/widgets/composer/attachment_panel.dart';
import '../ui/chat/widgets/composer/at_member_suggestions.dart';
import '../ui/chat/widgets/composer/chat_input_preview.dart';
import '../ui/chat/widgets/composer/recording_overlay.dart';
import '../ui/chat/widgets/list/chat_list_item.dart';
import '../ui/chat/widgets/composer/emoji_panel.dart';
import '../ui/chat/widgets/composer/format_toolbar.dart';
import '../ui/chat/widgets/composer/markdown_format_bar.dart';
import '../ui/chat/widgets/bubble/message_bubble.dart';
import '../ui/chat/widgets/list/message_list.dart';
import '../ui/chat/widgets/menu/message_selection_bar.dart';
import '../ui/chat/widgets/list/message_skeleton.dart';
import '../ui/chat/widgets/shared/message_status_indicator.dart';
import '../ui/chat/widgets/composer/quote_preview_bar.dart';
import '../ui/chat/widgets/shared/chat_detail_app_bar.dart';
import '../ui/chat/widgets/settings_components.dart';
import '../ui/chat/widgets/list/unread_count_view.dart';
import '../ui/contacts/widgets/contact_picker_list.dart';
import '../ui/core/theme/app_theme.dart';
import '../ui/core/widgets/card_layout.dart';
import '../ui/core/widgets/section_title.dart';
import '../ui/core/widgets/segmented_toggle.dart';
import '../ui/core/widgets/state_views.dart';
import '../ui/core/widgets/user_avatar.dart';
import '../ui/groups/widgets/group_member_section.dart';

/// 组件画廊入口（Widgetbook）。
///
/// 启动方式：
/// ```bash
/// flutter run -d windows -t lib/widgetbook/widgetbook.dart
/// ```
///
/// 左侧组件树选择组件，右侧实时渲染，顶部可切换明/暗主题。
void main() {
  runApp(
    Widgetbook.material(
      lightTheme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      directories: [
        WidgetbookCategory(
          name: '消息',
          children: [
        ],
        ),
        WidgetbookCategory(
          name: '通用组件',
          children: [
            WidgetbookComponent(
              name: 'CardLayout',
              useCases: [
                WidgetbookUseCase(
                  name: '基础卡片',
                  builder: (_) => cardLayoutPreview(),
                ),
                WidgetbookUseCase(
                  name: '带标题卡片',
                  builder: (_) => cardLayoutWithTitlePreview(),
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'SectionTitle',
              useCases: [
                WidgetbookUseCase(
                  name: '基础标题',
                  builder: (_) => sectionTitlePreview(),
                ),
                WidgetbookUseCase(
                  name: '带图标标题',
                  builder: (_) => sectionTitleWithIconPreview(),
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'SegmentedToggle',
              useCases: [
                WidgetbookUseCase(
                  name: '两段 - 选中第一项',
                  builder: (_) => segmentedToggleTwoFirstPreview(),
                ),
                WidgetbookUseCase(
                  name: '两段 - 选中第二项',
                  builder: (_) => segmentedToggleTwoSecondPreview(),
                ),
                WidgetbookUseCase(
                  name: '三段 - 选中中间',
                  builder: (_) => segmentedToggleThreePreview(),
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'UnreadCountView',
              useCases: [
                WidgetbookUseCase(
                  name: '未读数 5',
                  builder: (_) => unreadCountViewNumberPreview(),
                ),
                WidgetbookUseCase(
                  name: '未读数 99+',
                  builder: (_) => unreadCountViewMaxPreview(),
                ),
                WidgetbookUseCase(
                  name: '未读数 0（隐藏）',
                  builder: (_) => unreadCountViewZeroPreview(),
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'StateViews',
              useCases: [
                WidgetbookUseCase(
                  name: '空状态',
                  builder: (_) => emptyStatePreview(),
                ),
                WidgetbookUseCase(
                  name: '错误状态',
                  builder: (_) => errorStatePreview(),
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'UserAvatar',
              useCases: [
                WidgetbookUseCase(
                  name: '默认头像',
                  builder: (_) => userAvatarDefaultPreview(),
                ),
              ],
            ),
          ],
        ),
        WidgetbookCategory(
          name: '联系人 / 群组',
          children: [
            WidgetbookComponent(
              name: 'ContactPickerList',
              useCases: [
                WidgetbookUseCase(
                  name: '联系人选择列表（多选）',
                  builder: (_) => contactPickerListPreview(),
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'GroupMemberSection',
              useCases: [
                WidgetbookUseCase(
                  name: '群成员分区',
                  builder: (_) => groupMemberSectionPreview(),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  );
}

