// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'message.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$MessageEvent {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MessageEvent);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'MessageEvent()';
}


}

/// @nodoc
class $MessageEventCopyWith<$Res>  {
$MessageEventCopyWith(MessageEvent _, $Res Function(MessageEvent) __);
}


/// Adds pattern-matching-related methods to [MessageEvent].
extension MessageEventPatterns on MessageEvent {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( MessageEvent_NewMessage value)?  newMessage,TResult Function( MessageEvent_OfflineNewMessage value)?  offlineNewMessage,TResult Function( MessageEvent_OnlineOnlyMessage value)?  onlineOnlyMessage,TResult Function( MessageEvent_Revoked value)?  revoked,TResult Function( MessageEvent_C2CReadReceipt value)?  c2CReadReceipt,TResult Function( MessageEvent_Deleted value)?  deleted,TResult Function( MessageEvent_SendFailed value)?  sendFailed,TResult Function( MessageEvent_UploadProgress value)?  uploadProgress,required TResult orElse(),}){
final _that = this;
switch (_that) {
case MessageEvent_NewMessage() when newMessage != null:
return newMessage(_that);case MessageEvent_OfflineNewMessage() when offlineNewMessage != null:
return offlineNewMessage(_that);case MessageEvent_OnlineOnlyMessage() when onlineOnlyMessage != null:
return onlineOnlyMessage(_that);case MessageEvent_Revoked() when revoked != null:
return revoked(_that);case MessageEvent_C2CReadReceipt() when c2CReadReceipt != null:
return c2CReadReceipt(_that);case MessageEvent_Deleted() when deleted != null:
return deleted(_that);case MessageEvent_SendFailed() when sendFailed != null:
return sendFailed(_that);case MessageEvent_UploadProgress() when uploadProgress != null:
return uploadProgress(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( MessageEvent_NewMessage value)  newMessage,required TResult Function( MessageEvent_OfflineNewMessage value)  offlineNewMessage,required TResult Function( MessageEvent_OnlineOnlyMessage value)  onlineOnlyMessage,required TResult Function( MessageEvent_Revoked value)  revoked,required TResult Function( MessageEvent_C2CReadReceipt value)  c2CReadReceipt,required TResult Function( MessageEvent_Deleted value)  deleted,required TResult Function( MessageEvent_SendFailed value)  sendFailed,required TResult Function( MessageEvent_UploadProgress value)  uploadProgress,}){
final _that = this;
switch (_that) {
case MessageEvent_NewMessage():
return newMessage(_that);case MessageEvent_OfflineNewMessage():
return offlineNewMessage(_that);case MessageEvent_OnlineOnlyMessage():
return onlineOnlyMessage(_that);case MessageEvent_Revoked():
return revoked(_that);case MessageEvent_C2CReadReceipt():
return c2CReadReceipt(_that);case MessageEvent_Deleted():
return deleted(_that);case MessageEvent_SendFailed():
return sendFailed(_that);case MessageEvent_UploadProgress():
return uploadProgress(_that);}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( MessageEvent_NewMessage value)?  newMessage,TResult? Function( MessageEvent_OfflineNewMessage value)?  offlineNewMessage,TResult? Function( MessageEvent_OnlineOnlyMessage value)?  onlineOnlyMessage,TResult? Function( MessageEvent_Revoked value)?  revoked,TResult? Function( MessageEvent_C2CReadReceipt value)?  c2CReadReceipt,TResult? Function( MessageEvent_Deleted value)?  deleted,TResult? Function( MessageEvent_SendFailed value)?  sendFailed,TResult? Function( MessageEvent_UploadProgress value)?  uploadProgress,}){
final _that = this;
switch (_that) {
case MessageEvent_NewMessage() when newMessage != null:
return newMessage(_that);case MessageEvent_OfflineNewMessage() when offlineNewMessage != null:
return offlineNewMessage(_that);case MessageEvent_OnlineOnlyMessage() when onlineOnlyMessage != null:
return onlineOnlyMessage(_that);case MessageEvent_Revoked() when revoked != null:
return revoked(_that);case MessageEvent_C2CReadReceipt() when c2CReadReceipt != null:
return c2CReadReceipt(_that);case MessageEvent_Deleted() when deleted != null:
return deleted(_that);case MessageEvent_SendFailed() when sendFailed != null:
return sendFailed(_that);case MessageEvent_UploadProgress() when uploadProgress != null:
return uploadProgress(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( String conversationId,  MessageInfo message)?  newMessage,TResult Function( String conversationId,  MessageInfo message)?  offlineNewMessage,TResult Function( String conversationId,  MessageInfo message)?  onlineOnlyMessage,TResult Function( String conversationId,  int seq,  String clientMsgId,  String revokerId,  int revokerRole,  String revokerNickname,  int revokeTime,  int sourceMessageSendTime,  String sourceMessageSendId,  String sourceMessageSenderNickname,  int sessionType,  bool isAdminRevoke)?  revoked,TResult Function( List<MessageReceipt> receipts)?  c2CReadReceipt,TResult Function( String conversationId,  List<String> clientMsgIds)?  deleted,TResult Function( String clientMsgId,  String error)?  sendFailed,TResult Function( String clientMsgId,  int progress,  int totalSize,  int uploadedSize)?  uploadProgress,required TResult orElse(),}) {final _that = this;
switch (_that) {
case MessageEvent_NewMessage() when newMessage != null:
return newMessage(_that.conversationId,_that.message);case MessageEvent_OfflineNewMessage() when offlineNewMessage != null:
return offlineNewMessage(_that.conversationId,_that.message);case MessageEvent_OnlineOnlyMessage() when onlineOnlyMessage != null:
return onlineOnlyMessage(_that.conversationId,_that.message);case MessageEvent_Revoked() when revoked != null:
return revoked(_that.conversationId,_that.seq,_that.clientMsgId,_that.revokerId,_that.revokerRole,_that.revokerNickname,_that.revokeTime,_that.sourceMessageSendTime,_that.sourceMessageSendId,_that.sourceMessageSenderNickname,_that.sessionType,_that.isAdminRevoke);case MessageEvent_C2CReadReceipt() when c2CReadReceipt != null:
return c2CReadReceipt(_that.receipts);case MessageEvent_Deleted() when deleted != null:
return deleted(_that.conversationId,_that.clientMsgIds);case MessageEvent_SendFailed() when sendFailed != null:
return sendFailed(_that.clientMsgId,_that.error);case MessageEvent_UploadProgress() when uploadProgress != null:
return uploadProgress(_that.clientMsgId,_that.progress,_that.totalSize,_that.uploadedSize);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( String conversationId,  MessageInfo message)  newMessage,required TResult Function( String conversationId,  MessageInfo message)  offlineNewMessage,required TResult Function( String conversationId,  MessageInfo message)  onlineOnlyMessage,required TResult Function( String conversationId,  int seq,  String clientMsgId,  String revokerId,  int revokerRole,  String revokerNickname,  int revokeTime,  int sourceMessageSendTime,  String sourceMessageSendId,  String sourceMessageSenderNickname,  int sessionType,  bool isAdminRevoke)  revoked,required TResult Function( List<MessageReceipt> receipts)  c2CReadReceipt,required TResult Function( String conversationId,  List<String> clientMsgIds)  deleted,required TResult Function( String clientMsgId,  String error)  sendFailed,required TResult Function( String clientMsgId,  int progress,  int totalSize,  int uploadedSize)  uploadProgress,}) {final _that = this;
switch (_that) {
case MessageEvent_NewMessage():
return newMessage(_that.conversationId,_that.message);case MessageEvent_OfflineNewMessage():
return offlineNewMessage(_that.conversationId,_that.message);case MessageEvent_OnlineOnlyMessage():
return onlineOnlyMessage(_that.conversationId,_that.message);case MessageEvent_Revoked():
return revoked(_that.conversationId,_that.seq,_that.clientMsgId,_that.revokerId,_that.revokerRole,_that.revokerNickname,_that.revokeTime,_that.sourceMessageSendTime,_that.sourceMessageSendId,_that.sourceMessageSenderNickname,_that.sessionType,_that.isAdminRevoke);case MessageEvent_C2CReadReceipt():
return c2CReadReceipt(_that.receipts);case MessageEvent_Deleted():
return deleted(_that.conversationId,_that.clientMsgIds);case MessageEvent_SendFailed():
return sendFailed(_that.clientMsgId,_that.error);case MessageEvent_UploadProgress():
return uploadProgress(_that.clientMsgId,_that.progress,_that.totalSize,_that.uploadedSize);}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( String conversationId,  MessageInfo message)?  newMessage,TResult? Function( String conversationId,  MessageInfo message)?  offlineNewMessage,TResult? Function( String conversationId,  MessageInfo message)?  onlineOnlyMessage,TResult? Function( String conversationId,  int seq,  String clientMsgId,  String revokerId,  int revokerRole,  String revokerNickname,  int revokeTime,  int sourceMessageSendTime,  String sourceMessageSendId,  String sourceMessageSenderNickname,  int sessionType,  bool isAdminRevoke)?  revoked,TResult? Function( List<MessageReceipt> receipts)?  c2CReadReceipt,TResult? Function( String conversationId,  List<String> clientMsgIds)?  deleted,TResult? Function( String clientMsgId,  String error)?  sendFailed,TResult? Function( String clientMsgId,  int progress,  int totalSize,  int uploadedSize)?  uploadProgress,}) {final _that = this;
switch (_that) {
case MessageEvent_NewMessage() when newMessage != null:
return newMessage(_that.conversationId,_that.message);case MessageEvent_OfflineNewMessage() when offlineNewMessage != null:
return offlineNewMessage(_that.conversationId,_that.message);case MessageEvent_OnlineOnlyMessage() when onlineOnlyMessage != null:
return onlineOnlyMessage(_that.conversationId,_that.message);case MessageEvent_Revoked() when revoked != null:
return revoked(_that.conversationId,_that.seq,_that.clientMsgId,_that.revokerId,_that.revokerRole,_that.revokerNickname,_that.revokeTime,_that.sourceMessageSendTime,_that.sourceMessageSendId,_that.sourceMessageSenderNickname,_that.sessionType,_that.isAdminRevoke);case MessageEvent_C2CReadReceipt() when c2CReadReceipt != null:
return c2CReadReceipt(_that.receipts);case MessageEvent_Deleted() when deleted != null:
return deleted(_that.conversationId,_that.clientMsgIds);case MessageEvent_SendFailed() when sendFailed != null:
return sendFailed(_that.clientMsgId,_that.error);case MessageEvent_UploadProgress() when uploadProgress != null:
return uploadProgress(_that.clientMsgId,_that.progress,_that.totalSize,_that.uploadedSize);case _:
  return null;

}
}

}

