import '../../../../domain/models/chat_message.dart';
import '../../../../generated/rust/event/events/message.dart' show GroupReadReceipt;

class MessageStore {
  final Map<String, List<ChatMessage>> messages;
  final Map<String, String> typingUsers;
  final Map<String, int> uploadProgress;
  final Map<String, GroupReadReceipt> groupReadReceipts;

  const MessageStore({
    this.messages = const {},
    this.typingUsers = const {},
    this.uploadProgress = const {},
    this.groupReadReceipts = const {},
  });

  MessageStore copyWith({
    Map<String, List<ChatMessage>>? messages,
    Map<String, String>? typingUsers,
    Map<String, int>? uploadProgress,
    Map<String, GroupReadReceipt>? groupReadReceipts,
  }) {
    return MessageStore(
      messages: messages ?? this.messages,
      typingUsers: typingUsers ?? this.typingUsers,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      groupReadReceipts: groupReadReceipts ?? this.groupReadReceipts,
    );
  }
}