// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'friend.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Friend {

 String get userId; String get nickname; String get faceUrl; int get gender; String get remark; String get addSource; String get ex; DateTime? get createdTime;
/// Create a copy of Friend
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FriendCopyWith<Friend> get copyWith => _$FriendCopyWithImpl<Friend>(this as Friend, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Friend&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.nickname, nickname) || other.nickname == nickname)&&(identical(other.faceUrl, faceUrl) || other.faceUrl == faceUrl)&&(identical(other.gender, gender) || other.gender == gender)&&(identical(other.remark, remark) || other.remark == remark)&&(identical(other.addSource, addSource) || other.addSource == addSource)&&(identical(other.ex, ex) || other.ex == ex)&&(identical(other.createdTime, createdTime) || other.createdTime == createdTime));
}


@override
int get hashCode => Object.hash(runtimeType,userId,nickname,faceUrl,gender,remark,addSource,ex,createdTime);

@override
String toString() {
  return 'Friend(userId: $userId, nickname: $nickname, faceUrl: $faceUrl, gender: $gender, remark: $remark, addSource: $addSource, ex: $ex, createdTime: $createdTime)';
}


}

/// @nodoc
abstract mixin class $FriendCopyWith<$Res>  {
  factory $FriendCopyWith(Friend value, $Res Function(Friend) _then) = _$FriendCopyWithImpl;
@useResult
$Res call({
 String userId, String nickname, String faceUrl, int gender, String remark, String addSource, String ex, DateTime? createdTime
});




}
/// @nodoc
class _$FriendCopyWithImpl<$Res>
    implements $FriendCopyWith<$Res> {
  _$FriendCopyWithImpl(this._self, this._then);

  final Friend _self;
  final $Res Function(Friend) _then;

/// Create a copy of Friend
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? userId = null,Object? nickname = null,Object? faceUrl = null,Object? gender = null,Object? remark = null,Object? addSource = null,Object? ex = null,Object? createdTime = freezed,}) {
  return _then(_self.copyWith(
userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,nickname: null == nickname ? _self.nickname : nickname // ignore: cast_nullable_to_non_nullable
as String,faceUrl: null == faceUrl ? _self.faceUrl : faceUrl // ignore: cast_nullable_to_non_nullable
as String,gender: null == gender ? _self.gender : gender // ignore: cast_nullable_to_non_nullable
as int,remark: null == remark ? _self.remark : remark // ignore: cast_nullable_to_non_nullable
as String,addSource: null == addSource ? _self.addSource : addSource // ignore: cast_nullable_to_non_nullable
as String,ex: null == ex ? _self.ex : ex // ignore: cast_nullable_to_non_nullable
as String,createdTime: freezed == createdTime ? _self.createdTime : createdTime // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [Friend].
extension FriendPatterns on Friend {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Friend value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Friend() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Friend value)  $default,){
final _that = this;
switch (_that) {
case _Friend():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Friend value)?  $default,){
final _that = this;
switch (_that) {
case _Friend() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String userId,  String nickname,  String faceUrl,  int gender,  String remark,  String addSource,  String ex,  DateTime? createdTime)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Friend() when $default != null:
return $default(_that.userId,_that.nickname,_that.faceUrl,_that.gender,_that.remark,_that.addSource,_that.ex,_that.createdTime);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String userId,  String nickname,  String faceUrl,  int gender,  String remark,  String addSource,  String ex,  DateTime? createdTime)  $default,) {final _that = this;
switch (_that) {
case _Friend():
return $default(_that.userId,_that.nickname,_that.faceUrl,_that.gender,_that.remark,_that.addSource,_that.ex,_that.createdTime);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String userId,  String nickname,  String faceUrl,  int gender,  String remark,  String addSource,  String ex,  DateTime? createdTime)?  $default,) {final _that = this;
switch (_that) {
case _Friend() when $default != null:
return $default(_that.userId,_that.nickname,_that.faceUrl,_that.gender,_that.remark,_that.addSource,_that.ex,_that.createdTime);case _:
  return null;

}
}

}

/// @nodoc


class _Friend implements Friend {
  const _Friend({required this.userId, required this.nickname, required this.faceUrl, required this.gender, required this.remark, required this.addSource, required this.ex, this.createdTime});
  

@override final  String userId;
@override final  String nickname;
@override final  String faceUrl;
@override final  int gender;
@override final  String remark;
@override final  String addSource;
@override final  String ex;
@override final  DateTime? createdTime;

/// Create a copy of Friend
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FriendCopyWith<_Friend> get copyWith => __$FriendCopyWithImpl<_Friend>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Friend&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.nickname, nickname) || other.nickname == nickname)&&(identical(other.faceUrl, faceUrl) || other.faceUrl == faceUrl)&&(identical(other.gender, gender) || other.gender == gender)&&(identical(other.remark, remark) || other.remark == remark)&&(identical(other.addSource, addSource) || other.addSource == addSource)&&(identical(other.ex, ex) || other.ex == ex)&&(identical(other.createdTime, createdTime) || other.createdTime == createdTime));
}


@override
int get hashCode => Object.hash(runtimeType,userId,nickname,faceUrl,gender,remark,addSource,ex,createdTime);

@override
String toString() {
  return 'Friend(userId: $userId, nickname: $nickname, faceUrl: $faceUrl, gender: $gender, remark: $remark, addSource: $addSource, ex: $ex, createdTime: $createdTime)';
}


}

/// @nodoc
abstract mixin class _$FriendCopyWith<$Res> implements $FriendCopyWith<$Res> {
  factory _$FriendCopyWith(_Friend value, $Res Function(_Friend) _then) = __$FriendCopyWithImpl;
@override @useResult
$Res call({
 String userId, String nickname, String faceUrl, int gender, String remark, String addSource, String ex, DateTime? createdTime
});




}
/// @nodoc
class __$FriendCopyWithImpl<$Res>
    implements _$FriendCopyWith<$Res> {
  __$FriendCopyWithImpl(this._self, this._then);

  final _Friend _self;
  final $Res Function(_Friend) _then;

/// Create a copy of Friend
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? userId = null,Object? nickname = null,Object? faceUrl = null,Object? gender = null,Object? remark = null,Object? addSource = null,Object? ex = null,Object? createdTime = freezed,}) {
  return _then(_Friend(
userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,nickname: null == nickname ? _self.nickname : nickname // ignore: cast_nullable_to_non_nullable
as String,faceUrl: null == faceUrl ? _self.faceUrl : faceUrl // ignore: cast_nullable_to_non_nullable
as String,gender: null == gender ? _self.gender : gender // ignore: cast_nullable_to_non_nullable
as int,remark: null == remark ? _self.remark : remark // ignore: cast_nullable_to_non_nullable
as String,addSource: null == addSource ? _self.addSource : addSource // ignore: cast_nullable_to_non_nullable
as String,ex: null == ex ? _self.ex : ex // ignore: cast_nullable_to_non_nullable
as String,createdTime: freezed == createdTime ? _self.createdTime : createdTime // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
