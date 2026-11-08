import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../domain/models/chat_message.dart';
import '../../../domain/models/topic.dart';
import '../../../domain/models/user.dart';
import '../../../application/chat/topic_event_revision_provider.dart';
import '../../../providers/im_providers.dart';
import '../../chat/mappers/message_display.dart';
import '../../chat/providers/conversation_provider.dart';
import '../../chat/providers/message_provider.dart';
import '../../chat/providers/message_service_provider.dart';
import '../../chat/widgets/bubble/message_bubble.dart';
import '../../core/theme/app_theme.dart';
import '../../groups/providers/group_provider.dart';
import '../providers/topic_provider.dart';
import '../widgets/topic_chat_composer.dart';
import '../widgets/topic_common_dialogs.dart';
import '../widgets/topic_share_sheet.dart';

class TopicDetailScreen extends ConsumerStatefulWidget {
  const TopicDetailScreen({
    super.key,
    required this.groupId,
    required this.topicId,
  });

  final String groupId;
  final String topicId;

  @override
  ConsumerState<TopicDetailScreen> createState() => _TopicDetailScreenState();
}

class _TopicDetailScreenState extends ConsumerState<TopicDetailScreen> {
  final ValueNotifier<double> _composerHeight = ValueNotifier(0);
  String? _lastMessageId;
  ChatMessage? _quotedMessage;

  TopicDetailArgs get _args =>
      (groupId: widget.groupId, topicId: widget.topicId);

  String get _conversationId => 'sg_${widget.groupId}';

  @override
  void initState() {
    super.initState();
    ref.listenManual(messagesProvider(_conversationId), (_, messages) {
      final topicMessages = messages.where(
        (message) => message.topicId == widget.topicId,
      );
      if (topicMessages.isEmpty) return;
      final latest = topicMessages.reduce(
        (left, right) => left.seq >= right.seq ? left : right,
      );
      if (latest.clientMsgId == _lastMessageId) return;
      _lastMessageId = latest.clientMsgId;
      ref.read(topicDetailProvider(_args).notifier).load();
    });
    ref.listenManual(topicEventRevisionProvider, (_, __) {
      ref.read(topicDetailProvider(_args).notifier).load();
    });
  }

