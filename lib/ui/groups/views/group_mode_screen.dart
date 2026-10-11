import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/models/group_mode.dart';
import '../../core/theme/app_icon_colors.dart';
import '../../core/theme/app_theme.dart';
import '../providers/group_provider.dart';

/// 群模式页（对齐飞书稿）：对话 / 话题 二选一，下方是对应形态的预览图。
///
/// 没有「确定」按钮：点选即写入建群状态，返回后创建页直接读同一份状态。
class GroupModeScreen extends ConsumerWidget {
  const GroupModeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final mode = ref.watch(createGroupProvider).mode;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('群模式'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _ModeToggle(
            mode: mode,
            onChanged: (value) =>
                ref.read(createGroupProvider.notifier).setMode(value),
          ),
          const SizedBox(height: 20),
          Text(
            mode.isTopic ? '发布话题，在群内开展讨论' : '根据发送的先后顺序展现信息内容',
            style: TextStyle(fontSize: 16, color: colors.textSecondary),
          ),
          const SizedBox(height: 16),
          _ModePreview(mode: mode),
          if (mode.isTopic) ...[
            const SizedBox(height: 12),
            Text(
              '话题模式的服务端能力待接入，当前先记录选择',
              style: TextStyle(
                fontSize: AppTheme.fontSizeCaption,
                color: colors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 两枚胶囊的分段控件：选中＝主色实心 + 白字，未选中＝浅灰底 + 深字。
class _ModeToggle extends StatelessWidget {
  const _ModeToggle({required this.mode, required this.onChanged});

  final GroupMode mode;
  final ValueChanged<GroupMode> onChanged;

  static const double _height = 44;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _buildSegment(context, GroupMode.chat, '对话')),
        const SizedBox(width: AppTheme.spacingSm),
        Expanded(child: _buildSegment(context, GroupMode.topic, '话题')),
      ],
    );
  }

  Widget _buildSegment(BuildContext context, GroupMode value, String label) {
    final colors = context.appColors;
    final selected = value == mode;
    return GestureDetector(
      key: ValueKey('group_mode_${value.name}'),
      onTap: () => onChanged(value),
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: _height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? colors.primary : colors.segmentTrack,
          borderRadius: BorderRadius.circular(_height / 2),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? colors.onPrimary : colors.textPrimary,
          ),
        ),
      ),
    );
  }
}

/// 模式预览图：用真实组件拼的示意图（非图片资源）。
class _ModePreview extends StatelessWidget {
  const _ModePreview({required this.mode});

  final GroupMode mode;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(color: colors.divider),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          child: mode.isTopic
              ? const _TopicModePreview()
              : const _ChatModePreview(),
        ),
      ),
    );
  }
}

// ==================== 对话模式预览 ====================

typedef _PreviewMessage = ({String name, String text, Color color, bool mine});

const List<_PreviewMessage> _chatPreviewMessages = [
  (
    name: '杰森',
    text: '大家好，我是新来的同学，很高兴加入团队！',
    color: AppIconColors.orange,
    mine: true,
  ),
  (name: '李毅', text: '欢迎欢迎！', color: AppIconColors.crimson, mine: false),
  (
    name: '迈克',
    text: '中午大家一起吃个饭吧，互相熟悉一下',
    color: AppIconColors.violet,
    mine: false,
  ),
  (
    name: '艾米',
    text: '欢迎！之后如果工作方面有什么问题，随时在群里问~',
    color: AppIconColors.purple,
    mine: false,
  ),
];

