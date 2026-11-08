import 'chat_message.dart';
import 'group_mode.dart';

enum TopicState {
  open,
  closed,
  revoked;

  static TopicState parse(Object? value) {
    final text = value?.toString() ?? '';
    if (value == 2 || text == 'TOPIC_STATE_CLOSED' || text == 'closed') {
      return TopicState.closed;
    }
    if (value == 3 || text == 'TOPIC_STATE_REVOKED' || text == 'revoked') {
      return TopicState.revoked;
    }
    return TopicState.open;
  }

  int get wireValue => switch (this) {
    TopicState.open => 1,
    TopicState.closed => 2,
    TopicState.revoked => 3,
  };
}

enum TopicTab {
  all,
  subscribed;

  int get wireValue => switch (this) {
    TopicTab.all => 0,
    TopicTab.subscribed => 1,
  };
}

enum TopicTaskStatus {
  todo,
  done,
  canceled;

  static TopicTaskStatus parse(Object? value) {
    final text = value?.toString() ?? '';
    if (value == 2 || text == 'TOPIC_TASK_STATUS_DONE' || text == 'done') {
      return TopicTaskStatus.done;
    }
    if (value == 3 ||
        text == 'TOPIC_TASK_STATUS_CANCELED' ||
        text == 'canceled') {
      return TopicTaskStatus.canceled;
    }
    return TopicTaskStatus.todo;
  }

  int get wireValue => switch (this) {
    TopicTaskStatus.todo => 1,
    TopicTaskStatus.done => 2,
    TopicTaskStatus.canceled => 3,
  };
}

enum TopicTaskPriority {
  low,
  normal,
  high,
  urgent;

  static TopicTaskPriority parse(Object? value) {
    final wire = value is num ? value.toInt() : 2;
    return switch (wire) {
      1 => TopicTaskPriority.low,
      3 => TopicTaskPriority.high,
      4 => TopicTaskPriority.urgent,
      _ => TopicTaskPriority.normal,
    };
  }

  int get wireValue => switch (this) {
    TopicTaskPriority.low => 1,
    TopicTaskPriority.normal => 2,
    TopicTaskPriority.high => 3,
    TopicTaskPriority.urgent => 4,
  };
}

enum TopicFeedItemType {
  topic,
  system;

  static TopicFeedItemType parse(Object? value) {
    final text = value?.toString() ?? '';
    return value == 1 || text == 'TOPIC_FEED_ITEM_TOPIC' || text == 'topic'
        ? TopicFeedItemType.topic
        : TopicFeedItemType.system;
  }
}

class TopicUserState {
  final String userId;
  final bool subscribed;
  final int lastReadSeq;
  final int updatedAt;
  final bool groupPinnedHidden;

  const TopicUserState({
    required this.userId,
    required this.subscribed,
    required this.lastReadSeq,
    required this.updatedAt,
    this.groupPinnedHidden = false,
  });

  factory TopicUserState.fromJson(Map<String, dynamic> json) {
    return TopicUserState(
      userId: json['userID']?.toString() ?? '',
      subscribed: json['subscribed'] == true,
      lastReadSeq: _int(json['lastReadSeq']),
      updatedAt: _int(json['updatedAt']),
      groupPinnedHidden: json['groupPinnedHidden'] == true,
    );
  }
}

class TopicReplyPreview {
  final String clientMsgId;
  final int seq;
  final String sendId;
  final String senderNickname;
  final String senderFaceUrl;
  final String content;
  final int contentType;
  final int sendTime;

  const TopicReplyPreview({
    required this.clientMsgId,
    required this.seq,
    required this.sendId,
    required this.senderNickname,
    required this.senderFaceUrl,
    required this.content,
    required this.contentType,
    required this.sendTime,
  });

  factory TopicReplyPreview.fromJson(Map<String, dynamic> json) {
    return TopicReplyPreview(
      clientMsgId: json['clientMsgID']?.toString() ?? '',
      seq: _int(json['seq']),
      sendId: json['sendID']?.toString() ?? '',
      senderNickname: json['senderNickname']?.toString() ?? '',
      senderFaceUrl: json['senderFaceURL']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      contentType: _int(json['contentType']),
      sendTime: _int(json['sendTime']),
    );
  }
}

class TopicReactionCount {
  final String emoji;
  final int count;

  const TopicReactionCount({required this.emoji, required this.count});

