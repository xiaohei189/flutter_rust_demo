// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'conversation.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Conversation {

 String get conversationId; int get conversationType; String get userId; String get groupId; String get showName; String get faceUrl; String get latestMsg; int get latestMsgSendTime; int get unreadCount; int get recvMsgOpt; bool get isPinned; bool get isPrivateChat; int get burnDuration; int get groupAtType; bool get isNotInGroup; int get updateUnreadCountTime; String get attachedInfo; String get ex; String get draftText; int get draftTextTime; int get maxSeq; int get minSeq; bool get isMsgDestruct; int get msgDestructTime;
/// Create a copy of Conversation
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ConversationCopyWith<Conversation> get copyWith => _$ConversationCopyWithImpl<Conversation>(this as Conversation, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Conversation&&(identical(other.conversationId, conversationId) || other.conversationId == conversationId)&&(identical(other.conversationType, conversationType) || other.conversationType == conversationType)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.groupId, groupId) || other.groupId == groupId)&&(identical(other.showName, showName) || other.showName == showName)&&(identical(other.faceUrl, faceUrl) || other.faceUrl == faceUrl)&&(identical(other.latestMsg, latestMsg) || other.latestMsg == latestMsg)&&(identical(other.latestMsgSendTime, latestMsgSendTime) || other.latestMsgSendTime == latestMsgSendTime)&&(identical(other.unreadCount, unreadCount) || other.unreadCount == unreadCount)&&(identical(other.recvMsgOpt, recvMsgOpt) || other.recvMsgOpt == recvMsgOpt)&&(identical(other.isPinned, isPinned) || other.isPinned == isPinned)&&(identical(other.isPrivateChat, isPrivateChat) || other.isPrivateChat == isPrivateChat)&&(identical(other.burnDuration, burnDuration) || other.burnDuration == burnDuration)&&(identical(other.groupAtType, groupAtType) || other.groupAtType == groupAtType)&&(identical(other.isNotInGroup, isNotInGroup) || other.isNotInGroup == isNotInGroup)&&(identical(other.updateUnreadCountTime, updateUnreadCountTime) || other.updateUnreadCountTime == updateUnreadCountTime)&&(identical(other.attachedInfo, attachedInfo) || other.attachedInfo == attachedInfo)&&(identical(other.ex, ex) || other.ex == ex)&&(identical(other.draftText, draftText) || other.draftText == draftText)&&(identical(other.draftTextTime, draftTextTime) || other.draftTextTime == draftTextTime)&&(identical(other.maxSeq, maxSeq) || other.maxSeq == maxSeq)&&(identical(other.minSeq, minSeq) || other.minSeq == minSeq)&&(identical(other.isMsgDestruct, isMsgDestruct) || other.isMsgDestruct == isMsgDestruct)&&(identical(other.msgDestructTime, msgDestructTime) || other.msgDestructTime == msgDestructTime));
}


@override
int get hashCode => Object.hashAll([runtimeType,conversationId,conversationType,userId,groupId,showName,faceUrl,latestMsg,latestMsgSendTime,unreadCount,recvMsgOpt,isPinned,isPrivateChat,burnDuration,groupAtType,isNotInGroup,updateUnreadCountTime,attachedInfo,ex,draftText,draftTextTime,maxSeq,minSeq,isMsgDestruct,msgDestructTime]);

@override
String toString() {
  return 'Conversation(conversationId: $conversationId, conversationType: $conversationType, userId: $userId, groupId: $groupId, showName: $showName, faceUrl: $faceUrl, latestMsg: $latestMsg, latestMsgSendTime: $latestMsgSendTime, unreadCount: $unreadCount, recvMsgOpt: $recvMsgOpt, isPinned: $isPinned, isPrivateChat: $isPrivateChat, burnDuration: $burnDuration, groupAtType: $groupAtType, isNotInGroup: $isNotInGroup, updateUnreadCountTime: $updateUnreadCountTime, attachedInfo: $attachedInfo, ex: $ex, draftText: $draftText, draftTextTime: $draftTextTime, maxSeq: $maxSeq, minSeq: $minSeq, isMsgDestruct: $isMsgDestruct, msgDestructTime: $msgDestructTime)';
}


}

