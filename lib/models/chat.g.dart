// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ChatImpl _$$ChatImplFromJson(Map<String, dynamic> json) => _$ChatImpl(
  id: json['id'] as String,
  name: json['name'] as String,
  avatar: json['avatar'] as String?,
  isGroup: json['isGroup'] as bool,
  unreadCount: (json['unreadCount'] as num).toInt(),
  lastMessage: Message.fromJson(json['lastMessage'] as Map<String, dynamic>),
  lastMessageTime: DateTime.parse(json['lastMessageTime'] as String),
  memberIds: (json['memberIds'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  groupId: json['groupId'] as String?,
);

Map<String, dynamic> _$$ChatImplToJson(_$ChatImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'avatar': instance.avatar,
      'isGroup': instance.isGroup,
      'unreadCount': instance.unreadCount,
      'lastMessage': instance.lastMessage,
      'lastMessageTime': instance.lastMessageTime.toIso8601String(),
      'memberIds': instance.memberIds,
      'groupId': instance.groupId,
    };
