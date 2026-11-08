import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/chat_message.dart';
import '../../core/theme/app_theme.dart';
import '../providers/topic_provider.dart';
import '../widgets/topic_chat_composer.dart';

class TopicComposeScreen extends ConsumerStatefulWidget {
  const TopicComposeScreen({super.key, required this.groupId});

  final String groupId;

  @override
  ConsumerState<TopicComposeScreen> createState() => _TopicComposeScreenState();
}

class _TopicComposeScreenState extends ConsumerState<TopicComposeScreen> {
  final ValueNotifier<double> _composerHeight = ValueNotifier(0);
  bool _subscribeAfterPublish = true;
  bool _finished = false;

  String get _conversationId => 'sg_${widget.groupId}';

  @override
  void dispose() {
    _composerHeight.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final maxInputHeight = (MediaQuery.sizeOf(context).height - kToolbarHeight)
        .clamp(0.0, double.infinity)
        .toDouble();
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        title: const Text('发布话题'),
      ),
      body: Stack(
        children: [
          ValueListenableBuilder<double>(
            valueListenable: _composerHeight,
            builder: (context, height, _) => ListView(
              padding: EdgeInsets.fromLTRB(16, 16, 16, height + 24),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '发布一个可独立讨论的话题',
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '支持 Markdown、@成员、图片、视频、语音、文件、位置和名片。'
                        '发布内容会作为话题根消息，后续回复进入同一条讨论。',
                        style: TextStyle(color: colors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  ),
                  child: SwitchListTile.adaptive(
                    value: _subscribeAfterPublish,
                    onChanged: (value) =>
                        setState(() => _subscribeAfterPublish = value),
                    title: const Text('关注这个话题'),
                    subtitle: const Text('关注后可在“我订阅的”中快速找到'),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxInputHeight),
              child: Builder(
                builder: (context) => TopicChatComposer(
                  groupId: widget.groupId,
                  conversationId: _conversationId,
                  heightNotifier: _composerHeight,
                  sendToLabel: '发布到话题群',
                  onSent: (message) {
                    unawaited(_finish(message));
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _finish(ChatMessage message) async {
    if (_finished || !mounted) return;
    _finished = true;
    if (!_subscribeAfterPublish) {
      try {
        await ref
            .read(topicRepositoryProvider)
            .setSubscription(topicId: message.topicId, subscribed: false);
      } catch (_) {
        // 创建者默认关注失败不影响根消息发布；用户仍可在话题详情取消关注。
      }
    }
    if (mounted) Navigator.of(context).pop(true);
  }
}