/// @nodoc
abstract mixin class $ConversationCopyWith<$Res>  {
  factory $ConversationCopyWith(Conversation value, $Res Function(Conversation) _then) = _$ConversationCopyWithImpl;
@useResult
$Res call({
 String conversationId, int conversationType, String userId, String groupId, String showName, String faceUrl, String latestMsg, int latestMsgSendTime, int unreadCount, int recvMsgOpt, bool isPinned, bool isPrivateChat, int burnDuration, int groupAtType, bool isNotInGroup, int updateUnreadCountTime, String attachedInfo, String ex, String draftText, int draftTextTime, int maxSeq, int minSeq, bool isMsgDestruct, int msgDestructTime
});




}
/// @nodoc
class _$ConversationCopyWithImpl<$Res>
    implements $ConversationCopyWith<$Res> {
  _$ConversationCopyWithImpl(this._self, this._then);

  final Conversation _self;
  final $Res Function(Conversation) _then;

/// Create a copy of Conversation
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? conversationId = null,Object? conversationType = null,Object? userId = null,Object? groupId = null,Object? showName = null,Object? faceUrl = null,Object? latestMsg = null,Object? latestMsgSendTime = null,Object? unreadCount = null,Object? recvMsgOpt = null,Object? isPinned = null,Object? isPrivateChat = null,Object? burnDuration = null,Object? groupAtType = null,Object? isNotInGroup = null,Object? updateUnreadCountTime = null,Object? attachedInfo = null,Object? ex = null,Object? draftText = null,Object? draftTextTime = null,Object? maxSeq = null,Object? minSeq = null,Object? isMsgDestruct = null,Object? msgDestructTime = null,}) {
  return _then(_self.copyWith(
conversationId: null == conversationId ? _self.conversationId : conversationId // ignore: cast_nullable_to_non_nullable
as String,conversationType: null == conversationType ? _self.conversationType : conversationType // ignore: cast_nullable_to_non_nullable
as int,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,groupId: null == groupId ? _self.groupId : groupId // ignore: cast_nullable_to_non_nullable
as String,showName: null == showName ? _self.showName : showName // ignore: cast_nullable_to_non_nullable
as String,faceUrl: null == faceUrl ? _self.faceUrl : faceUrl // ignore: cast_nullable_to_non_nullable
as String,latestMsg: null == latestMsg ? _self.latestMsg : latestMsg // ignore: cast_nullable_to_non_nullable
as String,latestMsgSendTime: null == latestMsgSendTime ? _self.latestMsgSendTime : latestMsgSendTime // ignore: cast_nullable_to_non_nullable
as int,unreadCount: null == unreadCount ? _self.unreadCount : unreadCount // ignore: cast_nullable_to_non_nullable
as int,recvMsgOpt: null == recvMsgOpt ? _self.recvMsgOpt : recvMsgOpt // ignore: cast_nullable_to_non_nullable
as int,isPinned: null == isPinned ? _self.isPinned : isPinned // ignore: cast_nullable_to_non_nullable
as bool,isPrivateChat: null == isPrivateChat ? _self.isPrivateChat : isPrivateChat // ignore: cast_nullable_to_non_nullable
as bool,burnDuration: null == burnDuration ? _self.burnDuration : burnDuration // ignore: cast_nullable_to_non_nullable
as int,groupAtType: null == groupAtType ? _self.groupAtType : groupAtType // ignore: cast_nullable_to_non_nullable
as int,isNotInGroup: null == isNotInGroup ? _self.isNotInGroup : isNotInGroup // ignore: cast_nullable_to_non_nullable
as bool,updateUnreadCountTime: null == updateUnreadCountTime ? _self.updateUnreadCountTime : updateUnreadCountTime // ignore: cast_nullable_to_non_nullable
as int,attachedInfo: null == attachedInfo ? _self.attachedInfo : attachedInfo // ignore: cast_nullable_to_non_nullable
as String,ex: null == ex ? _self.ex : ex // ignore: cast_nullable_to_non_nullable
as String,draftText: null == draftText ? _self.draftText : draftText // ignore: cast_nullable_to_non_nullable
as String,draftTextTime: null == draftTextTime ? _self.draftTextTime : draftTextTime // ignore: cast_nullable_to_non_nullable
as int,maxSeq: null == maxSeq ? _self.maxSeq : maxSeq // ignore: cast_nullable_to_non_nullable
as int,minSeq: null == minSeq ? _self.minSeq : minSeq // ignore: cast_nullable_to_non_nullable
as int,isMsgDestruct: null == isMsgDestruct ? _self.isMsgDestruct : isMsgDestruct // ignore: cast_nullable_to_non_nullable
as bool,msgDestructTime: null == msgDestructTime ? _self.msgDestructTime : msgDestructTime // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [Conversation].
extension ConversationPatterns on Conversation {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Conversation value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Conversation() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Conversation value)  $default,){
final _that = this;
switch (_that) {
case _Conversation():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Conversation value)?  $default,){
final _that = this;
switch (_that) {
case _Conversation() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String conversationId,  int conversationType,  String userId,  String groupId,  String showName,  String faceUrl,  String latestMsg,  int latestMsgSendTime,  int unreadCount,  int recvMsgOpt,  bool isPinned,  bool isPrivateChat,  int burnDuration,  int groupAtType,  bool isNotInGroup,  int updateUnreadCountTime,  String attachedInfo,  String ex,  String draftText,  int draftTextTime,  int maxSeq,  int minSeq,  bool isMsgDestruct,  int msgDestructTime)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Conversation() when $default != null:
return $default(_that.conversationId,_that.conversationType,_that.userId,_that.groupId,_that.showName,_that.faceUrl,_that.latestMsg,_that.latestMsgSendTime,_that.unreadCount,_that.recvMsgOpt,_that.isPinned,_that.isPrivateChat,_that.burnDuration,_that.groupAtType,_that.isNotInGroup,_that.updateUnreadCountTime,_that.attachedInfo,_that.ex,_that.draftText,_that.draftTextTime,_that.maxSeq,_that.minSeq,_that.isMsgDestruct,_that.msgDestructTime);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String conversationId,  int conversationType,  String userId,  String groupId,  String showName,  String faceUrl,  String latestMsg,  int latestMsgSendTime,  int unreadCount,  int recvMsgOpt,  bool isPinned,  bool isPrivateChat,  int burnDuration,  int groupAtType,  bool isNotInGroup,  int updateUnreadCountTime,  String attachedInfo,  String ex,  String draftText,  int draftTextTime,  int maxSeq,  int minSeq,  bool isMsgDestruct,  int msgDestructTime)  $default,) {final _that = this;
switch (_that) {
case _Conversation():
return $default(_that.conversationId,_that.conversationType,_that.userId,_that.groupId,_that.showName,_that.faceUrl,_that.latestMsg,_that.latestMsgSendTime,_that.unreadCount,_that.recvMsgOpt,_that.isPinned,_that.isPrivateChat,_that.burnDuration,_that.groupAtType,_that.isNotInGroup,_that.updateUnreadCountTime,_that.attachedInfo,_that.ex,_that.draftText,_that.draftTextTime,_that.maxSeq,_that.minSeq,_that.isMsgDestruct,_that.msgDestructTime);case _:
  throw StateError('Unexpected subclass');

}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String conversationId,  int conversationType,  String userId,  String groupId,  String showName,  String faceUrl,  String latestMsg,  int latestMsgSendTime,  int unreadCount,  int recvMsgOpt,  bool isPinned,  bool isPrivateChat,  int burnDuration,  int groupAtType,  bool isNotInGroup,  int updateUnreadCountTime,  String attachedInfo,  String ex,  String draftText,  int draftTextTime,  int maxSeq,  int minSeq,  bool isMsgDestruct,  int msgDestructTime)?  $default,) {final _that = this;
switch (_that) {
case _Conversation() when $default != null:
return $default(_that.conversationId,_that.conversationType,_that.userId,_that.groupId,_that.showName,_that.faceUrl,_that.latestMsg,_that.latestMsgSendTime,_that.unreadCount,_that.recvMsgOpt,_that.isPinned,_that.isPrivateChat,_that.burnDuration,_that.groupAtType,_that.isNotInGroup,_that.updateUnreadCountTime,_that.attachedInfo,_that.ex,_that.draftText,_that.draftTextTime,_that.maxSeq,_that.minSeq,_that.isMsgDestruct,_that.msgDestructTime);case _:
  return null;

}
}

}