class _ChatModePreview extends StatelessWidget {
  const _ChatModePreview();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            children: [
              Icon(
                Icons.arrow_back_ios_new,
                size: 16,
                color: colors.textPrimary,
              ),
              Expanded(
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '团队沟通群',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                        ),
                      ),
                      Icon(
                        Icons.arrow_right,
                        size: 16,
                        color: colors.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
              Icon(
                Icons.videocam_outlined,
                size: 18,
                color: colors.textPrimary,
              ),
              const SizedBox(width: 10),
              Icon(Icons.more_horiz, size: 18, color: colors.textPrimary),
            ],
          ),
        ),
        Divider(height: 1, color: colors.divider),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 4),
          child: Column(
            children: [
              for (final message in _chatPreviewMessages)
                _buildMessage(context, message),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: colors.inputBackground,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: Row(
              children: [
                Text(
                  '发给 团队沟通群',
                  style: TextStyle(fontSize: 13, color: colors.textSecondary),
                ),
                const Spacer(),
                Icon(Icons.open_in_full, size: 16, color: colors.textSecondary),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMessage(BuildContext context, _PreviewMessage message) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PreviewAvatar(name: message.name, color: message.color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.name,
                  style: TextStyle(
                    fontSize: AppTheme.fontSizeCaption,
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: message.mine
                        ? colors.bubbleOtherSingleChat
                        : colors.bubbleOther,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                  child: Text(
                    message.text,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: colors.bubbleOtherText,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== 话题模式预览 ====================

typedef _PreviewTopicReply = ({String name, String text});
typedef _PreviewTopic = ({
  String name,
  String time,
  Color color,
  String text,
  String earlier,
  List<_PreviewTopicReply> replies,
});

const List<_PreviewTopic> _topicPreviewTopics = [
  (
    name: '李毅',
    time: '5月25日 10:20',
    color: AppIconColors.crimson,
    text: '发现官网上的地址信息还是旧的，需要相关同学更新一下',
    earlier: '查看更早 1 条回复',
    replies: [(name: '安娜', text: '收到，尽快处理')],
  ),
  (
    name: '杰森',
    time: '5月17日 19:32',
    color: AppIconColors.orange,
    text: '新功能的文章链接怎么失效了？',
    earlier: '',
    replies: [
      (name: '刘明', text: '内容需修改，暂时下线了'),
      (name: '陈晨', text: '应该今晚就能改完并重新发布'),
    ],
  ),
];

class _TopicModePreview extends StatelessWidget {
  const _TopicModePreview();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 群主题色头部
        Container(
          color: AppIconColors.teal,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.arrow_back_ios_new,
                    size: 14,
                    color: colors.onPrimary,
                  ),
                  const Spacer(),
                  Icon(Icons.more_horiz, size: 16, color: colors.onPrimary),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const _PreviewAvatar(
                    name: '内容反馈群',
                    color: AppIconColors.sky,
                    radius: 18,
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '内容反馈群',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: colors.onPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 12,
                            color: colors.onPrimary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '568',
                            style: TextStyle(
                              fontSize: AppTheme.fontSizeCaption,
                              color: colors.onPrimary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                      border: Border.all(
                        color: colors.onPrimary.withValues(alpha: 0.7),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.ios_share,
                          size: 12,
                          color: colors.onPrimary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '分享',
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.onPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // 全部 / 我订阅的
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
          child: Row(
            children: [
              Text(
                '全部',
                style: TextStyle(fontSize: 14, color: colors.textSecondary),
              ),
              const SizedBox(width: 24),
              Column(
                children: [
                  Text(
                    '我订阅的',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colors.primary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(width: 42, height: 2, color: colors.primary),
                ],
              ),
            ],
          ),
        ),
        Divider(height: 1, color: colors.divider),
        for (final topic in _topicPreviewTopics) _buildTopic(context, topic),
      ],
    );
  }

  Widget _buildTopic(BuildContext context, _PreviewTopic topic) {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.divider)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _PreviewAvatar(name: topic.name, color: topic.color),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    topic.name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                  Text(
                    topic.time,
                    style: TextStyle(
                      fontSize: AppTheme.fontSizeCaption,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Icon(Icons.more_horiz, size: 16, color: colors.textSecondary),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            topic.text,
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: colors.surfaceMuted,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (topic.earlier.isNotEmpty) ...[
                  Text(
                    topic.earlier,
                    style: TextStyle(
                      fontSize: AppTheme.fontSizeCaption,
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                for (final reply in topic.replies)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '${reply.name}：',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          TextSpan(text: reply.text),
                        ],
                      ),
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final icon in const [
                Icons.thumb_up_alt_outlined,
                Icons.mode_comment_outlined,
                Icons.ios_share,
                Icons.bookmark_add_outlined,
              ])
                Expanded(
                  child: Icon(icon, size: 16, color: colors.textSecondary),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 预览图里的小头像：装饰色底 + 名字首字。
class _PreviewAvatar extends StatelessWidget {
  const _PreviewAvatar({
    required this.name,
    required this.color,
    this.radius = 13,
  });

  final String name;
  final Color color;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: color,
      child: Text(
        name.substring(0, 1),
        style: TextStyle(
          fontSize: radius * 0.85,
          color: context.appColors.onPrimary,
        ),
      ),
    );
  }
}