/// @nodoc


class MessageEvent_NewMessage extends MessageEvent {
  const MessageEvent_NewMessage({required this.conversationId, required this.message}): super._();
  

 final  String conversationId;
 final  MessageInfo message;

/// Create a copy of MessageEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MessageEvent_NewMessageCopyWith<MessageEvent_NewMessage> get copyWith => _$MessageEvent_NewMessageCopyWithImpl<MessageEvent_NewMessage>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MessageEvent_NewMessage&&(identical(other.conversationId, conversationId) || other.conversationId == conversationId)&&(identical(other.message, message) || other.message == message));
}


@override
int get hashCode => Object.hash(runtimeType,conversationId,message);

@override
String toString() {
  return 'MessageEvent.newMessage(conversationId: $conversationId, message: $message)';
}


}

/// @nodoc
abstract mixin class $MessageEvent_NewMessageCopyWith<$Res> implements $MessageEventCopyWith<$Res> {
  factory $MessageEvent_NewMessageCopyWith(MessageEvent_NewMessage value, $Res Function(MessageEvent_NewMessage) _then) = _$MessageEvent_NewMessageCopyWithImpl;
@useResult
$Res call({
 String conversationId, MessageInfo message
});




}
/// @nodoc
class _$MessageEvent_NewMessageCopyWithImpl<$Res>
    implements $MessageEvent_NewMessageCopyWith<$Res> {
  _$MessageEvent_NewMessageCopyWithImpl(this._self, this._then);

  final MessageEvent_NewMessage _self;
  final $Res Function(MessageEvent_NewMessage) _then;

/// Create a copy of MessageEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? conversationId = null,Object? message = null,}) {
  return _then(MessageEvent_NewMessage(
conversationId: null == conversationId ? _self.conversationId : conversationId // ignore: cast_nullable_to_non_nullable
as String,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as MessageInfo,
  ));
}


}

