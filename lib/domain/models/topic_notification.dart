enum TopicNotificationType {
  newTopic,
  reply,
  mention,
  stateChanged,
  rootEdited,
  taskAssigned,
  taskChanged,
}

extension TopicNotificationTypeWire on TopicNotificationType {
  int get wireValue => index + 1;
}

class TopicNotification {
  final String id;
  final String groupId;
  final String topicId;
  final String actorId;
  final String actorName;
  final String title;
  final String body;
  final TopicNotificationType type;
  final int createdAt;
  final bool read;

  const TopicNotification({
    required this.id,
    required this.groupId,
    required this.topicId,
    required this.actorId,
    required this.actorName,
    required this.title,
    required this.body,
    required this.type,
    required this.createdAt,
    this.read = false,
  });

  TopicNotification copyWith({bool? read}) => TopicNotification(
    id: id,
    groupId: groupId,
    topicId: topicId,
    actorId: actorId,
    actorName: actorName,
    title: title,
    body: body,
    type: type,
    createdAt: createdAt,
    read: read ?? this.read,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'groupID': groupId,
    'topicID': topicId,
    'actorID': actorId,
    'actorName': actorName,
    'title': title,
    'body': body,
    'type': type.name,
    'createdAt': createdAt,
    'read': read,
  };

  factory TopicNotification.fromJson(Map<String, dynamic> json) {
    final rawType = json['type'];
    return TopicNotification(
      id: json['id']?.toString() ?? json['notificationID']?.toString() ?? '',
      groupId: json['groupID']?.toString() ?? '',
      topicId: json['topicID']?.toString() ?? '',
      actorId: json['actorID']?.toString() ?? '',
      actorName: json['actorName']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      type: rawType is num
          ? _typeFromWire(rawType.toInt())
          : TopicNotificationType.values.firstWhere(
              (value) => value.name == rawType,
              orElse: () => TopicNotificationType.reply,
            ),
      createdAt: (json['createdAt'] as num?)?.toInt() ?? 0,
      read: json['read'] == true,
    );
  }

  static TopicNotificationType _typeFromWire(int value) => switch (value) {
    1 => TopicNotificationType.newTopic,
    2 => TopicNotificationType.reply,
    3 => TopicNotificationType.mention,
    4 => TopicNotificationType.stateChanged,
    5 => TopicNotificationType.rootEdited,
    6 => TopicNotificationType.taskAssigned,
    7 => TopicNotificationType.taskChanged,
    _ => TopicNotificationType.reply,
  };
}

class TopicNotificationPage {
  final List<TopicNotification> notifications;
  final String nextCursor;
  final bool hasMore;
  final int unreadCount;

  const TopicNotificationPage({
    required this.notifications,
    this.nextCursor = '',
    this.hasMore = false,
    this.unreadCount = 0,
  });
}
