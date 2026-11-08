import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/chat_session_type.dart';
import '../../../domain/models/topic.dart';
import '../../chat/mappers/message_display.dart';
import '../../chat/providers/message_service_provider.dart';
import '../../contacts/views/contact_picker_screen.dart';
import '../../contacts/widgets/contact_pick_item.dart';
import '../../core/theme/app_theme.dart';
import '../providers/topic_provider.dart';
import '../utils/topic_link.dart';

Future<void> showTopicShareSheet({
  required BuildContext context,
  required WidgetRef ref,
  required Topic topic,
  required String groupName,
}) async {
  final action = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: context.appColors.surface,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.link),
            title: const Text('复制话题链接'),
            subtitle: const Text('链接只对群成员有效'),
            onTap: () => Navigator.of(sheetContext).pop('copy'),
          ),
          ListTile(
            leading: const Icon(Icons.send_outlined),
            title: const Text('转发到会话'),
            subtitle: const Text('发送包含根话题和全部回复快照的卡片'),
            onTap: () => Navigator.of(sheetContext).pop('share'),
          ),
        ],
      ),
    ),
  );
  if (!context.mounted || action == null) return;

  if (action == 'copy') {
    final card = buildTopicShareCard(topic: topic, groupName: groupName);
    await Clipboard.setData(ClipboardData(text: card.link));
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('话题链接已复制')));
    }
    return;
  }

  final liveTopic = ref.read(topicRepositoryProvider);
  final TopicDetail detail;
  final ({List<TopicShareReply> replies, bool complete}) snapshot;
  try {
    detail = await liveTopic.getTopic(
      groupId: topic.groupId,
      topicId: topic.topicId,
    );
    snapshot = await _loadReplySnapshot(ref, detail.topic);
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('生成话题转发内容失败: $e')));
    }
    return;
  }
  if (!context.mounted) return;
  final rootText = detail.rootMessage?.displayText.trim() ?? '';
  final card = buildTopicShareCard(
    topic: detail.topic,
    groupName: groupName,
    title: rootText.isEmpty ? null : rootText,
    replies: snapshot.replies,
    snapshotComplete: snapshot.complete,
  );

  final targets = await Navigator.of(context).push<List<ContactPickItem>>(
    MaterialPageRoute(
      builder: (_) =>
          const ContactPickerScreen(multiSelect: true, title: '转发话题'),
    ),
  );
  if (!context.mounted || targets == null || targets.isEmpty) return;

  final repository = ref.read(messageRepositoryProvider);
  final messages = ref.read(messageServiceProvider.notifier);
  var sent = 0;
  for (final target in targets) {
    try {
      final sessionType = target.isGroup
          ? ChatSessionType.writeGroupChat
          : ChatSessionType.singleChat;
      final conversationId = await repository.getConversationIdBySessionType(
        sourceId: target.id,
        sessionType: sessionType,
      );
      final pending = await messages.sendCustomMessage(
        data: jsonEncode(card.toJson()),
        extension: 'openim_topic',
        description: '${card.groupName}: ${card.title}',
        sourceId: target.id,
        sessionType: sessionType,
        conversationId: conversationId,
      );
      await pending.done;
      sent++;
    } catch (_) {
      // 多个目标逐个发送，单个失败不阻断其余目标。
    }
  }
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          sent == targets.length
              ? '话题已转发到 $sent 个会话'
              : '已转发 $sent/${targets.length} 个会话',
        ),
      ),
    );
  }
}

Future<({List<TopicShareReply> replies, bool complete})> _loadReplySnapshot(
  WidgetRef ref,
  Topic topic,
) async {
  const pageSize = 100;
  final repository = ref.read(topicRepositoryProvider);
  final replies = <TopicShareReply>[];
  final seen = <String>{};
  var beforeSeq = 0;
  var complete = true;

  while (true) {
    final page = await repository.getReplies(
      topicId: topic.topicId,
      beforeSeq: beforeSeq,
      count: pageSize,
    );
    for (final item in page.replies) {
      if (item.revoked) continue;
      if (!seen.add(item.message.clientMsgId)) continue;
      final text = item.message.displayText.trim();
      replies.add(
        TopicShareReply(
          seq: item.message.seq,
          senderName: item.message.senderNickname.isEmpty
              ? '成员'
              : item.message.senderNickname,
          content: text.isEmpty ? '[消息]' : text,
          sendTime: item.message.sendTime,
        ),
      );
    }
    if (!page.hasMore) {
      complete = true;
      break;
    }
    if (page.nextBeforeSeq <= 0 || page.nextBeforeSeq == beforeSeq) {
      complete = false;
      break;
    }
    beforeSeq = page.nextBeforeSeq;
  }
  replies.sort((left, right) => left.seq.compareTo(right.seq));
  return (replies: replies, complete: complete);
}