/// @nodoc


class MessageEvent_OfflineNewMessage extends MessageEvent {
  const MessageEvent_OfflineNewMessage({required this.conversationId, required this.message}): super._();
  

 final  String conversationId;
 final  MessageInfo message;

/// Create a copy of MessageEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MessageEvent_OfflineNewMessageCopyWith<MessageEvent_OfflineNewMessage> get copyWith => _$MessageEvent_OfflineNewMessageCopyWithImpl<MessageEvent_OfflineNewMessage>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MessageEvent_OfflineNewMessage&&(identical(other.conversationId, conversationId) || other.conversationId == conversationId)&&(identical(other.message, message) || other.message == message));
}


@override
int get hashCode => Object.hash(runtimeType,conversationId,message);

@override
String toString() {
  return 'MessageEvent.offlineNewMessage(conversationId: $conversationId, message: $message)';
}


}

/// @nodoc
abstract mixin class $MessageEvent_OfflineNewMessageCopyWith<$Res> implements $MessageEventCopyWith<$Res> {
  factory $MessageEvent_OfflineNewMessageCopyWith(MessageEvent_OfflineNewMessage value, $Res Function(MessageEvent_OfflineNewMessage) _then) = _$MessageEvent_OfflineNewMessageCopyWithImpl;
@useResult
$Res call({
 String conversationId, MessageInfo message
});




}
/// @nodoc
class _$MessageEvent_OfflineNewMessageCopyWithImpl<$Res>
    implements $MessageEvent_OfflineNewMessageCopyWith<$Res> {
  _$MessageEvent_OfflineNewMessageCopyWithImpl(this._self, this._then);

  final MessageEvent_OfflineNewMessage _self;
  final $Res Function(MessageEvent_OfflineNewMessage) _then;

/// Create a copy of MessageEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? conversationId = null,Object? message = null,}) {
  return _then(MessageEvent_OfflineNewMessage(
conversationId: null == conversationId ? _self.conversationId : conversationId // ignore: cast_nullable_to_non_nullable
as String,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as MessageInfo,
  ));
}


}

