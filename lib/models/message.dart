/// 消息类型（与 OpenIM contentType 对齐）
enum MessageType {
  text,       // 101
  image,      // 102
  video,      // 103
  audio,      // 104
  file,       // 105
  location,   // 106/109
  card,       // 108
  custom,     // 110
  merge,      // 111
  quote,      // 114
  face,       // 115
  at,         // 116
  advancedText, // 117
  markdown,   // 118
  system,     // 系统提示（撤回等）
}

/// 将 OpenIM contentType 整数转为 MessageType
MessageType messageTypeFromContentType(int ct) {
  return switch (ct) {
    101 => MessageType.text,
    102 => MessageType.image,
    103 => MessageType.video,
    104 => MessageType.audio,
    105 => MessageType.file,
    106 || 109 => MessageType.location,
    107 || 108 => MessageType.card,
    110 => MessageType.custom,
    111 => MessageType.merge,
    114 => MessageType.quote,
    115 => MessageType.face,
    116 => MessageType.at,
    117 => MessageType.advancedText,
    118 => MessageType.markdown,
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