  factory TopicReactionCount.fromJson(Map<String, dynamic> json) {
    return TopicReactionCount(
      emoji: json['emoji']?.toString() ?? '',
      count: _int(json['count']),
    );
  }
}

class TopicReactionState {
  final List<TopicReactionCount> counts;
  final List<String> myReactions;

  const TopicReactionState({
    this.counts = const [],
    this.myReactions = const [],
  });

  factory TopicReactionState.fromJson(Map<String, dynamic> json) {
    return TopicReactionState(
      counts: _maps(
        json['counts'],
      ).map(TopicReactionCount.fromJson).toList(growable: false),
      myReactions: json['myReactions'] is List
          ? (json['myReactions'] as List)
                .map((value) => value.toString())
                .toList(growable: false)
          : const [],
    );
  }

  bool hasReaction(String emoji) => myReactions.contains(emoji);
}

class Topic {
  final String topicId;
  final String groupId;
  final String rootClientMsgId;
  final int rootSeq;
  final String creatorId;
  final String creatorNickname;
  final String creatorFaceUrl;
  final int createdAt;
  final int lastReplyAt;
  final int lastReplySeq;
  final int replyCount;
  final TopicState state;
  final bool pinned;
  final int pinnedAt;
  final String pinnedBy;
  final bool groupPinned;
  final int groupPinnedAt;
  final String groupPinnedBy;
  final String rootPreview;
  final int rootContentType;
  final List<TopicReplyPreview> recentReplies;
  final TopicUserState? userState;
  final bool hasUnread;
  final bool hasMention;
  final int version;
  final TopicReactionState reactions;
  final int editedAt;
  final String editedBy;

  const Topic({
    required this.topicId,
    required this.groupId,
    required this.rootClientMsgId,
    required this.rootSeq,
    required this.creatorId,
    required this.creatorNickname,
    required this.creatorFaceUrl,
    required this.createdAt,
    required this.lastReplyAt,
    required this.lastReplySeq,
    required this.replyCount,
    required this.state,
    required this.pinned,
    required this.pinnedAt,
    required this.pinnedBy,
    this.groupPinned = false,
    this.groupPinnedAt = 0,
    this.groupPinnedBy = '',
    required this.rootPreview,
    required this.rootContentType,
    required this.recentReplies,
    required this.userState,
    required this.hasUnread,
    this.hasMention = false,
    required this.version,
    this.reactions = const TopicReactionState(),
    this.editedAt = 0,
    this.editedBy = '',
  });

  bool get subscribed => userState?.subscribed == true;

  factory Topic.fromJson(Map<String, dynamic> json) {
    final stateJson = json['userState'];
    return Topic(
      topicId: json['topicID']?.toString() ?? '',
      groupId: json['groupID']?.toString() ?? '',
      rootClientMsgId: json['rootClientMsgID']?.toString() ?? '',
      rootSeq: _int(json['rootSeq']),
      creatorId: json['creatorID']?.toString() ?? '',
      creatorNickname: json['creatorNickname']?.toString() ?? '',
      creatorFaceUrl: json['creatorFaceURL']?.toString() ?? '',
      createdAt: _int(json['createdAt']),
      lastReplyAt: _int(json['lastReplyAt']),
      lastReplySeq: _int(json['lastReplySeq']),
      replyCount: _int(json['replyCount']),
      state: TopicState.parse(json['state']),
      pinned: json['pinned'] == true,
      pinnedAt: _int(json['pinnedAt']),
      pinnedBy: json['pinnedBy']?.toString() ?? '',
      groupPinned: json['groupPinned'] == true,
      groupPinnedAt: _int(json['groupPinnedAt']),
      groupPinnedBy: json['groupPinnedBy']?.toString() ?? '',
      rootPreview: json['rootPreview']?.toString() ?? '',
      rootContentType: _int(json['rootContentType']),
      recentReplies: _maps(
        json['recentReplies'],
      ).map(TopicReplyPreview.fromJson).toList(growable: false),
      userState: stateJson is Map<Object?, Object?>
          ? TopicUserState.fromJson(Map<String, dynamic>.from(stateJson))
          : null,
      hasUnread: json['hasUnread'] == true,
      hasMention: json['hasMention'] == true,
      version: _int(json['version']),
      reactions: json['reactions'] is Map<Object?, Object?>
          ? TopicReactionState.fromJson(
              Map<String, dynamic>.from(json['reactions'] as Map),
            )
          : const TopicReactionState(),
      editedAt: _int(json['editedAt']),
      editedBy: json['editedBy']?.toString() ?? '',
    );
  }