/// @nodoc


class MessageEvent_OnlineOnlyMessage extends MessageEvent {
  const MessageEvent_OnlineOnlyMessage({required this.conversationId, required this.message}): super._();
  

 final  String conversationId;
 final  MessageInfo message;

/// Create a copy of MessageEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MessageEvent_OnlineOnlyMessageCopyWith<MessageEvent_OnlineOnlyMessage> get copyWith => _$MessageEvent_OnlineOnlyMessageCopyWithImpl<MessageEvent_OnlineOnlyMessage>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MessageEvent_OnlineOnlyMessage&&(identical(other.conversationId, conversationId) || other.conversationId == conversationId)&&(identical(other.message, message) || other.message == message));
}


@override
int get hashCode => Object.hash(runtimeType,conversationId,message);

@override
String toString() {
  return 'MessageEvent.onlineOnlyMessage(conversationId: $conversationId, message: $message)';
}


}

/// @nodoc
abstract mixin class $MessageEvent_OnlineOnlyMessageCopyWith<$Res> implements $MessageEventCopyWith<$Res> {
  factory $MessageEvent_OnlineOnlyMessageCopyWith(MessageEvent_OnlineOnlyMessage value, $Res Function(MessageEvent_OnlineOnlyMessage) _then) = _$MessageEvent_OnlineOnlyMessageCopyWithImpl;
@useResult
$Res call({
 String conversationId, MessageInfo message
});




}
/// @nodoc
class _$MessageEvent_OnlineOnlyMessageCopyWithImpl<$Res>
    implements $MessageEvent_OnlineOnlyMessageCopyWith<$Res> {
  _$MessageEvent_OnlineOnlyMessageCopyWithImpl(this._self, this._then);

  final MessageEvent_OnlineOnlyMessage _self;
  final $Res Function(MessageEvent_OnlineOnlyMessage) _then;

/// Create a copy of MessageEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? conversationId = null,Object? message = null,}) {
  return _then(MessageEvent_OnlineOnlyMessage(
conversationId: null == conversationId ? _self.conversationId : conversationId // ignore: cast_nullable_to_non_nullable
as String,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as MessageInfo,
  ));
}


}