  @override
  void dispose() {
    _composerHeight.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final state = ref.watch(topicDetailProvider(_args));
    final topic = state.topic;
    final currentUserId = ref.watch(
      messageServiceProvider.select((service) => service.currentUserId),
    );
    final conversation = ref.watch(conversationByIdProvider(_conversationId));
    final canReply =
        topic?.state != TopicState.closed && topic?.state != TopicState.revoked;
    final maxInputHeight = (MediaQuery.sizeOf(context).height - kToolbarHeight)
        .clamp(0.0, double.infinity)
        .toDouble();
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        title: const Text('话题'),
        actions: [
          if (topic != null)
            IconButton(
              tooltip: '转发话题',
              onPressed: () => showTopicShareSheet(
                context: context,
                ref: ref,
                topic: topic,
                groupName: conversation?.showName ?? '话题群',
              ),
              icon: const Icon(Icons.ios_share),
            ),
          if (topic != null)
            PopupMenuButton<String>(
              onSelected: (value) => _action(value),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'subscribe',
                  child: Text(topic.subscribed ? '取消订阅' : '订阅话题'),
                ),
                const PopupMenuItem(value: 'unread', child: Text('标为未读')),
                PopupMenuItem(
                  value: 'pin',
                  child: Text(topic.pinned ? '取消 Pin' : 'Pin'),
                ),
                PopupMenuItem(
                  value: 'groupPin',
                  child: Text(topic.groupPinned ? '取消置顶' : '置顶话题'),
                ),
                PopupMenuItem(
                  value: 'state',
                  child: Text(
                    topic.state == TopicState.closed ? '重开话题' : '关闭话题',
                  ),
                ),
                const PopupMenuItem(value: 'revoke', child: Text('撤回话题')),
                const PopupMenuItem(value: 'task', child: Text('添加任务')),
                if (topic.creatorId == currentUserId &&
                    const {101, 106, 117, 118}.contains(topic.rootContentType))
                  const PopupMenuItem(value: 'edit', child: Text('编辑话题')),
              ],
            ),
        ],
      ),
      body: state.isLoading && topic == null
          ? const Center(child: CircularProgressIndicator())
          : state.error != null && topic == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_outline, size: 40),
                    const SizedBox(height: 12),
                    Text(state.error!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () =>
                          ref.read(topicDetailProvider(_args).notifier).load(),
                      child: const Text('重试'),
                    ),
                  ],
                ),
              ),
            )
          : Stack(
              children: [
                ValueListenableBuilder<double>(
                  valueListenable: _composerHeight,
                  builder: (context, composerHeight, _) => ListView(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      16,
                      16,
                      canReply ? composerHeight + 20 : 20,
                    ),
                    children: [
                      if (state.rootMessage != null)
                        _MessageBlock(
                          message: state.rootMessage!,
                          root: true,
                          onLongPress: _showMessageActions,
                        ),
                      if (topic?.edited == true)
                        Padding(
                          padding: const EdgeInsets.only(left: 52, top: 2),
                          child: Text(
                            '作者已编辑',
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      if (topic != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              for (final emoji in const ['👍', '❤️', '🎉'])
                                FilterChip(
                                  selected: topic.reactions.hasReaction(emoji),
                                  label: Text(_reactionLabel(topic, emoji)),
                                  onSelected: (_) => ref
                                      .read(topicDetailProvider(_args).notifier)
                                      .toggleReaction(emoji),
                                ),
                            ],
                          ),
                        ),
                      if (topic?.state == TopicState.closed)
                        const _Banner(text: '话题已关闭，暂不能回复'),
                      if (topic?.state == TopicState.revoked)
                        const _Banner(text: '话题已撤回'),
                      if (state.tasks.isNotEmpty || state.taskError != null)
                        _TopicTaskSection(
                          tasks: state.tasks,
                          error: state.taskError,
                          onRetry: () => ref
                              .read(topicDetailProvider(_args).notifier)
                              .reloadTasks(),
                          onStatusChanged: (task, status) => ref
                              .read(topicDetailProvider(_args).notifier)
                              .changeTaskStatus(task, status),
                        ),
                      if (state.replies.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 18, bottom: 4),
                          child: Row(
                            children: [
                              Text(
                                '${topic?.replyCount ?? state.replies.length} 条话题回复',
                                style: TextStyle(
                                  color: colors.textSecondary,
                                  fontSize: AppTheme.fontSizeSmall,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Divider(
                                  height: 1,
                                  thickness: 0.5,
                                  color: colors.divider,
                                ),
                              ),
                            ],
                          ),
                        ),
                      for (final reply in state.replies)
                        _MessageBlock(
                          message: reply.message,
                          root: false,
                          onLongPress: _showMessageActions,
                        ),
                      if (state.hasMore)
                        TextButton(
                          onPressed: () => ref
                              .read(topicDetailProvider(_args).notifier)
                              .loadMore(),
                          child: Text(state.isLoadingMore ? '加载中…' : '加载更早回复'),
                        ),
                    ],
                  ),
                ),
                if (canReply)
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
                          topicId: widget.topicId,
                          quotedMessage: _quotedMessage,
                          onClearQuote: () {
                            if (mounted) {
                              setState(() => _quotedMessage = null);
                            }
                          },
                          heightNotifier: _composerHeight,
                          sendToLabel: '回复话题',
                          onSent: (_) {
                            unawaited(
                              Future<void>.delayed(
                                const Duration(milliseconds: 250),
                                () => ref
                                    .read(topicDetailProvider(_args).notifier)
                                    .load(),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Future<void> _action(String value) async {
    final notifier = ref.read(topicDetailProvider(_args).notifier);
    try {
      switch (value) {
        case 'subscribe':
          await notifier.toggleSubscription();
        case 'unread':
          await notifier.markUnread();
          if (mounted) Navigator.of(context).pop();
        case 'pin':
          await notifier.togglePinned();
        case 'groupPin':
          await notifier.toggleGroupPinned();
        case 'state':
          await notifier.closeOrReopen();
        case 'revoke':
          await notifier.revoke();
        case 'task':
          await _addTask();
        case 'edit':
          await _editTopic();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('操作失败: $e')));
      }
    }
  }

  String _reactionLabel(Topic topic, String emoji) {
    final count =
        topic.reactions.counts
            .where((reaction) => reaction.emoji == emoji)
            .firstOrNull
            ?.count ??
        0;
    return count > 0 ? '$emoji $count' : emoji;
  }

  Future<void> _showMessageActions(ChatMessage message) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: context.appColors.surface,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.reply_rounded),
              title: const Text('引用回复'),
              onTap: () => Navigator.of(sheetContext).pop('quote'),
            ),
            ListTile(
              leading: const Icon(Icons.copy_rounded),
              title: const Text('复制内容'),
              onTap: () => Navigator.of(sheetContext).pop('copy'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    switch (action) {
      case 'quote':
        setState(() => _quotedMessage = message);
      case 'copy':
        await Clipboard.setData(ClipboardData(text: message.displayText));
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('内容已复制')));
        }
    }
  }

  Future<void> _addTask() async {
    final memberProvider = groupMemberProvider(widget.groupId);
    if (ref.read(memberProvider).members.isEmpty) {
      await ref.read(memberProvider.notifier).loadMembers();
    }
    if (!mounted) return;
    final members = ref.read(memberProvider).members;
    if (members.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('暂无可分配的群成员')));
      return;
    }
    final result = await showCreateTopicTaskDialog(
      context: context,
      members: members,
    );
    if (result == null || !mounted) return;
    try {
      await ref
          .read(topicDetailProvider(_args).notifier)
          .createTask(
            title: result.title,
            description: result.description,
            assigneeId: result.assigneeId,
            dueAt: result.dueAt,
            priority: result.priority,
          );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('任务已创建')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('创建任务失败: $e')));
      }
    }
  }

  Future<void> _editTopic() async {
    final state = ref.read(topicDetailProvider(_args));
    if (state.topic == null) return;
    final text = await showEditTopicDialog(
      context: context,
      initialText: state.rootMessage?.displayText ?? state.topic!.rootPreview,
    );
    if (text == null || !mounted) return;
    try {
      await ref.read(topicDetailProvider(_args).notifier).editRoot(text);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('编辑话题失败: $e')));
      }
    }
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.appColors.background,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Text(text, textAlign: TextAlign.center),
    );
  }
}

