// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'user.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$UserEvent {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UserEvent);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'UserEvent()';
}


}

/// @nodoc
class $UserEventCopyWith<$Res>  {
$UserEventCopyWith(UserEvent _, $Res Function(UserEvent) __);
}


/// Adds pattern-matching-related methods to [UserEvent].
extension UserEventPatterns on UserEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( UserEvent_UserInfoUpdated value)?  userInfoUpdated,TResult Function( UserEvent_UserStatusChanged value)?  userStatusChanged,required TResult orElse(),}){
final _that = this;
switch (_that) {
case UserEvent_UserInfoUpdated() when userInfoUpdated != null:
return userInfoUpdated(_that);case UserEvent_UserStatusChanged() when userStatusChanged != null:
return userStatusChanged(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( UserEvent_UserInfoUpdated value)  userInfoUpdated,required TResult Function( UserEvent_UserStatusChanged value)  userStatusChanged,}){
final _that = this;
switch (_that) {
case UserEvent_UserInfoUpdated():
return userInfoUpdated(_that);case UserEvent_UserStatusChanged():
return userStatusChanged(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( UserEvent_UserInfoUpdated value)?  userInfoUpdated,TResult? Function( UserEvent_UserStatusChanged value)?  userStatusChanged,}){
final _that = this;
switch (_that) {
case UserEvent_UserInfoUpdated() when userInfoUpdated != null:
return userInfoUpdated(_that);case UserEvent_UserStatusChanged() when userStatusChanged != null:
return userStatusChanged(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( UserInfo user)?  userInfoUpdated,TResult Function( String userId,  int status,  Int32List platformIds)?  userStatusChanged,required TResult orElse(),}) {final _that = this;
switch (_that) {
case UserEvent_UserInfoUpdated() when userInfoUpdated != null:
return userInfoUpdated(_that.user);case UserEvent_UserStatusChanged() when userStatusChanged != null:
return userStatusChanged(_that.userId,_that.status,_that.platformIds);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( UserInfo user)  userInfoUpdated,required TResult Function( String userId,  int status,  Int32List platformIds)  userStatusChanged,}) {final _that = this;
switch (_that) {
case UserEvent_UserInfoUpdated():
return userInfoUpdated(_that.user);case UserEvent_UserStatusChanged():
return userStatusChanged(_that.userId,_that.status,_that.platformIds);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( UserInfo user)?  userInfoUpdated,TResult? Function( String userId,  int status,  Int32List platformIds)?  userStatusChanged,}) {final _that = this;
switch (_that) {
case UserEvent_UserInfoUpdated() when userInfoUpdated != null:
return userInfoUpdated(_that.user);case UserEvent_UserStatusChanged() when userStatusChanged != null:
return userStatusChanged(_that.userId,_that.status,_that.platformIds);case _:
  return null;

}
}

}

/// @nodoc


class UserEvent_UserInfoUpdated extends UserEvent {
  const UserEvent_UserInfoUpdated({required this.user}): super._();
  

 final  UserInfo user;

/// Create a copy of UserEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UserEvent_UserInfoUpdatedCopyWith<UserEvent_UserInfoUpdated> get copyWith => _$UserEvent_UserInfoUpdatedCopyWithImpl<UserEvent_UserInfoUpdated>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UserEvent_UserInfoUpdated&&(identical(other.user, user) || other.user == user));
}


@override
int get hashCode => Object.hash(runtimeType,user);

@override
String toString() {
  return 'UserEvent.userInfoUpdated(user: $user)';
}


}

/// @nodoc
abstract mixin class $UserEvent_UserInfoUpdatedCopyWith<$Res> implements $UserEventCopyWith<$Res> {
  factory $UserEvent_UserInfoUpdatedCopyWith(UserEvent_UserInfoUpdated value, $Res Function(UserEvent_UserInfoUpdated) _then) = _$UserEvent_UserInfoUpdatedCopyWithImpl;
@useResult
$Res call({
 UserInfo user
});




}
/// @nodoc
class _$UserEvent_UserInfoUpdatedCopyWithImpl<$Res>
    implements $UserEvent_UserInfoUpdatedCopyWith<$Res> {
  _$UserEvent_UserInfoUpdatedCopyWithImpl(this._self, this._then);

  final UserEvent_UserInfoUpdated _self;
  final $Res Function(UserEvent_UserInfoUpdated) _then;

/// Create a copy of UserEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? user = null,}) {
  return _then(UserEvent_UserInfoUpdated(
user: null == user ? _self.user : user // ignore: cast_nullable_to_non_nullable
as UserInfo,
  ));
}


}

/// @nodoc


class UserEvent_UserStatusChanged extends UserEvent {
  const UserEvent_UserStatusChanged({required this.userId, required this.status, required this.platformIds}): super._();
  

 final  String userId;
 final  int status;
 final  Int32List platformIds;

/// Create a copy of UserEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UserEvent_UserStatusChangedCopyWith<UserEvent_UserStatusChanged> get copyWith => _$UserEvent_UserStatusChangedCopyWithImpl<UserEvent_UserStatusChanged>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UserEvent_UserStatusChanged&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.status, status) || other.status == status)&&const DeepCollectionEquality().equals(other.platformIds, platformIds));
}


@override
int get hashCode => Object.hash(runtimeType,userId,status,const DeepCollectionEquality().hash(platformIds));

@override
String toString() {
  return 'UserEvent.userStatusChanged(userId: $userId, status: $status, platformIds: $platformIds)';
}


}

/// @nodoc
abstract mixin class $UserEvent_UserStatusChangedCopyWith<$Res> implements $UserEventCopyWith<$Res> {
  factory $UserEvent_UserStatusChangedCopyWith(UserEvent_UserStatusChanged value, $Res Function(UserEvent_UserStatusChanged) _then) = _$UserEvent_UserStatusChangedCopyWithImpl;
@useResult
$Res call({
 String userId, int status, Int32List platformIds
});




}
/// @nodoc
class _$UserEvent_UserStatusChangedCopyWithImpl<$Res>
    implements $UserEvent_UserStatusChangedCopyWith<$Res> {
  _$UserEvent_UserStatusChangedCopyWithImpl(this._self, this._then);

  final UserEvent_UserStatusChanged _self;
  final $Res Function(UserEvent_UserStatusChanged) _then;

/// Create a copy of UserEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? userId = null,Object? status = null,Object? platformIds = null,}) {
  return _then(UserEvent_UserStatusChanged(
userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as int,platformIds: null == platformIds ? _self.platformIds : platformIds // ignore: cast_nullable_to_non_nullable
as Int32List,
  ));
}


}

// dart format on
