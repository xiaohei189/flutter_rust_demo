// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'group.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Group {

 String get groupId; String get groupName; String get faceUrl; String get introduction; String get notification; String get ownerUserId; int get memberCount; int get status; DateTime? get createdTime;
/// Create a copy of Group
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GroupCopyWith<Group> get copyWith => _$GroupCopyWithImpl<Group>(this as Group, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Group&&(identical(other.groupId, groupId) || other.groupId == groupId)&&(identical(other.groupName, groupName) || other.groupName == groupName)&&(identical(other.faceUrl, faceUrl) || other.faceUrl == faceUrl)&&(identical(other.introduction, introduction) || other.introduction == introduction)&&(identical(other.notification, notification) || other.notification == notification)&&(identical(other.ownerUserId, ownerUserId) || other.ownerUserId == ownerUserId)&&(identical(other.memberCount, memberCount) || other.memberCount == memberCount)&&(identical(other.status, status) || other.status == status)&&(identical(other.createdTime, createdTime) || other.createdTime == createdTime));
}


@override
int get hashCode => Object.hash(runtimeType,groupId,groupName,faceUrl,introduction,notification,ownerUserId,memberCount,status,createdTime);

@override
String toString() {
  return 'Group(groupId: $groupId, groupName: $groupName, faceUrl: $faceUrl, introduction: $introduction, notification: $notification, ownerUserId: $ownerUserId, memberCount: $memberCount, status: $status, createdTime: $createdTime)';
}


}

/// @nodoc
abstract mixin class $GroupCopyWith<$Res>  {
  factory $GroupCopyWith(Group value, $Res Function(Group) _then) = _$GroupCopyWithImpl;
@useResult
$Res call({
 String groupId, String groupName, String faceUrl, String introduction, String notification, String ownerUserId, int memberCount, int status, DateTime? createdTime
});




}
/// @nodoc
class _$GroupCopyWithImpl<$Res>
    implements $GroupCopyWith<$Res> {
  _$GroupCopyWithImpl(this._self, this._then);

  final Group _self;
  final $Res Function(Group) _then;

/// Create a copy of Group
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? groupId = null,Object? groupName = null,Object? faceUrl = null,Object? introduction = null,Object? notification = null,Object? ownerUserId = null,Object? memberCount = null,Object? status = null,Object? createdTime = freezed,}) {
  return _then(_self.copyWith(
groupId: null == groupId ? _self.groupId : groupId // ignore: cast_nullable_to_non_nullable
as String,groupName: null == groupName ? _self.groupName : groupName // ignore: cast_nullable_to_non_nullable
as String,faceUrl: null == faceUrl ? _self.faceUrl : faceUrl // ignore: cast_nullable_to_non_nullable
as String,introduction: null == introduction ? _self.introduction : introduction // ignore: cast_nullable_to_non_nullable
as String,notification: null == notification ? _self.notification : notification // ignore: cast_nullable_to_non_nullable
as String,ownerUserId: null == ownerUserId ? _self.ownerUserId : ownerUserId // ignore: cast_nullable_to_non_nullable
as String,memberCount: null == memberCount ? _self.memberCount : memberCount // ignore: cast_nullable_to_non_nullable
as int,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as int,createdTime: freezed == createdTime ? _self.createdTime : createdTime // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [Group].
extension GroupPatterns on Group {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Group value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Group() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Group value)  $default,){
final _that = this;
switch (_that) {
case _Group():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Group value)?  $default,){
final _that = this;
switch (_that) {
case _Group() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String groupId,  String groupName,  String faceUrl,  String introduction,  String notification,  String ownerUserId,  int memberCount,  int status,  DateTime? createdTime)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Group() when $default != null:
return $default(_that.groupId,_that.groupName,_that.faceUrl,_that.introduction,_that.notification,_that.ownerUserId,_that.memberCount,_that.status,_that.createdTime);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String groupId,  String groupName,  String faceUrl,  String introduction,  String notification,  String ownerUserId,  int memberCount,  int status,  DateTime? createdTime)  $default,) {final _that = this;
switch (_that) {
case _Group():
return $default(_that.groupId,_that.groupName,_that.faceUrl,_that.introduction,_that.notification,_that.ownerUserId,_that.memberCount,_that.status,_that.createdTime);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String groupId,  String groupName,  String faceUrl,  String introduction,  String notification,  String ownerUserId,  int memberCount,  int status,  DateTime? createdTime)?  $default,) {final _that = this;
switch (_that) {
case _Group() when $default != null:
return $default(_that.groupId,_that.groupName,_that.faceUrl,_that.introduction,_that.notification,_that.ownerUserId,_that.memberCount,_that.status,_that.createdTime);case _:
  return null;

}
}

}