/// @nodoc


class MessageEvent_Revoked extends MessageEvent {
  const MessageEvent_Revoked({required this.conversationId, required this.seq, required this.clientMsgId, required this.revokerId, required this.revokerRole, required this.revokerNickname, required this.revokeTime, required this.sourceMessageSendTime, required this.sourceMessageSendId, required this.sourceMessageSenderNickname, required this.sessionType, required this.isAdminRevoke}): super._();
  

 final  String conversationId;
 final  int seq;
 final  String clientMsgId;
 final  String revokerId;
 final  int revokerRole;
 final  String revokerNickname;
 final  int revokeTime;
 final  int sourceMessageSendTime;
 final  String sourceMessageSendId;
 final  String sourceMessageSenderNickname;
 final  int sessionType;
 final  bool isAdminRevoke;

/// Create a copy of MessageEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MessageEvent_RevokedCopyWith<MessageEvent_Revoked> get copyWith => _$MessageEvent_RevokedCopyWithImpl<MessageEvent_Revoked>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MessageEvent_Revoked&&(identical(other.conversationId, conversationId) || other.conversationId == conversationId)&&(identical(other.seq, seq) || other.seq == seq)&&(identical(other.clientMsgId, clientMsgId) || other.clientMsgId == clientMsgId)&&(identical(other.revokerId, revokerId) || other.revokerId == revokerId)&&(identical(other.revokerRole, revokerRole) || other.revokerRole == revokerRole)&&(identical(other.revokerNickname, revokerNickname) || other.revokerNickname == revokerNickname)&&(identical(other.revokeTime, revokeTime) || other.revokeTime == revokeTime)&&(identical(other.sourceMessageSendTime, sourceMessageSendTime) || other.sourceMessageSendTime == sourceMessageSendTime)&&(identical(other.sourceMessageSendId, sourceMessageSendId) || other.sourceMessageSendId == sourceMessageSendId)&&(identical(other.sourceMessageSenderNickname, sourceMessageSenderNickname) || other.sourceMessageSenderNickname == sourceMessageSenderNickname)&&(identical(other.sessionType, sessionType) || other.sessionType == sessionType)&&(identical(other.isAdminRevoke, isAdminRevoke) || other.isAdminRevoke == isAdminRevoke));
}


@override
int get hashCode => Object.hash(runtimeType,conversationId,seq,clientMsgId,revokerId,revokerRole,revokerNickname,revokeTime,sourceMessageSendTime,sourceMessageSendId,sourceMessageSenderNickname,sessionType,isAdminRevoke);

@override
String toString() {
  return 'MessageEvent.revoked(conversationId: $conversationId, seq: $seq, clientMsgId: $clientMsgId, revokerId: $revokerId, revokerRole: $revokerRole, revokerNickname: $revokerNickname, revokeTime: $revokeTime, sourceMessageSendTime: $sourceMessageSendTime, sourceMessageSendId: $sourceMessageSendId, sourceMessageSenderNickname: $sourceMessageSenderNickname, sessionType: $sessionType, isAdminRevoke: $isAdminRevoke)';
}


}

