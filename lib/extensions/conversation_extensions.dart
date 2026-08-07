import '../src/rust/constant/enums.dart' show SessionType;
import '../src/rust/model/local.dart' show LocalConversation;

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
