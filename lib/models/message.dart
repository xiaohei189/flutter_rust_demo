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

enum MessageSendStatus {
  sending,
  sent,
  failed,
  read,
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