/// @nodoc


class _Conversation implements Conversation {
  const _Conversation({required this.conversationId, required this.conversationType, required this.userId, required this.groupId, required this.showName, required this.faceUrl, required this.latestMsg, required this.latestMsgSendTime, required this.unreadCount, required this.recvMsgOpt, required this.isPinned, required this.isPrivateChat, required this.burnDuration, required this.groupAtType, required this.isNotInGroup, required this.updateUnreadCountTime, required this.attachedInfo, required this.ex, required this.draftText, required this.draftTextTime, required this.maxSeq, required this.minSeq, required this.isMsgDestruct, required this.msgDestructTime});
  

@override final  String conversationId;
@override final  int conversationType;
@override final  String userId;
@override final  String groupId;
@override final  String showName;
@override final  String faceUrl;
@override final  String latestMsg;
@override final  int latestMsgSendTime;
@override final  int unreadCount;
@override final  int recvMsgOpt;
@override final  bool isPinned;
@override final  bool isPrivateChat;
@override final  int burnDuration;
@override final  int groupAtType;
@override final  bool isNotInGroup;
@override final  int updateUnreadCountTime;
@override final  String attachedInfo;
@override final  String ex;
@override final  String draftText;
@override final  int draftTextTime;
@override final  int maxSeq;
@override final  int minSeq;
@override final  bool isMsgDestruct;
@override final  int msgDestructTime;

/// Create a copy of Conversation
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ConversationCopyWith<_Conversation> get copyWith => __$ConversationCopyWithImpl<_Conversation>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Conversation&&(identical(other.conversationId, conversationId) || other.conversationId == conversationId)&&(identical(other.conversationType, conversationType) || other.conversationType == conversationType)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.groupId, groupId) || other.groupId == groupId)&&(identical(other.showName, showName) || other.showName == showName)&&(identical(other.faceUrl, faceUrl) || other.faceUrl == faceUrl)&&(identical(other.latestMsg, latestMsg) || other.latestMsg == latestMsg)&&(identical(other.latestMsgSendTime, latestMsgSendTime) || other.latestMsgSendTime == latestMsgSendTime)&&(identical(other.unreadCount, unreadCount) || other.unreadCount == unreadCount)&&(identical(other.recvMsgOpt, recvMsgOpt) || other.recvMsgOpt == recvMsgOpt)&&(identical(other.isPinned, isPinned) || other.isPinned == isPinned)&&(identical(other.isPrivateChat, isPrivateChat) || other.isPrivateChat == isPrivateChat)&&(identical(other.burnDuration, burnDuration) || other.burnDuration == burnDuration)&&(identical(other.groupAtType, groupAtType) || other.groupAtType == groupAtType)&&(identical(other.isNotInGroup, isNotInGroup) || other.isNotInGroup == isNotInGroup)&&(identical(other.updateUnreadCountTime, updateUnreadCountTime) || other.updateUnreadCountTime == updateUnreadCountTime)&&(identical(other.attachedInfo, attachedInfo) || other.attachedInfo == attachedInfo)&&(identical(other.ex, ex) || other.ex == ex)&&(identical(other.draftText, draftText) || other.draftText == draftText)&&(identical(other.draftTextTime, draftTextTime) || other.draftTextTime == draftTextTime)&&(identical(other.maxSeq, maxSeq) || other.maxSeq == maxSeq)&&(identical(other.minSeq, minSeq) || other.minSeq == minSeq)&&(identical(other.isMsgDestruct, isMsgDestruct) || other.isMsgDestruct == isMsgDestruct)&&(identical(other.msgDestructTime, msgDestructTime) || other.msgDestructTime == msgDestructTime));
}


