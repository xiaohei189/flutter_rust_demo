// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'blacklist_user.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$BlacklistUser {

 String get userId; String get nickname; String get faceUrl;
/// Create a copy of BlacklistUser
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BlacklistUserCopyWith<BlacklistUser> get copyWith => _$BlacklistUserCopyWithImpl<BlacklistUser>(this as BlacklistUser, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BlacklistUser&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.nickname, nickname) || other.nickname == nickname)&&(identical(other.faceUrl, faceUrl) || other.faceUrl == faceUrl));
}


@override
int get hashCode => Object.hash(runtimeType,userId,nickname,faceUrl);

@override
String toString() {
  return 'BlacklistUser(userId: $userId, nickname: $nickname, faceUrl: $faceUrl)';
}


}

/// @nodoc
abstract mixin class $BlacklistUserCopyWith<$Res>  {
  factory $BlacklistUserCopyWith(BlacklistUser value, $Res Function(BlacklistUser) _then) = _$BlacklistUserCopyWithImpl;
@useResult
$Res call({
 String userId, String nickname, String faceUrl
});




}
/// @nodoc
class _$BlacklistUserCopyWithImpl<$Res>
    implements $BlacklistUserCopyWith<$Res> {
  _$BlacklistUserCopyWithImpl(this._self, this._then);

  final BlacklistUser _self;
  final $Res Function(BlacklistUser) _then;

/// Create a copy of BlacklistUser
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? userId = null,Object? nickname = null,Object? faceUrl = null,}) {
  return _then(_self.copyWith(
userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,nickname: null == nickname ? _self.nickname : nickname // ignore: cast_nullable_to_non_nullable
as String,faceUrl: null == faceUrl ? _self.faceUrl : faceUrl // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [BlacklistUser].
extension BlacklistUserPatterns on BlacklistUser {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BlacklistUser value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BlacklistUser() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BlacklistUser value)  $default,){
final _that = this;
switch (_that) {
case _BlacklistUser():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BlacklistUser value)?  $default,){
final _that = this;
switch (_that) {
case _BlacklistUser() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String userId,  String nickname,  String faceUrl)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BlacklistUser() when $default != null:
return $default(_that.userId,_that.nickname,_that.faceUrl);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String userId,  String nickname,  String faceUrl)  $default,) {final _that = this;
switch (_that) {
case _BlacklistUser():
return $default(_that.userId,_that.nickname,_that.faceUrl);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String userId,  String nickname,  String faceUrl)?  $default,) {final _that = this;
switch (_that) {
case _BlacklistUser() when $default != null:
return $default(_that.userId,_that.nickname,_that.faceUrl);case _:
  return null;

}
}

}

/// @nodoc


class _BlacklistUser implements BlacklistUser {
  const _BlacklistUser({required this.userId, required this.nickname, required this.faceUrl});
  

@override final  String userId;
@override final  String nickname;
@override final  String faceUrl;

/// Create a copy of BlacklistUser
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BlacklistUserCopyWith<_BlacklistUser> get copyWith => __$BlacklistUserCopyWithImpl<_BlacklistUser>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _BlacklistUser&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.nickname, nickname) || other.nickname == nickname)&&(identical(other.faceUrl, faceUrl) || other.faceUrl == faceUrl));
}


@override
int get hashCode => Object.hash(runtimeType,userId,nickname,faceUrl);

@override
String toString() {
  return 'BlacklistUser(userId: $userId, nickname: $nickname, faceUrl: $faceUrl)';
}


}

/// @nodoc
abstract mixin class _$BlacklistUserCopyWith<$Res> implements $BlacklistUserCopyWith<$Res> {
  factory _$BlacklistUserCopyWith(_BlacklistUser value, $Res Function(_BlacklistUser) _then) = __$BlacklistUserCopyWithImpl;
@override @useResult
$Res call({
 String userId, String nickname, String faceUrl
});




}
/// @nodoc
class __$BlacklistUserCopyWithImpl<$Res>
    implements _$BlacklistUserCopyWith<$Res> {
  __$BlacklistUserCopyWithImpl(this._self, this._then);

  final _BlacklistUser _self;
  final $Res Function(_BlacklistUser) _then;

/// Create a copy of BlacklistUser
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? userId = null,Object? nickname = null,Object? faceUrl = null,}) {
  return _then(_BlacklistUser(
userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,nickname: null == nickname ? _self.nickname : nickname // ignore: cast_nullable_to_non_nullable
as String,faceUrl: null == faceUrl ? _self.faceUrl : faceUrl // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
