/// 本地定时消息：到点后用普通文本消息链路发送。
///
/// 仅本地持久化（SharedPreferences），不参与服务端同步；
/// 应用关闭期间到点的消息会在下次启动登录后补发。
class ScheduledMessage {
  const ScheduledMessage({
    required this.id,
    required this.conversationId,
    required this.text,
    required this.scheduledAt,
  });

  final String id;
  final String conversationId;
  final String text;

  /// 计划发送时间（epoch 毫秒）。
  final int scheduledAt;

  DateTime get scheduledDateTime =>
      DateTime.fromMillisecondsSinceEpoch(scheduledAt);

  bool isDue(DateTime now) => !scheduledDateTime.isAfter(now);

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'conversationId': conversationId,
    'text': text,
    'scheduledAt': scheduledAt,
  };

  static ScheduledMessage? fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final conversationId = json['conversationId'];
    final text = json['text'];
    final scheduledAt = json['scheduledAt'];
    if (id is! String || id.isEmpty) return null;
    if (conversationId is! String || conversationId.isEmpty) return null;
    if (text is! String || text.isEmpty) return null;
    if (scheduledAt is! num) return null;
    return ScheduledMessage(
      id: id,
      conversationId: conversationId,
      text: text,
      scheduledAt: scheduledAt.toInt(),
    );
  }
}
