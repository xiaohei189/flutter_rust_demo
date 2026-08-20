import 'models/chat_message.dart' show ChatMessage;

/// 按发送时间升序排序，时间相同时按 seq 升序。
///
/// UI 使用 reverse ListView，列表必须保持“旧消息在前、新消息在后”，
/// 这样渲染时最新消息才会出现在底部。
List<ChatMessage> sortMessagesByTime(List<ChatMessage> messages) {
  final list = List<ChatMessage>.from(messages);
  list.sort((a, b) {
    final time = a.sendTime.toInt().compareTo(b.sendTime.toInt());
    if (time != 0) return time;
    return a.seq.toInt().compareTo(b.seq.toInt());
  });
  return list;
}
