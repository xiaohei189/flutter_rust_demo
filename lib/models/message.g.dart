// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'message.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$MessageImpl _$$MessageImplFromJson(Map<String, dynamic> json) =>
    _$MessageImpl(
      id: json['id'] as String,
      senderId: json['senderId'] as String,
      content: json['content'] as String,
      type:
          $enumDecodeNullable(_$MessageTypeEnumMap, json['type']) ??
          MessageType.text,
      timestamp: DateTime.parse(json['timestamp'] as String),
      isSent: json['isSent'] as bool? ?? true,
      sendStatus: $enumDecodeNullable(
        _$MessageSendStatusEnumMap,
        json['sendStatus'],
      ),
      senderNickname: json['senderNickname'] as String?,
      senderFaceUrl: json['senderFaceUrl'] as String?,
    );

Map<String, dynamic> _$$MessageImplToJson(_$MessageImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'senderId': instance.senderId,
      'content': instance.content,
      'type': _$MessageTypeEnumMap[instance.type]!,
      'timestamp': instance.timestamp.toIso8601String(),
      'isSent': instance.isSent,
      'sendStatus': _$MessageSendStatusEnumMap[instance.sendStatus],
      'senderNickname': instance.senderNickname,
      'senderFaceUrl': instance.senderFaceUrl,
    };

const _$MessageTypeEnumMap = {
  MessageType.text: 'text',
  MessageType.image: 'image',
  MessageType.audio: 'audio',
  MessageType.video: 'video',
  MessageType.file: 'file',
};

const _$MessageSendStatusEnumMap = {
  MessageSendStatus.sending: 'sending',
  MessageSendStatus.sendSuccess: 'sendSuccess',
  MessageSendStatus.sendFailed: 'sendFailed',
  MessageSendStatus.hasDeleted: 'hasDeleted',
};
