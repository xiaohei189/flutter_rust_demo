/// 消息级本地扩展：表情回复、置顶标记、标记（收藏）。
///
/// 仅本地生效（不参与服务端同步），按「会话 + 消息」维度存储：
/// - reactions：当前用户给这条消息加的表情（emoji 集合）
/// - pinned：是否被置顶；pinnedAt 用于多条置顶时取最近的一条
/// - flagged：是否被「标记」，用于后续从标记入口回看
class MessageExtras {
  const MessageExtras({
    this.reactions = const <String>{},
    this.pinned = false,
    this.pinnedAt = 0,
    this.flagged = false,
  });

  final Set<String> reactions;
  final bool pinned;
  final int pinnedAt;
  final bool flagged;

  static const MessageExtras empty = MessageExtras();

  bool get isEmpty => reactions.isEmpty && !pinned && !flagged;

  MessageExtras copyWith({
    Set<String>? reactions,
    bool? pinned,
    int? pinnedAt,
    bool? flagged,
  }) {
    return MessageExtras(
      reactions: reactions ?? this.reactions,
      pinned: pinned ?? this.pinned,
      pinnedAt: pinnedAt ?? this.pinnedAt,
      flagged: flagged ?? this.flagged,
    );
  }

  factory MessageExtras.fromJson(Map<String, dynamic> json) {
    final rawReactions = json['reactions'];
    return MessageExtras(
      reactions: rawReactions is List
          ? rawReactions.whereType<String>().toSet()
          : const <String>{},
      pinned: json['pinned'] == true,
      pinnedAt: (json['pinnedAt'] as num?)?.toInt() ?? 0,
      flagged: json['flagged'] == true,
    );
  }

  /// 空扩展不落盘：JSON 里只保留有内容的字段。
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      if (reactions.isNotEmpty) 'reactions': reactions.toList(),
      if (pinned) 'pinned': true,
      if (pinned) 'pinnedAt': pinnedAt,
      if (flagged) 'flagged': true,
    };
  }

  @override
  bool operator ==(Object other) {
    return other is MessageExtras &&
        other.pinned == pinned &&
        other.pinnedAt == pinnedAt &&
        other.flagged == flagged &&
        other.reactions.length == reactions.length &&
        other.reactions.containsAll(reactions);
  }

  @override
  int get hashCode =>
      Object.hash(pinned, pinnedAt, flagged, Object.hashAllUnordered(reactions));
}
