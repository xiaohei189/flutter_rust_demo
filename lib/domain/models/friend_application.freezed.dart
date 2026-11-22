// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'friend_application.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$FriendApplication {

 String get userId; String get nickname; String get faceUrl; int get gender; int get addSource; String get ex; int get handleResult; String? get reqMsg; String? get handleMsg; DateTime? get createdTime;
/// Create a copy of FriendApplication
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FriendApplicationCopyWith<FriendApplication> get copyWith => _$FriendApplicationCopyWithImpl<FriendApplication>(this as FriendApplication, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FriendApplication&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.nickname, nickname) || other.nickname == nickname)&&(identical(other.faceUrl, faceUrl) || other.faceUrl == faceUrl)&&(identical(other.gender, gender) || other.gender == gender)&&(identical(other.addSource, addSource) || other.addSource == addSource)&&(identical(other.ex, ex) || other.ex == ex)&&(identical(other.handleResult, handleResult) || other.handleResult == handleResult)&&(identical(other.reqMsg, reqMsg) || other.reqMsg == reqMsg)&&(identical(other.handleMsg, handleMsg) || other.handleMsg == handleMsg)&&(identical(other.createdTime, createdTime) || other.createdTime == createdTime));
}


@override
int get hashCode => Object.hash(runtimeType,userId,nickname,faceUrl,gender,addSource,ex,handleResult,reqMsg,handleMsg,createdTime);

@override
String toString() {
  return 'FriendApplication(userId: $userId, nickname: $nickname, faceUrl: $faceUrl, gender: $gender, addSource: $addSource, ex: $ex, handleResult: $handleResult, reqMsg: $reqMsg, handleMsg: $handleMsg, createdTime: $createdTime)';
}


}

/// @nodoc
abstract mixin class $FriendApplicationCopyWith<$Res>  {
  factory $FriendApplicationCopyWith(FriendApplication value, $Res Function(FriendApplication) _then) = _$FriendApplicationCopyWithImpl;
@useResult
$Res call({
 String userId, String nickname, String faceUrl, int gender, int addSource, String ex, int handleResult, String? reqMsg, String? handleMsg, DateTime? createdTime
});




}
/// @nodoc
class _$FriendApplicationCopyWithImpl<$Res>
    implements $FriendApplicationCopyWith<$Res> {
  _$FriendApplicationCopyWithImpl(this._self, this._then);

  final FriendApplication _self;
  final $Res Function(FriendApplication) _then;

/// Create a copy of FriendApplication
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? userId = null,Object? nickname = null,Object? faceUrl = null,Object? gender = null,Object? addSource = null,Object? ex = null,Object? handleResult = null,Object? reqMsg = freezed,Object? handleMsg = freezed,Object? createdTime = freezed,}) {
  return _then(_self.copyWith(
userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,nickname: null == nickname ? _self.nickname : nickname // ignore: cast_nullable_to_non_nullable
as String,faceUrl: null == faceUrl ? _self.faceUrl : faceUrl // ignore: cast_nullable_to_non_nullable
as String,gender: null == gender ? _self.gender : gender // ignore: cast_nullable_to_non_nullable
as int,addSource: null == addSource ? _self.addSource : addSource // ignore: cast_nullable_to_non_nullable
as int,ex: null == ex ? _self.ex : ex // ignore: cast_nullable_to_non_nullable
as String,handleResult: null == handleResult ? _self.handleResult : handleResult // ignore: cast_nullable_to_non_nullable
as int,reqMsg: freezed == reqMsg ? _self.reqMsg : reqMsg // ignore: cast_nullable_to_non_nullable
as String?,handleMsg: freezed == handleMsg ? _self.handleMsg : handleMsg // ignore: cast_nullable_to_non_nullable
as String?,createdTime: freezed == createdTime ? _self.createdTime : createdTime // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [FriendApplication].
extension FriendApplicationPatterns on FriendApplication {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FriendApplication value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FriendApplication() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FriendApplication value)  $default,){
final _that = this;
switch (_that) {
case _FriendApplication():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FriendApplication value)?  $default,){
final _that = this;
switch (_that) {
case _FriendApplication() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String userId,  String nickname,  String faceUrl,  int gender,  int addSource,  String ex,  int handleResult,  String? reqMsg,  String? handleMsg,  DateTime? createdTime)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FriendApplication() when $default != null:
return $default(_that.userId,_that.nickname,_that.faceUrl,_that.gender,_that.addSource,_that.ex,_that.handleResult,_that.reqMsg,_that.handleMsg,_that.createdTime);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String userId,  String nickname,  String faceUrl,  int gender,  int addSource,  String ex,  int handleResult,  String? reqMsg,  String? handleMsg,  DateTime? createdTime)  $default,) {final _that = this;
switch (_that) {
case _FriendApplication():
return $default(_that.userId,_that.nickname,_that.faceUrl,_that.gender,_that.addSource,_that.ex,_that.handleResult,_that.reqMsg,_that.handleMsg,_that.createdTime);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String userId,  String nickname,  String faceUrl,  int gender,  int addSource,  String ex,  int handleResult,  String? reqMsg,  String? handleMsg,  DateTime? createdTime)?  $default,) {final _that = this;
switch (_that) {
case _FriendApplication() when $default != null:
return $default(_that.userId,_that.nickname,_that.faceUrl,_that.gender,_that.addSource,_that.ex,_that.handleResult,_that.reqMsg,_that.handleMsg,_that.createdTime);case _:
  return null;

}
}

}

