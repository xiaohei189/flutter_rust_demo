// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_User _$UserFromJson(Map<String, dynamic> json) => _User(
  id: json['id'] as String,
  name: json['name'] as String,
  avatar: json['avatar'] as String?,
  status: json['status'] as String?,
  avatarColorValue: (json['avatarColorValue'] as num?)?.toInt(),
  avatarIconName: json['avatarIconName'] as String?,
);

Map<String, dynamic> _$UserToJson(_User instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'avatar': instance.avatar,
  'status': instance.status,
  'avatarColorValue': instance.avatarColorValue,
  'avatarIconName': instance.avatarIconName,
};