/// @nodoc
abstract mixin class $MessageEvent_RevokedCopyWith<$Res> implements $MessageEventCopyWith<$Res> {
  factory $MessageEvent_RevokedCopyWith(MessageEvent_Revoked value, $Res Function(MessageEvent_Revoked) _then) = _$MessageEvent_RevokedCopyWithImpl;
@useResult
$Res call({
 String conversationId, int seq, String clientMsgId, String revokerId, int revokerRole, String revokerNickname, int revokeTime, int sourceMessageSendTime, String sourceMessageSendId, String sourceMessageSenderNickname, int sessionType, bool isAdminRevoke
});




}
/// @nodoc
class _$MessageEvent_RevokedCopyWithImpl<$Res>
    implements $MessageEvent_RevokedCopyWith<$Res> {
  _$MessageEvent_RevokedCopyWithImpl(this._self, this._then);

  final MessageEvent_Revoked _self;
  final $Res Function(MessageEvent_Revoked) _then;

/// Create a copy of MessageEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? conversationId = null,Object? seq = null,Object? clientMsgId = null,Object? revokerId = null,Object? revokerRole = null,Object? revokerNickname = null,Object? revokeTime = null,Object? sourceMessageSendTime = null,Object? sourceMessageSendId = null,Object? sourceMessageSenderNickname = null,Object? sessionType = null,Object? isAdminRevoke = null,}) {
  return _then(MessageEvent_Revoked(
conversationId: null == conversationId ? _self.conversationId : conversationId // ignore: cast_nullable_to_non_nullable
as String,seq: null == seq ? _self.seq : seq // ignore: cast_nullable_to_non_nullable
as int,clientMsgId: null == clientMsgId ? _self.clientMsgId : clientMsgId // ignore: cast_nullable_to_non_nullable
as String,revokerId: null == revokerId ? _self.revokerId : revokerId // ignore: cast_nullable_to_non_nullable
as String,revokerRole: null == revokerRole ? _self.revokerRole : revokerRole // ignore: cast_nullable_to_non_nullable
as int,revokerNickname: null == revokerNickname ? _self.revokerNickname : revokerNickname // ignore: cast_nullable_to_non_nullable
as String,revokeTime: null == revokeTime ? _self.revokeTime : revokeTime // ignore: cast_nullable_to_non_nullable
as int,sourceMessageSendTime: null == sourceMessageSendTime ? _self.sourceMessageSendTime : sourceMessageSendTime // ignore: cast_nullable_to_non_nullable
as int,sourceMessageSendId: null == sourceMessageSendId ? _self.sourceMessageSendId : sourceMessageSendId // ignore: cast_nullable_to_non_nullable
as String,sourceMessageSenderNickname: null == sourceMessageSenderNickname ? _self.sourceMessageSenderNickname : sourceMessageSenderNickname // ignore: cast_nullable_to_non_nullable
as String,sessionType: null == sessionType ? _self.sessionType : sessionType // ignore: cast_nullable_to_non_nullable
as int,isAdminRevoke: null == isAdminRevoke ? _self.isAdminRevoke : isAdminRevoke // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc


class MessageEvent_C2CReadReceipt extends MessageEvent {
  const MessageEvent_C2CReadReceipt({required final  List<MessageReceipt> receipts}): _receipts = receipts,super._();
  

 final  List<MessageReceipt> _receipts;
 List<MessageReceipt> get receipts {
  if (_receipts is EqualUnmodifiableListView) return _receipts;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_receipts);
}


/// Create a copy of MessageEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MessageEvent_C2CReadReceiptCopyWith<MessageEvent_C2CReadReceipt> get copyWith => _$MessageEvent_C2CReadReceiptCopyWithImpl<MessageEvent_C2CReadReceipt>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MessageEvent_C2CReadReceipt&&const DeepCollectionEquality().equals(other._receipts, _receipts));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_receipts));

@override
String toString() {
  return 'MessageEvent.c2CReadReceipt(receipts: $receipts)';
}


}

/// @nodoc
abstract mixin class $MessageEvent_C2CReadReceiptCopyWith<$Res> implements $MessageEventCopyWith<$Res> {
  factory $MessageEvent_C2CReadReceiptCopyWith(MessageEvent_C2CReadReceipt value, $Res Function(MessageEvent_C2CReadReceipt) _then) = _$MessageEvent_C2CReadReceiptCopyWithImpl;
@useResult
$Res call({
 List<MessageReceipt> receipts
});




}
/// @nodoc
class _$MessageEvent_C2CReadReceiptCopyWithImpl<$Res>
    implements $MessageEvent_C2CReadReceiptCopyWith<$Res> {
  _$MessageEvent_C2CReadReceiptCopyWithImpl(this._self, this._then);

  final MessageEvent_C2CReadReceipt _self;
  final $Res Function(MessageEvent_C2CReadReceipt) _then;

/// Create a copy of MessageEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? receipts = null,}) {
  return _then(MessageEvent_C2CReadReceipt(
receipts: null == receipts ? _self._receipts : receipts // ignore: cast_nullable_to_non_nullable
as List<MessageReceipt>,
  ));
}


}

/// @nodoc


class MessageEvent_Deleted extends MessageEvent {
  const MessageEvent_Deleted({required this.conversationId, required final  List<String> clientMsgIds}): _clientMsgIds = clientMsgIds,super._();
  

 final  String conversationId;
 final  List<String> _clientMsgIds;
 List<String> get clientMsgIds {
  if (_clientMsgIds is EqualUnmodifiableListView) return _clientMsgIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_clientMsgIds);
}


/// Create a copy of MessageEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MessageEvent_DeletedCopyWith<MessageEvent_Deleted> get copyWith => _$MessageEvent_DeletedCopyWithImpl<MessageEvent_Deleted>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MessageEvent_Deleted&&(identical(other.conversationId, conversationId) || other.conversationId == conversationId)&&const DeepCollectionEquality().equals(other._clientMsgIds, _clientMsgIds));
}


