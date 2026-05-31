import '../src/rust/domain/constant/enums.dart' show SessionType;
import '../src/rust/infra/database/models.dart' show LocalConversation;

extension LocalConversationX on LocalConversation {
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