/// @nodoc


class _Group implements Group {
  const _Group({required this.groupId, required this.groupName, required this.faceUrl, required this.introduction, required this.notification, required this.ownerUserId, required this.memberCount, required this.status, this.createdTime});
  

@override final  String groupId;
@override final  String groupName;
@override final  String faceUrl;
@override final  String introduction;
@override final  String notification;
@override final  String ownerUserId;
@override final  int memberCount;
@override final  int status;
@override final  DateTime? createdTime;

/// Create a copy of Group
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GroupCopyWith<_Group> get copyWith => __$GroupCopyWithImpl<_Group>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Group&&(identical(other.groupId, groupId) || other.groupId == groupId)&&(identical(other.groupName, groupName) || other.groupName == groupName)&&(identical(other.faceUrl, faceUrl) || other.faceUrl == faceUrl)&&(identical(other.introduction, introduction) || other.introduction == introduction)&&(identical(other.notification, notification) || other.notification == notification)&&(identical(other.ownerUserId, ownerUserId) || other.ownerUserId == ownerUserId)&&(identical(other.memberCount, memberCount) || other.memberCount == memberCount)&&(identical(other.status, status) || other.status == status)&&(identical(other.createdTime, createdTime) || other.createdTime == createdTime));
}


@override
int get hashCode => Object.hash(runtimeType,groupId,groupName,faceUrl,introduction,notification,ownerUserId,memberCount,status,createdTime);

@override
String toString() {
  return 'Group(groupId: $groupId, groupName: $groupName, faceUrl: $faceUrl, introduction: $introduction, notification: $notification, ownerUserId: $ownerUserId, memberCount: $memberCount, status: $status, createdTime: $createdTime)';
}


}

/// @nodoc
abstract mixin class _$GroupCopyWith<$Res> implements $GroupCopyWith<$Res> {
  factory _$GroupCopyWith(_Group value, $Res Function(_Group) _then) = __$GroupCopyWithImpl;
@override @useResult
$Res call({
 String groupId, String groupName, String faceUrl, String introduction, String notification, String ownerUserId, int memberCount, int status, DateTime? createdTime
});




}
/// @nodoc
class __$GroupCopyWithImpl<$Res>
    implements _$GroupCopyWith<$Res> {
  __$GroupCopyWithImpl(this._self, this._then);

  final _Group _self;
  final $Res Function(_Group) _then;

/// Create a copy of Group
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? groupId = null,Object? groupName = null,Object? faceUrl = null,Object? introduction = null,Object? notification = null,Object? ownerUserId = null,Object? memberCount = null,Object? status = null,Object? createdTime = freezed,}) {
  return _then(_Group(
groupId: null == groupId ? _self.groupId : groupId // ignore: cast_nullable_to_non_nullable
as String,groupName: null == groupName ? _self.groupName : groupName // ignore: cast_nullable_to_non_nullable
as String,faceUrl: null == faceUrl ? _self.faceUrl : faceUrl // ignore: cast_nullable_to_non_nullable
as String,introduction: null == introduction ? _self.introduction : introduction // ignore: cast_nullable_to_non_nullable
as String,notification: null == notification ? _self.notification : notification // ignore: cast_nullable_to_non_nullable
as String,ownerUserId: null == ownerUserId ? _self.ownerUserId : ownerUserId // ignore: cast_nullable_to_non_nullable
as String,memberCount: null == memberCount ? _self.memberCount : memberCount // ignore: cast_nullable_to_non_nullable
as int,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as int,createdTime: freezed == createdTime ? _self.createdTime : createdTime // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
