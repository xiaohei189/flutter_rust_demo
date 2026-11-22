// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'chat.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Chat {

 String get id; String get name; String? get avatar; bool get isGroup; int get unreadCount; String get lastMessage; DateTime get lastMessageTime; List<String>? get memberIds; String? get groupId;
/// Create a copy of Chat
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ChatCopyWith<Chat> get copyWith => _$ChatCopyWithImpl<Chat>(this as Chat, _$identity);

  /// Serializes this Chat to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Chat&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.avatar, avatar) || other.avatar == avatar)&&(identical(other.isGroup, isGroup) || other.isGroup == isGroup)&&(identical(other.unreadCount, unreadCount) || other.unreadCount == unreadCount)&&(identical(other.lastMessage, lastMessage) || other.lastMessage == lastMessage)&&(identical(other.lastMessageTime, lastMessageTime) || other.lastMessageTime == lastMessageTime)&&const DeepCollectionEquality().equals(other.memberIds, memberIds)&&(identical(other.groupId, groupId) || other.groupId == groupId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,avatar,isGroup,unreadCount,lastMessage,lastMessageTime,const DeepCollectionEquality().hash(memberIds),groupId);

@override
String toString() {
  return 'Chat(id: $id, name: $name, avatar: $avatar, isGroup: $isGroup, unreadCount: $unreadCount, lastMessage: $lastMessage, lastMessageTime: $lastMessageTime, memberIds: $memberIds, groupId: $groupId)';
}


}

