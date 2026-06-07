import 'package:freezed_annotation/freezed_annotation.dart';

part 'chat.freezed.dart';
part 'chat.g.dart';

@freezed
class Chat with _$Chat {
  const factory Chat({
    required String id,
    required String name,
    String? avatar,
    required bool isGroup,
    required int unreadCount,
    required String lastMessage,
    required DateTime lastMessageTime,
    List<String>? memberIds,
    String? groupId,
  }) = _Chat;

  factory Chat.fromJson(Map<String, dynamic> json) => _$ChatFromJson(json);
}
