/// 消息类型（与 OpenIM contentType 对齐，参考 rust/src/constant/types.rs）
enum MessageType {
  text,         // 101
  image,        // 102
  audio,        // 103（语音）
  video,        // 104
  file,         // 105
  at,           // 106
  merge,        // 107（合并转发）
  card,         // 108
  location,     // 109
  custom,       // 110
  quote,        // 114
  face,         // 115
  advancedText, // 117
  markdown,     // 118
  system,       // 系统提示（撤回等）
}

/// 将 OpenIM contentType 整数转为 MessageType
MessageType messageTypeFromContentType(int ct) {
  // OpenIM 通知类型区间：1000-5000（好友、用户、群组、会话、业务通知等）
  if (ct >= 1000 && ct <= 5000) return MessageType.system;
  return switch (ct) {
    101 => MessageType.text,
    102 => MessageType.image,
    103 => MessageType.audio,
    104 => MessageType.video,
    105 => MessageType.file,
    106 => MessageType.at,
    107 => MessageType.merge,
    108 => MessageType.card,
    109 => MessageType.location,
    110 => MessageType.custom,
    114 => MessageType.quote,
    115 => MessageType.face,
    117 => MessageType.advancedText,
    118 => MessageType.markdown,
    2101 => MessageType.system, // 消息撤回（RevokeNotification）
    10000 => MessageType.system,
    _ => MessageType.text,
  };
}

/// 消息发送状态（与 Rust SDK MessageSendStatus 对齐）
enum MessageSendStatus {
  sending(1),
  sendSuccess(2),
  sendFailed(3),
  hasDeleted(4);

  final int value;
  const MessageSendStatus(this.value);

  factory MessageSendStatus.fromValue(int value) {
    return values.firstWhere(
      (e) => e.value == value,
      orElse: () => MessageSendStatus.sending,
    );
  }
}
