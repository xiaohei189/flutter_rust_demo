import '../../../domain/models/conversation.dart';
import '../../../generated/rust/constant/enums.dart' show SessionType;

extension ConversationX on Conversation {
  SessionType get sessionType {
    switch (conversationType) {
      case 1:
        return SessionType.singleChat;
      case 2:
        return SessionType.writeGroupChat;
      case 3:
        return SessionType.readGroupChat;
      default:
        return SessionType.notificationChat;
    }
  }
}