class _TopicTaskSection extends StatelessWidget {
  const _TopicTaskSection({
    required this.tasks,
    required this.error,
    required this.onRetry,
    required this.onStatusChanged,
  });

  final List<TopicTask> tasks;
  final String? error;
  final Future<void> Function() onRetry;
  final Future<void> Function(TopicTask task, TopicTaskStatus status)
  onStatusChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.task_alt, size: 18),
              const SizedBox(width: 6),
              Text(
                '关联任务 ${tasks.length}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (error != null)
            Row(
              children: [
                Expanded(
                  child: Text(
                    error!,
                    style: TextStyle(color: colors.textSecondary, fontSize: 12),
                  ),
                ),
                TextButton(onPressed: onRetry, child: const Text('重试')),
              ],
            ),
          for (final task in tasks)
            Row(
              children: [
                Checkbox(
                  value: task.status == TopicTaskStatus.done,
                  onChanged: (checked) => onStatusChanged(
                    task,
                    checked == true
                        ? TopicTaskStatus.done
                        : TopicTaskStatus.todo,
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: TextStyle(
                          color: colors.textPrimary,
                          decoration: task.status == TopicTaskStatus.done
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      Text(
                        '${task.assigneeNickname.isEmpty ? task.assigneeId : task.assigneeNickname}'
                        ' · ${_priorityLabel(task.priority)}'
                        '${task.dueAt > 0 ? ' · ${DateFormat('MM-dd HH:mm').format(DateTime.fromMillisecondsSinceEpoch(task.dueAt))}' : ''}',
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<TopicTaskStatus>(
                  tooltip: '更新任务状态',
                  onSelected: (status) => onStatusChanged(task, status),
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: TopicTaskStatus.todo,
                      child: Text('恢复待办'),
                    ),
                    PopupMenuItem(
                      value: TopicTaskStatus.done,
                      child: Text('标记完成'),
                    ),
                    PopupMenuItem(
                      value: TopicTaskStatus.canceled,
                      child: Text('取消任务'),
                    ),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }

  static String _priorityLabel(TopicTaskPriority priority) =>
      switch (priority) {
        TopicTaskPriority.low => '低优先级',
        TopicTaskPriority.normal => '普通',
        TopicTaskPriority.high => '高优先级',
        TopicTaskPriority.urgent => '紧急',
      };
}

class _MessageBlock extends ConsumerWidget {
  const _MessageBlock({
    required this.message,
    required this.root,
    required this.onLongPress,
  });

  final ChatMessage message;
  final bool root;
  final ValueChanged<ChatMessage> onLongPress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserId = ref.watch(
      messageServiceProvider.select((state) => state.currentUserId),
    );
    final name = message.senderNickname.isEmpty
        ? message.sendId
        : message.senderNickname;
    return Padding(
      padding: EdgeInsets.only(top: root ? 4 : 8, bottom: 4),
      child: MessageBubble(
        message: message,
        otherUser: User(
          id: message.sendId,
          name: name.isEmpty ? '成员' : name,
          avatar: message.senderFaceUrl.isEmpty ? null : message.senderFaceUrl,
        ),
        currentUserId: currentUserId,
        maxBubbleWidth: MediaQuery.sizeOf(context).width * 0.78,
        flatThread: true,
        onLongPress: onLongPress,
        onPlayAudio: (source) async {
          final ok = await ref.read(audioPlayerServiceProvider).play(source);
          if (!ok && context.mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('语音播放失败：文件已失效或网络不可用')));
          }
        },
      ),
    );
  }
}