@override
int get hashCode => Object.hashAll([runtimeType,conversationId,conversationType,userId,groupId,showName,faceUrl,latestMsg,latestMsgSendTime,unreadCount,recvMsgOpt,isPinned,isPrivateChat,burnDuration,groupAtType,isNotInGroup,updateUnreadCountTime,attachedInfo,ex,draftText,draftTextTime,maxSeq,minSeq,isMsgDestruct,msgDestructTime]);

@override
String toString() {
  return 'Conversation(conversationId: $conversationId, conversationType: $conversationType, userId: $userId, groupId: $groupId, showName: $showName, faceUrl: $faceUrl, latestMsg: $latestMsg, latestMsgSendTime: $latestMsgSendTime, unreadCount: $unreadCount, recvMsgOpt: $recvMsgOpt, isPinned: $isPinned, isPrivateChat: $isPrivateChat, burnDuration: $burnDuration, groupAtType: $groupAtType, isNotInGroup: $isNotInGroup, updateUnreadCountTime: $updateUnreadCountTime, attachedInfo: $attachedInfo, ex: $ex, draftText: $draftText, draftTextTime: $draftTextTime, maxSeq: $maxSeq, minSeq: $minSeq, isMsgDestruct: $isMsgDestruct, msgDestructTime: $msgDestructTime)';
}


}

