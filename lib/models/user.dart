import 'package:freezed_annotation/freezed_annotation.dart';

part 'user.freezed.dart';
part 'user.g.dart';

@freezed
class User with _$User {
  const factory User({
    required String id,
    required String name,
    String? avatar,
    String? status,
    int? avatarColorValue,
    String? avatarIconName,
  }) = _User;

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);

  // 添加 currentUser getter
  static User get currentUser => mockUsers[0];

  static const List<User> mockUsers = [
    User(
      id: '1',
      name: '张三',
      avatar: null,
      status: '在线',
      avatarColorValue: 0xFF6200EE,
      avatarIconName: 'person',
    ),
    User(
      id: '2',
      name: '李四',
      avatar: null,
      status: '离线',
      avatarColorValue: 0xFF03DAC6,
      avatarIconName: 'person',
    ),
    User(
      id: '3',
      name: '王五',
      avatar: null,
      status: '忙碌',
      avatarColorValue: 0xFFF44336,
      avatarIconName: 'person',
    ),
  ];
}

// 为 User 类添加扩展方法
extension UserExtensions on User {
  int get avatarColor => avatarColorValue ?? 0xFF6200EE;
  String get avatarIcon => avatarIconName ?? 'person';
}

