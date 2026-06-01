import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flutter_rust_demo/models/user.dart';

part 'message.freezed.dart';
part 'message.g.dart';

enum MessageType {
  text,
  image,
  audio,
  video,
  file,
}

/// 消息发送状态（与 Rust SDK MessageSendStatus 对齐）
enum MessageSendStatus {
  sending(1),      // 发送中
  sendSuccess(2),  // 发送成功
  sendFailed(3),   // 发送失败
  hasDeleted(4);   // 已删除

  final int value;
  const MessageSendStatus(this.value);

  factory MessageSendStatus.fromValue(int value) {
    return values.firstWhere(
      (e) => e.value == value,
      orElse: () => sending,
    );
  }
}

@freezed
class Message with _$Message {
  const factory Message({
    required String id,
    required String senderId,
    required String content,
    @Default(MessageType.text) MessageType type,
    required DateTime timestamp,
    @Default(true) bool isSent,
    MessageSendStatus? sendStatus,
    String? senderNickname,
    String? senderFaceUrl,
  }) = _Message;

  factory Message.fromJson(Map<String, dynamic> json) => _$MessageFromJson(json);
}

// 为 Message 类添加扩展方法
extension MessageExtensions on Message {
  bool get isFromMe => senderId == User.currentUser.id;
}