@override
int get hashCode => Object.hash(runtimeType,conversationId,const DeepCollectionEquality().hash(_clientMsgIds));

@override
String toString() {
  return 'MessageEvent.deleted(conversationId: $conversationId, clientMsgIds: $clientMsgIds)';
}


}

/// @nodoc
abstract mixin class $MessageEvent_DeletedCopyWith<$Res> implements $MessageEventCopyWith<$Res> {
  factory $MessageEvent_DeletedCopyWith(MessageEvent_Deleted value, $Res Function(MessageEvent_Deleted) _then) = _$MessageEvent_DeletedCopyWithImpl;
@useResult
$Res call({
 String conversationId, List<String> clientMsgIds
});




}
/// @nodoc
class _$MessageEvent_DeletedCopyWithImpl<$Res>
    implements $MessageEvent_DeletedCopyWith<$Res> {
  _$MessageEvent_DeletedCopyWithImpl(this._self, this._then);

  final MessageEvent_Deleted _self;
  final $Res Function(MessageEvent_Deleted) _then;

/// Create a copy of MessageEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? conversationId = null,Object? clientMsgIds = null,}) {
  return _then(MessageEvent_Deleted(
conversationId: null == conversationId ? _self.conversationId : conversationId // ignore: cast_nullable_to_non_nullable
as String,clientMsgIds: null == clientMsgIds ? _self._clientMsgIds : clientMsgIds // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}

/// @nodoc


class MessageEvent_SendFailed extends MessageEvent {
  const MessageEvent_SendFailed({required this.clientMsgId, required this.error}): super._();
  

 final  String clientMsgId;
 final  String error;

/// Create a copy of MessageEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MessageEvent_SendFailedCopyWith<MessageEvent_SendFailed> get copyWith => _$MessageEvent_SendFailedCopyWithImpl<MessageEvent_SendFailed>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MessageEvent_SendFailed&&(identical(other.clientMsgId, clientMsgId) || other.clientMsgId == clientMsgId)&&(identical(other.error, error) || other.error == error));
}


@override
int get hashCode => Object.hash(runtimeType,clientMsgId,error);

@override
String toString() {
  return 'MessageEvent.sendFailed(clientMsgId: $clientMsgId, error: $error)';
}


}

/// @nodoc
abstract mixin class $MessageEvent_SendFailedCopyWith<$Res> implements $MessageEventCopyWith<$Res> {
  factory $MessageEvent_SendFailedCopyWith(MessageEvent_SendFailed value, $Res Function(MessageEvent_SendFailed) _then) = _$MessageEvent_SendFailedCopyWithImpl;
@useResult
$Res call({
 String clientMsgId, String error
});




}
/// @nodoc
class _$MessageEvent_SendFailedCopyWithImpl<$Res>
    implements $MessageEvent_SendFailedCopyWith<$Res> {
  _$MessageEvent_SendFailedCopyWithImpl(this._self, this._then);

  final MessageEvent_SendFailed _self;
  final $Res Function(MessageEvent_SendFailed) _then;

/// Create a copy of MessageEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? clientMsgId = null,Object? error = null,}) {
  return _then(MessageEvent_SendFailed(
clientMsgId: null == clientMsgId ? _self.clientMsgId : clientMsgId // ignore: cast_nullable_to_non_nullable
as String,error: null == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class MessageEvent_UploadProgress extends MessageEvent {
  const MessageEvent_UploadProgress({required this.clientMsgId, required this.progress, required this.totalSize, required this.uploadedSize}): super._();
  

 final  String clientMsgId;
 final  int progress;
 final  int totalSize;
 final  int uploadedSize;

/// Create a copy of MessageEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MessageEvent_UploadProgressCopyWith<MessageEvent_UploadProgress> get copyWith => _$MessageEvent_UploadProgressCopyWithImpl<MessageEvent_UploadProgress>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MessageEvent_UploadProgress&&(identical(other.clientMsgId, clientMsgId) || other.clientMsgId == clientMsgId)&&(identical(other.progress, progress) || other.progress == progress)&&(identical(other.totalSize, totalSize) || other.totalSize == totalSize)&&(identical(other.uploadedSize, uploadedSize) || other.uploadedSize == uploadedSize));
}


@override
int get hashCode => Object.hash(runtimeType,clientMsgId,progress,totalSize,uploadedSize);

@override
String toString() {
  return 'MessageEvent.uploadProgress(clientMsgId: $clientMsgId, progress: $progress, totalSize: $totalSize, uploadedSize: $uploadedSize)';
}


}

/// @nodoc
abstract mixin class $MessageEvent_UploadProgressCopyWith<$Res> implements $MessageEventCopyWith<$Res> {
  factory $MessageEvent_UploadProgressCopyWith(MessageEvent_UploadProgress value, $Res Function(MessageEvent_UploadProgress) _then) = _$MessageEvent_UploadProgressCopyWithImpl;
@useResult
$Res call({
 String clientMsgId, int progress, int totalSize, int uploadedSize
});




}
/// @nodoc
class _$MessageEvent_UploadProgressCopyWithImpl<$Res>
    implements $MessageEvent_UploadProgressCopyWith<$Res> {
  _$MessageEvent_UploadProgressCopyWithImpl(this._self, this._then);

  final MessageEvent_UploadProgress _self;
  final $Res Function(MessageEvent_UploadProgress) _then;

/// Create a copy of MessageEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? clientMsgId = null,Object? progress = null,Object? totalSize = null,Object? uploadedSize = null,}) {
  return _then(MessageEvent_UploadProgress(
clientMsgId: null == clientMsgId ? _self.clientMsgId : clientMsgId // ignore: cast_nullable_to_non_nullable
as String,progress: null == progress ? _self.progress : progress // ignore: cast_nullable_to_non_nullable
as int,totalSize: null == totalSize ? _self.totalSize : totalSize // ignore: cast_nullable_to_non_nullable
as int,uploadedSize: null == uploadedSize ? _self.uploadedSize : uploadedSize // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