  bool get edited => editedAt > 0;
}

class TopicFeedItem {
  final TopicFeedItemType type;
  final int sortTime;
  final Topic? topic;
  final String systemEventId;
  final String systemEventText;

  const TopicFeedItem({
    required this.type,
    required this.sortTime,
    this.topic,
    this.systemEventId = '',
    this.systemEventText = '',
  });

  factory TopicFeedItem.fromJson(Map<String, dynamic> json) {
    final topicJson = json['topic'];
    return TopicFeedItem(
      type: TopicFeedItemType.parse(json['type']),
      sortTime: _int(json['sortTime']),
      topic: topicJson is Map
          ? Topic.fromJson(Map<String, dynamic>.from(topicJson))
          : null,
      systemEventId: json['systemEventID']?.toString() ?? '',
      systemEventText: json['systemEventText']?.toString() ?? '',
    );
  }
}

class TopicFeedPage {
  final List<TopicFeedItem> items;
  final String nextCursor;
  final bool hasMore;

  const TopicFeedPage({
    required this.items,
    required this.nextCursor,
    required this.hasMore,
  });
}

enum TopicSearchState { any, open, closed }

class TopicSearchFilter {
  final String authorId;
  final int createdAfter;
  final int createdBefore;
  final TopicSearchState state;
  final bool hasAttachments;
  final bool hasTasks;
  final bool pinnedOnly;
  final bool groupPinnedOnly;

  const TopicSearchFilter({
    this.authorId = '',
    this.createdAfter = 0,
    this.createdBefore = 0,
    this.state = TopicSearchState.any,
    this.hasAttachments = false,
    this.hasTasks = false,
    this.pinnedOnly = false,
    this.groupPinnedOnly = false,
  });

  bool get isActive =>
      authorId.isNotEmpty ||
      createdAfter > 0 ||
      createdBefore > 0 ||
      state != TopicSearchState.any ||
      hasAttachments ||
      hasTasks ||
      pinnedOnly ||
      groupPinnedOnly;

  TopicSearchFilter copyWith({
    String? authorId,
    int? createdAfter,
    int? createdBefore,
    TopicSearchState? state,
    bool? hasAttachments,
    bool? hasTasks,
    bool? pinnedOnly,
    bool? groupPinnedOnly,
    bool clearAuthor = false,
    bool clearCreatedAfter = false,
    bool clearCreatedBefore = false,
  }) {
    return TopicSearchFilter(
      authorId: clearAuthor ? '' : (authorId ?? this.authorId),
      createdAfter: clearCreatedAfter ? 0 : (createdAfter ?? this.createdAfter),
      createdBefore: clearCreatedBefore
          ? 0
          : (createdBefore ?? this.createdBefore),
      state: state ?? this.state,
      hasAttachments: hasAttachments ?? this.hasAttachments,
      hasTasks: hasTasks ?? this.hasTasks,
      pinnedOnly: pinnedOnly ?? this.pinnedOnly,
      groupPinnedOnly: groupPinnedOnly ?? this.groupPinnedOnly,
    );
  }

  int get stateWireValue => switch (state) {
    TopicSearchState.any => 0,
    TopicSearchState.open => 1,
    TopicSearchState.closed => 2,
  };
}

class TopicSearchPage {
  final List<Topic> topics;
  final String nextCursor;
  final bool hasMore;

  const TopicSearchPage({
    required this.topics,
    this.nextCursor = '',
    this.hasMore = false,
  });
}

class TopicDetail {
  final Topic topic;
  final ChatMessage? rootMessage;

  const TopicDetail({required this.topic, required this.rootMessage});
}

class TopicReply {
  final ChatMessage message;
  final bool revoked;

  const TopicReply({required this.message, required this.revoked});
}

class TopicReplyPage {
  final List<TopicReply> replies;
  final int nextBeforeSeq;
  final bool hasMore;

  const TopicReplyPage({
    required this.replies,
    required this.nextBeforeSeq,
    required this.hasMore,
  });
}

class TopicGroupModeProfile {
  final String groupId;
  final GroupMode mode;
  final int modeSinceSeq;
  final int version;

