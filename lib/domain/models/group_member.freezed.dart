// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'group_member.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$GroupMember {

 String get groupId; String get userId; String get nickname; String get faceUrl; int get roleLevel; String get joinSource; DateTime? get joinTime;/// 禁言结束时间；`null` 表示当前未被禁言（服务端用 0 表示未禁言）。
 DateTime? get muteEndTime;
/// Create a copy of GroupMember
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GroupMemberCopyWith<GroupMember> get copyWith => _$GroupMemberCopyWithImpl<GroupMember>(this as GroupMember, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GroupMember&&(identical(other.groupId, groupId) || other.groupId == groupId)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.nickname, nickname) || other.nickname == nickname)&&(identical(other.faceUrl, faceUrl) || other.faceUrl == faceUrl)&&(identical(other.roleLevel, roleLevel) || other.roleLevel == roleLevel)&&(identical(other.joinSource, joinSource) || other.joinSource == joinSource)&&(identical(other.joinTime, joinTime) || other.joinTime == joinTime)&&(identical(other.muteEndTime, muteEndTime) || other.muteEndTime == muteEndTime));
}


@override
int get hashCode => Object.hash(runtimeType,groupId,userId,nickname,faceUrl,roleLevel,joinSource,joinTime,muteEndTime);

@override
String toString() {
  return 'GroupMember(groupId: $groupId, userId: $userId, nickname: $nickname, faceUrl: $faceUrl, roleLevel: $roleLevel, joinSource: $joinSource, joinTime: $joinTime, muteEndTime: $muteEndTime)';
}


}

/// @nodoc
abstract mixin class $GroupMemberCopyWith<$Res>  {
  factory $GroupMemberCopyWith(GroupMember value, $Res Function(GroupMember) _then) = _$GroupMemberCopyWithImpl;
@useResult
$Res call({
 String groupId, String userId, String nickname, String faceUrl, int roleLevel, String joinSource, DateTime? joinTime, DateTime? muteEndTime
});




}
/// @nodoc
class _$GroupMemberCopyWithImpl<$Res>
    implements $GroupMemberCopyWith<$Res> {
  _$GroupMemberCopyWithImpl(this._self, this._then);

  final GroupMember _self;
  final $Res Function(GroupMember) _then;

/// Create a copy of GroupMember
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? groupId = null,Object? userId = null,Object? nickname = null,Object? faceUrl = null,Object? roleLevel = null,Object? joinSource = null,Object? joinTime = freezed,Object? muteEndTime = freezed,}) {
  return _then(_self.copyWith(
groupId: null == groupId ? _self.groupId : groupId // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,nickname: null == nickname ? _self.nickname : nickname // ignore: cast_nullable_to_non_nullable
as String,faceUrl: null == faceUrl ? _self.faceUrl : faceUrl // ignore: cast_nullable_to_non_nullable
as String,roleLevel: null == roleLevel ? _self.roleLevel : roleLevel // ignore: cast_nullable_to_non_nullable
as int,joinSource: null == joinSource ? _self.joinSource : joinSource // ignore: cast_nullable_to_non_nullable
as String,joinTime: freezed == joinTime ? _self.joinTime : joinTime // ignore: cast_nullable_to_non_nullable
as DateTime?,muteEndTime: freezed == muteEndTime ? _self.muteEndTime : muteEndTime // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [GroupMember].
extension GroupMemberPatterns on GroupMember {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GroupMember value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GroupMember() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GroupMember value)  $default,){
final _that = this;
switch (_that) {
case _GroupMember():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GroupMember value)?  $default,){
final _that = this;
switch (_that) {
case _GroupMember() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String groupId,  String userId,  String nickname,  String faceUrl,  int roleLevel,  String joinSource,  DateTime? joinTime,  DateTime? muteEndTime)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GroupMember() when $default != null:
return $default(_that.groupId,_that.userId,_that.nickname,_that.faceUrl,_that.roleLevel,_that.joinSource,_that.joinTime,_that.muteEndTime);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String groupId,  String userId,  String nickname,  String faceUrl,  int roleLevel,  String joinSource,  DateTime? joinTime,  DateTime? muteEndTime)  $default,) {final _that = this;
switch (_that) {
case _GroupMember():
return $default(_that.groupId,_that.userId,_that.nickname,_that.faceUrl,_that.roleLevel,_that.joinSource,_that.joinTime,_that.muteEndTime);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String groupId,  String userId,  String nickname,  String faceUrl,  int roleLevel,  String joinSource,  DateTime? joinTime,  DateTime? muteEndTime)?  $default,) {final _that = this;
switch (_that) {
case _GroupMember() when $default != null:
return $default(_that.groupId,_that.userId,_that.nickname,_that.faceUrl,_that.roleLevel,_that.joinSource,_that.joinTime,_that.muteEndTime);case _:
  return null;

}
}

}