/// @nodoc
abstract mixin class _$ConversationCopyWith<$Res> implements $ConversationCopyWith<$Res> {
  factory _$ConversationCopyWith(_Conversation value, $Res Function(_Conversation) _then) = __$ConversationCopyWithImpl;
@override @useResult
$Res call({
 String conversationId, int conversationType, String userId, String groupId, String showName, String faceUrl, String latestMsg, int latestMsgSendTime, int unreadCount, int recvMsgOpt, bool isPinned, bool isPrivateChat, int burnDuration, int groupAtType, bool isNotInGroup, int updateUnreadCountTime, String attachedInfo, String ex, String draftText, int draftTextTime, int maxSeq, int minSeq, bool isMsgDestruct, int msgDestructTime
});




}
/// @nodoc
class __$ConversationCopyWithImpl<$Res>
    implements _$ConversationCopyWith<$Res> {
  __$ConversationCopyWithImpl(this._self, this._then);

  final _Conversation _self;
  final $Res Function(_Conversation) _then;

/// Create a copy of Conversation
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? conversationId = null,Object? conversationType = null,Object? userId = null,Object? groupId = null,Object? showName = null,Object? faceUrl = null,Object? latestMsg = null,Object? latestMsgSendTime = null,Object? unreadCount = null,Object? recvMsgOpt = null,Object? isPinned = null,Object? isPrivateChat = null,Object? burnDuration = null,Object? groupAtType = null,Object? isNotInGroup = null,Object? updateUnreadCountTime = null,Object? attachedInfo = null,Object? ex = null,Object? draftText = null,Object? draftTextTime = null,Object? maxSeq = null,Object? minSeq = null,Object? isMsgDestruct = null,Object? msgDestructTime = null,}) {
  return _then(_Conversation(
conversationId: null == conversationId ? _self.conversationId : conversationId // ignore: cast_nullable_to_non_nullable
as String,conversationType: null == conversationType ? _self.conversationType : conversationType // ignore: cast_nullable_to_non_nullable
as int,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,groupId: null == groupId ? _self.groupId : groupId // ignore: cast_nullable_to_non_nullable
as String,showName: null == showName ? _self.showName : showName // ignore: cast_nullable_to_non_nullable
as String,faceUrl: null == faceUrl ? _self.faceUrl : faceUrl // ignore: cast_nullable_to_non_nullable
as String,latestMsg: null == latestMsg ? _self.latestMsg : latestMsg // ignore: cast_nullable_to_non_nullable
as String,latestMsgSendTime: null == latestMsgSendTime ? _self.latestMsgSendTime : latestMsgSendTime // ignore: cast_nullable_to_non_nullable
as int,unreadCount: null == unreadCount ? _self.unreadCount : unreadCount // ignore: cast_nullable_to_non_nullable
as int,recvMsgOpt: null == recvMsgOpt ? _self.recvMsgOpt : recvMsgOpt // ignore: cast_nullable_to_non_nullable
as int,isPinned: null == isPinned ? _self.isPinned : isPinned // ignore: cast_nullable_to_non_nullable
as bool,isPrivateChat: null == isPrivateChat ? _self.isPrivateChat : isPrivateChat // ignore: cast_nullable_to_non_nullable
as bool,burnDuration: null == burnDuration ? _self.burnDuration : burnDuration // ignore: cast_nullable_to_non_nullable
as int,groupAtType: null == groupAtType ? _self.groupAtType : groupAtType // ignore: cast_nullable_to_non_nullable
as int,isNotInGroup: null == isNotInGroup ? _self.isNotInGroup : isNotInGroup // ignore: cast_nullable_to_non_nullable
as bool,updateUnreadCountTime: null == updateUnreadCountTime ? _self.updateUnreadCountTime : updateUnreadCountTime // ignore: cast_nullable_to_non_nullable
as int,attachedInfo: null == attachedInfo ? _self.attachedInfo : attachedInfo // ignore: cast_nullable_to_non_nullable
as String,ex: null == ex ? _self.ex : ex // ignore: cast_nullable_to_non_nullable
as String,draftText: null == draftText ? _self.draftText : draftText // ignore: cast_nullable_to_non_nullable
as String,draftTextTime: null == draftTextTime ? _self.draftTextTime : draftTextTime // ignore: cast_nullable_to_non_nullable
as int,maxSeq: null == maxSeq ? _self.maxSeq : maxSeq // ignore: cast_nullable_to_non_nullable
as int,minSeq: null == minSeq ? _self.minSeq : minSeq // ignore: cast_nullable_to_non_nullable
as int,isMsgDestruct: null == isMsgDestruct ? _self.isMsgDestruct : isMsgDestruct // ignore: cast_nullable_to_non_nullable
as bool,msgDestructTime: null == msgDestructTime ? _self.msgDestructTime : msgDestructTime // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
