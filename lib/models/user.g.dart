// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$UserImpl _$$UserImplFromJson(Map<String, dynamic> json) => _$UserImpl(
  id: json['id'] as String,
  name: json['name'] as String,
  avatar: json['avatar'] as String?,
  status: json['status'] as String?,
  avatarColorValue: (json['avatarColorValue'] as num?)?.toInt(),
  avatarIconName: json['avatarIconName'] as String?,
);

Map<String, dynamic> _$$UserImplToJson(_$UserImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'avatar': instance.avatar,
      'status': instance.status,
      'avatarColorValue': instance.avatarColorValue,
      'avatarIconName': instance.avatarIconName,
    };
