import 'user.dart';
import 'message.dart';

/// 聊天会话模型
class Chat {
  final String id;
  final User user;
  final Message? lastMessage;
  final int unreadCount;
  final DateTime? lastMessageTime;

  Chat({
    required this.id,
    required this.user,
    this.lastMessage,
    this.unreadCount = 0,
    this.lastMessageTime,
  });

  // 模拟聊天列表数据
  static List<Chat> mockChats = [
    Chat(
      id: '1',
      user: User.mockUsers[0],
      lastMessage: Message(
        id: '1',
        senderId: '2',
        content: '你好，最近怎么样？',
        timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
      ),
      unreadCount: 2,
      lastMessageTime: DateTime.now().subtract(const Duration(minutes: 5)),
    ),
    Chat(
      id: '2',
      user: User.mockUsers[1],
      lastMessage: Message(
        id: '2',
        senderId: '3',
        content: '明天一起吃饭吗？',
        timestamp: DateTime.now().subtract(const Duration(hours: 1)),
      ),
      unreadCount: 0,
      lastMessageTime: DateTime.now().subtract(const Duration(hours: 1)),
    ),
    Chat(
      id: '3',
      user: User.mockUsers[2],
      lastMessage: Message(
        id: '3',
        senderId: '4',
        content: '收到，谢谢！',
        timestamp: DateTime.now().subtract(const Duration(hours: 3)),
      ),
      unreadCount: 1,
      lastMessageTime: DateTime.now().subtract(const Duration(hours: 3)),
    ),
  ];
}