  const TopicGroupModeProfile({
    required this.groupId,
    required this.mode,
    required this.modeSinceSeq,
    required this.version,
  });

  factory TopicGroupModeProfile.fromJson(Map<String, dynamic> json) {
    final mode = json['mode'];
    return TopicGroupModeProfile(
      groupId: json['groupID']?.toString() ?? '',
      mode: mode == 2 || mode?.toString() == 'GROUP_MODE_TOPIC'
          ? GroupMode.topic
          : GroupMode.chat,
      modeSinceSeq: _int(json['modeSinceSeq']),
      version: _int(json['version']),
    );
  }
}

class TopicGroupSettings {
  final bool allowMemberPublish;
  final bool allowMemberReply;
  final bool defaultSubscribe;
  final bool notifyNewTopic;
  final bool notifyReplies;
  final bool allowMemberPin;
  final bool allowMemberGroupPin;

  const TopicGroupSettings({
    this.allowMemberPublish = true,
    this.allowMemberReply = true,
    this.defaultSubscribe = true,
    this.notifyNewTopic = true,
    this.notifyReplies = true,
    this.allowMemberPin = true,
    this.allowMemberGroupPin = true,
  });

  TopicGroupSettings copyWith({
    bool? allowMemberPublish,
    bool? allowMemberReply,
    bool? defaultSubscribe,
    bool? notifyNewTopic,
    bool? notifyReplies,
    bool? allowMemberPin,
    bool? allowMemberGroupPin,
  }) {
    return TopicGroupSettings(
      allowMemberPublish: allowMemberPublish ?? this.allowMemberPublish,
      allowMemberReply: allowMemberReply ?? this.allowMemberReply,
      defaultSubscribe: defaultSubscribe ?? this.defaultSubscribe,
      notifyNewTopic: notifyNewTopic ?? this.notifyNewTopic,
      notifyReplies: notifyReplies ?? this.notifyReplies,
      allowMemberPin: allowMemberPin ?? this.allowMemberPin,
      allowMemberGroupPin: allowMemberGroupPin ?? this.allowMemberGroupPin,
    );
  }

  factory TopicGroupSettings.fromJson(Map<String, dynamic> json) {
    return TopicGroupSettings(
      allowMemberPublish: json['allowMemberPublish'] != false,
      allowMemberReply: json['allowMemberReply'] != false,
      defaultSubscribe: json['defaultSubscribe'] != false,
      notifyNewTopic: json['notifyNewTopic'] != false,
      notifyReplies: json['notifyReplies'] != false,
      allowMemberPin: json['allowMemberPin'] != false,
      allowMemberGroupPin: json['allowMemberGroupPin'] != false,
    );
  }
}

class TopicGroupSettingsProfile {
  final TopicGroupSettings settings;
  final int version;

  const TopicGroupSettingsProfile({
    required this.settings,
    required this.version,
  });

  factory TopicGroupSettingsProfile.fromJson(Map<String, dynamic> json) {
    final raw = json['settings'];
    return TopicGroupSettingsProfile(
      settings: raw is Map
          ? TopicGroupSettings.fromJson(Map<String, dynamic>.from(raw))
          : const TopicGroupSettings(),
      version: _int(json['version']),
    );
  }
}

class TopicGroupSummary {
  final String groupId;
  final int topicCount;
  final int unreadTopicCount;
  final String latestTopicId;
  final int latestActivityAt;
  final String latestActivityPreview;
  final int latestActivityType;
  final String latestSenderName;

  const TopicGroupSummary({
    required this.groupId,
    required this.topicCount,
    required this.unreadTopicCount,
    required this.latestTopicId,
    required this.latestActivityAt,
    required this.latestActivityPreview,
    required this.latestActivityType,
    required this.latestSenderName,
  });

  bool get hasUnread => unreadTopicCount > 0;

  factory TopicGroupSummary.fromJson(Map<String, dynamic> json) {
    return TopicGroupSummary(
      groupId: json['groupID']?.toString() ?? '',
      topicCount: _int(json['topicCount']),
      unreadTopicCount: _int(json['unreadTopicCount']),
      latestTopicId: json['latestTopicID']?.toString() ?? '',
      latestActivityAt: _int(json['latestActivityAt']),
      latestActivityPreview: json['latestActivityPreview']?.toString() ?? '',
      latestActivityType: _int(json['latestActivityType']),
      latestSenderName: json['latestSenderName']?.toString() ?? '',
    );
  }