/// @nodoc


class _GroupMember implements GroupMember {
  const _GroupMember({required this.groupId, required this.userId, required this.nickname, required this.faceUrl, required this.roleLevel, required this.joinSource, this.joinTime, this.muteEndTime});
  

@override final  String groupId;
@override final  String userId;
@override final  String nickname;
@override final  String faceUrl;
@override final  int roleLevel;
@override final  String joinSource;
@override final  DateTime? joinTime;
/// 禁言结束时间；`null` 表示当前未被禁言（服务端用 0 表示未禁言）。
@override final  DateTime? muteEndTime;

/// Create a copy of GroupMember
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GroupMemberCopyWith<_GroupMember> get copyWith => __$GroupMemberCopyWithImpl<_GroupMember>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _GroupMember&&(identical(other.groupId, groupId) || other.groupId == groupId)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.nickname, nickname) || other.nickname == nickname)&&(identical(other.faceUrl, faceUrl) || other.faceUrl == faceUrl)&&(identical(other.roleLevel, roleLevel) || other.roleLevel == roleLevel)&&(identical(other.joinSource, joinSource) || other.joinSource == joinSource)&&(identical(other.joinTime, joinTime) || other.joinTime == joinTime)&&(identical(other.muteEndTime, muteEndTime) || other.muteEndTime == muteEndTime));
}


@override
int get hashCode => Object.hash(runtimeType,groupId,userId,nickname,faceUrl,roleLevel,joinSource,joinTime,muteEndTime);

@override
String toString() {
  return 'GroupMember(groupId: $groupId, userId: $userId, nickname: $nickname, faceUrl: $faceUrl, roleLevel: $roleLevel, joinSource: $joinSource, joinTime: $joinTime, muteEndTime: $muteEndTime)';
}


}

/// @nodoc
abstract mixin class _$GroupMemberCopyWith<$Res> implements $GroupMemberCopyWith<$Res> {
  factory _$GroupMemberCopyWith(_GroupMember value, $Res Function(_GroupMember) _then) = __$GroupMemberCopyWithImpl;
@override @useResult
$Res call({
 String groupId, String userId, String nickname, String faceUrl, int roleLevel, String joinSource, DateTime? joinTime, DateTime? muteEndTime
});




}
/// @nodoc
class __$GroupMemberCopyWithImpl<$Res>
    implements _$GroupMemberCopyWith<$Res> {
  __$GroupMemberCopyWithImpl(this._self, this._then);

  final _GroupMember _self;
  final $Res Function(_GroupMember) _then;

/// Create a copy of GroupMember
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? groupId = null,Object? userId = null,Object? nickname = null,Object? faceUrl = null,Object? roleLevel = null,Object? joinSource = null,Object? joinTime = freezed,Object? muteEndTime = freezed,}) {
  return _then(_GroupMember(
groupId: null == groupId ? _self.groupId : groupId // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,nickname: null == nickname ? _self.nickname : nickname // ignore: cast_nullable_to_non_nullable
as String,faceUrl: null == faceUrl ? _self.faceUrl : faceUrl // ignore: cast_nullable_to_non_nullable
as String,roleLevel: null == roleLevel ? _self.roleLevel : roleLevel // ignore: cast_nullable_to_non_nullable
as int,joinSource: null == joinSource ? _self.joinSource : joinSource // ignore: cast_nullable_to_non_nullable
as String,joinTime: freezed == joinTime ? _self.joinTime : joinTime // ignore: cast_nullable_to_non_nullable
as DateTime?,muteEndTime: freezed == muteEndTime ? _self.muteEndTime : muteEndTime // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