/// @nodoc


class _FriendApplication implements FriendApplication {
  const _FriendApplication({required this.userId, required this.nickname, required this.faceUrl, required this.gender, required this.addSource, required this.ex, required this.handleResult, this.reqMsg, this.handleMsg, this.createdTime});
  

@override final  String userId;
@override final  String nickname;
@override final  String faceUrl;
@override final  int gender;
@override final  int addSource;
@override final  String ex;
@override final  int handleResult;
@override final  String? reqMsg;
@override final  String? handleMsg;
@override final  DateTime? createdTime;

/// Create a copy of FriendApplication
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FriendApplicationCopyWith<_FriendApplication> get copyWith => __$FriendApplicationCopyWithImpl<_FriendApplication>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FriendApplication&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.nickname, nickname) || other.nickname == nickname)&&(identical(other.faceUrl, faceUrl) || other.faceUrl == faceUrl)&&(identical(other.gender, gender) || other.gender == gender)&&(identical(other.addSource, addSource) || other.addSource == addSource)&&(identical(other.ex, ex) || other.ex == ex)&&(identical(other.handleResult, handleResult) || other.handleResult == handleResult)&&(identical(other.reqMsg, reqMsg) || other.reqMsg == reqMsg)&&(identical(other.handleMsg, handleMsg) || other.handleMsg == handleMsg)&&(identical(other.createdTime, createdTime) || other.createdTime == createdTime));
}


@override
int get hashCode => Object.hash(runtimeType,userId,nickname,faceUrl,gender,addSource,ex,handleResult,reqMsg,handleMsg,createdTime);

@override
String toString() {
  return 'FriendApplication(userId: $userId, nickname: $nickname, faceUrl: $faceUrl, gender: $gender, addSource: $addSource, ex: $ex, handleResult: $handleResult, reqMsg: $reqMsg, handleMsg: $handleMsg, createdTime: $createdTime)';
}


}

/// @nodoc
abstract mixin class _$FriendApplicationCopyWith<$Res> implements $FriendApplicationCopyWith<$Res> {
  factory _$FriendApplicationCopyWith(_FriendApplication value, $Res Function(_FriendApplication) _then) = __$FriendApplicationCopyWithImpl;
@override @useResult
$Res call({
 String userId, String nickname, String faceUrl, int gender, int addSource, String ex, int handleResult, String? reqMsg, String? handleMsg, DateTime? createdTime
});




}
/// @nodoc
class __$FriendApplicationCopyWithImpl<$Res>
    implements _$FriendApplicationCopyWith<$Res> {
  __$FriendApplicationCopyWithImpl(this._self, this._then);

  final _FriendApplication _self;
  final $Res Function(_FriendApplication) _then;

/// Create a copy of FriendApplication
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? userId = null,Object? nickname = null,Object? faceUrl = null,Object? gender = null,Object? addSource = null,Object? ex = null,Object? handleResult = null,Object? reqMsg = freezed,Object? handleMsg = freezed,Object? createdTime = freezed,}) {
  return _then(_FriendApplication(
userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,nickname: null == nickname ? _self.nickname : nickname // ignore: cast_nullable_to_non_nullable
as String,faceUrl: null == faceUrl ? _self.faceUrl : faceUrl // ignore: cast_nullable_to_non_nullable
as String,gender: null == gender ? _self.gender : gender // ignore: cast_nullable_to_non_nullable
as int,addSource: null == addSource ? _self.addSource : addSource // ignore: cast_nullable_to_non_nullable
as int,ex: null == ex ? _self.ex : ex // ignore: cast_nullable_to_non_nullable
as String,handleResult: null == handleResult ? _self.handleResult : handleResult // ignore: cast_nullable_to_non_nullable
as int,reqMsg: freezed == reqMsg ? _self.reqMsg : reqMsg // ignore: cast_nullable_to_non_nullable
as String?,handleMsg: freezed == handleMsg ? _self.handleMsg : handleMsg // ignore: cast_nullable_to_non_nullable
as String?,createdTime: freezed == createdTime ? _self.createdTime : createdTime // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