  String get displayPreview {
    if (latestActivityPreview.isEmpty) return '';
    if (latestSenderName.isEmpty) return latestActivityPreview;
    return '$latestSenderName: $latestActivityPreview';
  }
}

class TopicTask {
  final String taskId;
  final String topicId;
  final String groupId;
  final String title;
  final String description;
  final String creatorId;
  final String creatorNickname;
  final String assigneeId;
  final String assigneeNickname;
  final int dueAt;
  final TopicTaskPriority priority;
  final TopicTaskStatus status;
  final int createdAt;
  final int updatedAt;
  final int version;

  const TopicTask({
    required this.taskId,
    required this.topicId,
    required this.groupId,
    required this.title,
    required this.description,
    required this.creatorId,
    required this.creatorNickname,
    required this.assigneeId,
    required this.assigneeNickname,
    required this.dueAt,
    required this.priority,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.version,
  });

  factory TopicTask.fromJson(Map<String, dynamic> json) {
    return TopicTask(
      taskId: json['taskID']?.toString() ?? '',
      topicId: json['topicID']?.toString() ?? '',
      groupId: json['groupID']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      creatorId: json['creatorID']?.toString() ?? '',
      creatorNickname: json['creatorNickname']?.toString() ?? '',
      assigneeId: json['assigneeID']?.toString() ?? '',
      assigneeNickname: json['assigneeNickname']?.toString() ?? '',
      dueAt: _int(json['dueAt']),
      priority: TopicTaskPriority.parse(json['priority']),
      status: TopicTaskStatus.parse(json['status']),
      createdAt: _int(json['createdAt']),
      updatedAt: _int(json['updatedAt']),
      version: _int(json['version']),
    );
  }
}

/// 分享到普通会话的话题卡片数据。
///
/// 该数据写入自定义消息的 `data` 字段。接收方必须通过 Topic API 重新校验
/// 当前用户是否仍是群成员，卡片里的标题只用于展示，不能作为访问凭证。
class TopicShareCard {
  static const type = 'openim_topic_card';

  final String groupId;
  final String topicId;
  final String groupName;
  final String title;
  final String creatorName;
  final int replyCount;
  final String link;
  final List<TopicShareReply> replies;
  final bool snapshotComplete;

  const TopicShareCard({
    required this.groupId,
    required this.topicId,
    required this.groupName,
    required this.title,
    required this.creatorName,
    required this.replyCount,
    required this.link,
    this.replies = const [],
    this.snapshotComplete = true,
  });

  Map<String, dynamic> toJson() => {
    'type': type,
    'version': 1,
    'groupID': groupId,
    'topicID': topicId,
    'groupName': groupName,
    'title': title,
    'creatorName': creatorName,
    'replyCount': replyCount,
    'link': link,
    'replies': replies.map((reply) => reply.toJson()).toList(growable: false),
    'snapshotComplete': snapshotComplete,
  };

  factory TopicShareCard.fromJson(Map<String, dynamic> json) {
    return TopicShareCard(
      groupId: json['groupID']?.toString() ?? '',
      topicId: json['topicID']?.toString() ?? '',
      groupName: json['groupName']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      creatorName: json['creatorName']?.toString() ?? '',
      replyCount: _int(json['replyCount']),
      link: json['link']?.toString() ?? '',
      replies: _maps(
        json['replies'],
      ).map(TopicShareReply.fromJson).toList(growable: false),
      snapshotComplete: json['snapshotComplete'] != false,
    );
  }
}

class TopicShareReply {
  final int seq;
  final String senderName;
  final String content;
  final int sendTime;

  const TopicShareReply({
    required this.seq,
    required this.senderName,
    required this.content,
    required this.sendTime,
  });

  Map<String, dynamic> toJson() => {
    'seq': seq,
    'senderName': senderName,
    'content': content,
    'sendTime': sendTime,
  };

  factory TopicShareReply.fromJson(Map<String, dynamic> json) {
    return TopicShareReply(
      seq: _int(json['seq']),
      senderName: json['senderName']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      sendTime: _int(json['sendTime']),
    );
  }
}

int _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

List<Map<String, dynamic>> _maps(Object? value) {
  if (value is! List) return const [];
  return value
      .whereType<Map<Object?, Object?>>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList(growable: false);
}
