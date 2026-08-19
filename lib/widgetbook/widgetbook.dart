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
            WidgetbookComponent(
              name: 'MessageBubble',
              useCases: [
                WidgetbookUseCase(
                  name: '文本 - 对方',
                  builder: (_) => messageBubbleTextOtherPreview(),
                ),
                WidgetbookUseCase(
                  name: '文本 - 我（已读）',
                  builder: (_) => messageBubbleTextMinePreview(),
                ),
                WidgetbookUseCase(
                  name: '文本 - 我（发送失败）',
                  builder: (_) => messageBubbleTextFailedPreview(),
                ),
                WidgetbookUseCase(
                  name: '图片',
                  builder: (_) => messageBubbleImagePreview(),
                ),
                WidgetbookUseCase(
                  name: '引用',
                  builder: (_) => messageBubbleQuotePreview(),
                ),
                WidgetbookUseCase(
                  name: '合并转发',
                  builder: (_) => messageBubbleMergePreview(),
                ),
                WidgetbookUseCase(
                  name: '名片',
                  builder: (_) => messageBubbleCardPreview(),
                ),
                WidgetbookUseCase(
                  name: '位置',
                  builder: (_) => messageBubbleLocationPreview(),
                ),
                WidgetbookUseCase(
                  name: '系统消息',
                  builder: (_) => messageBubbleSystemPreview(),
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'ChatDetailAppBar',
              useCases: [
                WidgetbookUseCase(
                  name: '单聊在线',
                  builder: (_) => chatDetailAppBarPreview(),
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'AtMemberSuggestions',
              useCases: [
                WidgetbookUseCase(
                  name: '成员候选列表',
                  builder: (_) => atMemberSuggestionsPreview(),
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'RecordingOverlay',
              useCases: [
                WidgetbookUseCase(
                  name: '录音提示',
                  builder: (_) => recordingOverlayPreview(),
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'MessageList',
              useCases: [
                WidgetbookUseCase(
                  name: '混合内容消息流',
                  builder: (_) => messageListPreview(),
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'ChatListItem',
              useCases: [
                WidgetbookUseCase(
                  name: '单聊 - 普通',
                  builder: (_) => chatListItemNormalPreview(),
                ),
                WidgetbookUseCase(
                  name: '单聊 - 未读 5 条',
                  builder: (_) => chatListItemUnreadPreview(),
                ),
                WidgetbookUseCase(
                  name: '单聊 - 置顶',
                  builder: (_) => chatListItemPinnedPreview(),
                ),
                WidgetbookUseCase(
                  name: '单聊 - 草稿',
                  builder: (_) => chatListItemDraftPreview(),
                ),
                WidgetbookUseCase(
                  name: '群聊 - 未读 99+（免打扰）',
                  builder: (_) => chatListItemGroupPreview(),
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'MessageStatusIndicator',
              useCases: [
                WidgetbookUseCase(
                  name: '发送中',
                  builder: (_) => messageStatusSendingPreview(),
                ),
                WidgetbookUseCase(
                  name: '发送失败（可重试）',
                  builder: (_) => messageStatusFailedPreview(),
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'MessageSkeleton',
              useCases: [
                WidgetbookUseCase(
                  name: '骨架屏',
                  builder: (_) => messageSkeletonPreview(),
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'MessageSelectionTopBar',
              useCases: [
                WidgetbookUseCase(
                  name: '多选工具栏',
                  builder: (_) => messageSelectionBarPreview(),
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'QuotePreviewBar',
              useCases: [
                WidgetbookUseCase(
                  name: '引用预览栏',
                  builder: (_) => quotePreviewBarPreview(),
                ),
              ],
            ),
          ],
        ),
        WidgetbookCategory(
          name: '输入区',
          children: [
            WidgetbookComponent(
              name: 'ChatInput',
              useCases: [
                WidgetbookUseCase(
                  name: '单聊 - 默认',
                  builder: (_) => chatInputSinglePreview(),
                ),
                WidgetbookUseCase(
                  name: '群聊 - 带 @ 按钮',
                  builder: (_) => chatInputGroupPreview(),
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'AttachmentPanel',
              useCases: [
                WidgetbookUseCase(
                  name: '附件面板',
                  builder: (_) => attachmentPanelPreview(),
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'FormatToolbar',
              useCases: [
                WidgetbookUseCase(
                  name: '格式工具栏',
                  builder: (_) => formatToolbarPreview(),
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'MarkdownFormatBar',
              useCases: [
                WidgetbookUseCase(
                  name: 'Markdown 格式栏',
                  builder: (_) => markdownFormatBarPreview(),
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'EmojiPanel',
              useCases: [
                WidgetbookUseCase(
                  name: '表情面板',
                  builder: (_) => emojiPanelPreview(),
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'SettingsComponents',
              useCases: [
                WidgetbookUseCase(
                  name: '聊天设置卡片',
                  builder: (_) => settingsCardPreview(),
                ),
                WidgetbookUseCase(
                  name: '成员头像',
                  builder: (_) => settingsMemberAvatarPreview(),
                ),
              ],
            ),
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
