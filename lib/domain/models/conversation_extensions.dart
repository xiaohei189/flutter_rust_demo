import 'chat_session_type.dart' show ChatSessionType;
import 'conversation.dart';

extension ConversationX on Conversation {
  ChatSessionType get sessionType {
    switch (conversationType) {
      case 1:
        return ChatSessionType.singleChat;
      case 2:
        return ChatSessionType.writeGroupChat;
      case 3:
        return ChatSessionType.readGroupChat;
      default:
        return ChatSessionType.notificationChat;
    }
  }
}