/// @nodoc
abstract mixin class $ChatCopyWith<$Res>  {
  factory $ChatCopyWith(Chat value, $Res Function(Chat) _then) = _$ChatCopyWithImpl;
@useResult
$Res call({
 String id, String name, String? avatar, bool isGroup, int unreadCount, String lastMessage, DateTime lastMessageTime, List<String>? memberIds, String? groupId
});




}
/// @nodoc
class _$ChatCopyWithImpl<$Res>
    implements $ChatCopyWith<$Res> {
  _$ChatCopyWithImpl(this._self, this._then);

  final Chat _self;
  final $Res Function(Chat) _then;

/// Create a copy of Chat
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? avatar = freezed,Object? isGroup = null,Object? unreadCount = null,Object? lastMessage = null,Object? lastMessageTime = null,Object? memberIds = freezed,Object? groupId = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,avatar: freezed == avatar ? _self.avatar : avatar // ignore: cast_nullable_to_non_nullable
as String?,isGroup: null == isGroup ? _self.isGroup : isGroup // ignore: cast_nullable_to_non_nullable
as bool,unreadCount: null == unreadCount ? _self.unreadCount : unreadCount // ignore: cast_nullable_to_non_nullable
as int,lastMessage: null == lastMessage ? _self.lastMessage : lastMessage // ignore: cast_nullable_to_non_nullable
as String,lastMessageTime: null == lastMessageTime ? _self.lastMessageTime : lastMessageTime // ignore: cast_nullable_to_non_nullable
as DateTime,memberIds: freezed == memberIds ? _self.memberIds : memberIds // ignore: cast_nullable_to_non_nullable
as List<String>?,groupId: freezed == groupId ? _self.groupId : groupId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [Chat].
extension ChatPatterns on Chat {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Chat value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Chat() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Chat value)  $default,){
final _that = this;
switch (_that) {
case _Chat():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Chat value)?  $default,){
final _that = this;
switch (_that) {
case _Chat() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String? avatar,  bool isGroup,  int unreadCount,  String lastMessage,  DateTime lastMessageTime,  List<String>? memberIds,  String? groupId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Chat() when $default != null:
return $default(_that.id,_that.name,_that.avatar,_that.isGroup,_that.unreadCount,_that.lastMessage,_that.lastMessageTime,_that.memberIds,_that.groupId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String? avatar,  bool isGroup,  int unreadCount,  String lastMessage,  DateTime lastMessageTime,  List<String>? memberIds,  String? groupId)  $default,) {final _that = this;
switch (_that) {
case _Chat():
return $default(_that.id,_that.name,_that.avatar,_that.isGroup,_that.unreadCount,_that.lastMessage,_that.lastMessageTime,_that.memberIds,_that.groupId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String? avatar,  bool isGroup,  int unreadCount,  String lastMessage,  DateTime lastMessageTime,  List<String>? memberIds,  String? groupId)?  $default,) {final _that = this;
switch (_that) {
case _Chat() when $default != null:
return $default(_that.id,_that.name,_that.avatar,_that.isGroup,_that.unreadCount,_that.lastMessage,_that.lastMessageTime,_that.memberIds,_that.groupId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Chat implements Chat {
  const _Chat({required this.id, required this.name, this.avatar, required this.isGroup, required this.unreadCount, required this.lastMessage, required this.lastMessageTime, final  List<String>? memberIds, this.groupId}): _memberIds = memberIds;
  factory _Chat.fromJson(Map<String, dynamic> json) => _$ChatFromJson(json);

@override final  String id;
@override final  String name;
@override final  String? avatar;
@override final  bool isGroup;
@override final  int unreadCount;
@override final  String lastMessage;
@override final  DateTime lastMessageTime;
 final  List<String>? _memberIds;
@override List<String>? get memberIds {
  final value = _memberIds;
  if (value == null) return null;
  if (_memberIds is EqualUnmodifiableListView) return _memberIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

@override final  String? groupId;

/// Create a copy of Chat
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ChatCopyWith<_Chat> get copyWith => __$ChatCopyWithImpl<_Chat>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ChatToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Chat&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.avatar, avatar) || other.avatar == avatar)&&(identical(other.isGroup, isGroup) || other.isGroup == isGroup)&&(identical(other.unreadCount, unreadCount) || other.unreadCount == unreadCount)&&(identical(other.lastMessage, lastMessage) || other.lastMessage == lastMessage)&&(identical(other.lastMessageTime, lastMessageTime) || other.lastMessageTime == lastMessageTime)&&const DeepCollectionEquality().equals(other._memberIds, _memberIds)&&(identical(other.groupId, groupId) || other.groupId == groupId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,avatar,isGroup,unreadCount,lastMessage,lastMessageTime,const DeepCollectionEquality().hash(_memberIds),groupId);

@override
String toString() {
  return 'Chat(id: $id, name: $name, avatar: $avatar, isGroup: $isGroup, unreadCount: $unreadCount, lastMessage: $lastMessage, lastMessageTime: $lastMessageTime, memberIds: $memberIds, groupId: $groupId)';
}


}

/// @nodoc
abstract mixin class _$ChatCopyWith<$Res> implements $ChatCopyWith<$Res> {
  factory _$ChatCopyWith(_Chat value, $Res Function(_Chat) _then) = __$ChatCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String? avatar, bool isGroup, int unreadCount, String lastMessage, DateTime lastMessageTime, List<String>? memberIds, String? groupId
});




}
/// @nodoc
class __$ChatCopyWithImpl<$Res>
    implements _$ChatCopyWith<$Res> {
  __$ChatCopyWithImpl(this._self, this._then);

  final _Chat _self;
  final $Res Function(_Chat) _then;

/// Create a copy of Chat
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? avatar = freezed,Object? isGroup = null,Object? unreadCount = null,Object? lastMessage = null,Object? lastMessageTime = null,Object? memberIds = freezed,Object? groupId = freezed,}) {
  return _then(_Chat(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,avatar: freezed == avatar ? _self.avatar : avatar // ignore: cast_nullable_to_non_nullable
as String?,isGroup: null == isGroup ? _self.isGroup : isGroup // ignore: cast_nullable_to_non_nullable
as bool,unreadCount: null == unreadCount ? _self.unreadCount : unreadCount // ignore: cast_nullable_to_non_nullable
as int,lastMessage: null == lastMessage ? _self.lastMessage : lastMessage // ignore: cast_nullable_to_non_nullable
as String,lastMessageTime: null == lastMessageTime ? _self.lastMessageTime : lastMessageTime // ignore: cast_nullable_to_non_nullable
as DateTime,memberIds: freezed == memberIds ? _self._memberIds : memberIds // ignore: cast_nullable_to_non_nullable
as List<String>?,groupId: freezed == groupId ? _self.groupId : groupId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
