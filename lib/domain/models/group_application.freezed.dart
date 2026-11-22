// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'group_application.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$GroupApplication {

 String get groupId; String get userId; String get nickname; String get faceUrl; String get reason; int get handleResult; String? get ex;
/// Create a copy of GroupApplication
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GroupApplicationCopyWith<GroupApplication> get copyWith => _$GroupApplicationCopyWithImpl<GroupApplication>(this as GroupApplication, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GroupApplication&&(identical(other.groupId, groupId) || other.groupId == groupId)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.nickname, nickname) || other.nickname == nickname)&&(identical(other.faceUrl, faceUrl) || other.faceUrl == faceUrl)&&(identical(other.reason, reason) || other.reason == reason)&&(identical(other.handleResult, handleResult) || other.handleResult == handleResult)&&(identical(other.ex, ex) || other.ex == ex));
}


@override
int get hashCode => Object.hash(runtimeType,groupId,userId,nickname,faceUrl,reason,handleResult,ex);

@override
String toString() {
  return 'GroupApplication(groupId: $groupId, userId: $userId, nickname: $nickname, faceUrl: $faceUrl, reason: $reason, handleResult: $handleResult, ex: $ex)';
}


}

/// @nodoc
abstract mixin class $GroupApplicationCopyWith<$Res>  {
  factory $GroupApplicationCopyWith(GroupApplication value, $Res Function(GroupApplication) _then) = _$GroupApplicationCopyWithImpl;
@useResult
$Res call({
 String groupId, String userId, String nickname, String faceUrl, String reason, int handleResult, String? ex
});




}
/// @nodoc
class _$GroupApplicationCopyWithImpl<$Res>
    implements $GroupApplicationCopyWith<$Res> {
  _$GroupApplicationCopyWithImpl(this._self, this._then);

  final GroupApplication _self;
  final $Res Function(GroupApplication) _then;

/// Create a copy of GroupApplication
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? groupId = null,Object? userId = null,Object? nickname = null,Object? faceUrl = null,Object? reason = null,Object? handleResult = null,Object? ex = freezed,}) {
  return _then(_self.copyWith(
groupId: null == groupId ? _self.groupId : groupId // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,nickname: null == nickname ? _self.nickname : nickname // ignore: cast_nullable_to_non_nullable
as String,faceUrl: null == faceUrl ? _self.faceUrl : faceUrl // ignore: cast_nullable_to_non_nullable
as String,reason: null == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String,handleResult: null == handleResult ? _self.handleResult : handleResult // ignore: cast_nullable_to_non_nullable
as int,ex: freezed == ex ? _self.ex : ex // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [GroupApplication].
extension GroupApplicationPatterns on GroupApplication {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GroupApplication value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GroupApplication() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GroupApplication value)  $default,){
final _that = this;
switch (_that) {
case _GroupApplication():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GroupApplication value)?  $default,){
final _that = this;
switch (_that) {
case _GroupApplication() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String groupId,  String userId,  String nickname,  String faceUrl,  String reason,  int handleResult,  String? ex)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GroupApplication() when $default != null:
return $default(_that.groupId,_that.userId,_that.nickname,_that.faceUrl,_that.reason,_that.handleResult,_that.ex);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String groupId,  String userId,  String nickname,  String faceUrl,  String reason,  int handleResult,  String? ex)  $default,) {final _that = this;
switch (_that) {
case _GroupApplication():
return $default(_that.groupId,_that.userId,_that.nickname,_that.faceUrl,_that.reason,_that.handleResult,_that.ex);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String groupId,  String userId,  String nickname,  String faceUrl,  String reason,  int handleResult,  String? ex)?  $default,) {final _that = this;
switch (_that) {
case _GroupApplication() when $default != null:
return $default(_that.groupId,_that.userId,_that.nickname,_that.faceUrl,_that.reason,_that.handleResult,_that.ex);case _:
  return null;

}
}

}

/// @nodoc


class _GroupApplication implements GroupApplication {
  const _GroupApplication({required this.groupId, required this.userId, required this.nickname, required this.faceUrl, required this.reason, required this.handleResult, this.ex});
  

@override final  String groupId;
@override final  String userId;
@override final  String nickname;
@override final  String faceUrl;
@override final  String reason;
@override final  int handleResult;
@override final  String? ex;

/// Create a copy of GroupApplication
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GroupApplicationCopyWith<_GroupApplication> get copyWith => __$GroupApplicationCopyWithImpl<_GroupApplication>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _GroupApplication&&(identical(other.groupId, groupId) || other.groupId == groupId)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.nickname, nickname) || other.nickname == nickname)&&(identical(other.faceUrl, faceUrl) || other.faceUrl == faceUrl)&&(identical(other.reason, reason) || other.reason == reason)&&(identical(other.handleResult, handleResult) || other.handleResult == handleResult)&&(identical(other.ex, ex) || other.ex == ex));
}


@override
int get hashCode => Object.hash(runtimeType,groupId,userId,nickname,faceUrl,reason,handleResult,ex);

@override
String toString() {
  return 'GroupApplication(groupId: $groupId, userId: $userId, nickname: $nickname, faceUrl: $faceUrl, reason: $reason, handleResult: $handleResult, ex: $ex)';
}


}

/// @nodoc
abstract mixin class _$GroupApplicationCopyWith<$Res> implements $GroupApplicationCopyWith<$Res> {
  factory _$GroupApplicationCopyWith(_GroupApplication value, $Res Function(_GroupApplication) _then) = __$GroupApplicationCopyWithImpl;
@override @useResult
$Res call({
 String groupId, String userId, String nickname, String faceUrl, String reason, int handleResult, String? ex
});




}
/// @nodoc
class __$GroupApplicationCopyWithImpl<$Res>
    implements _$GroupApplicationCopyWith<$Res> {
  __$GroupApplicationCopyWithImpl(this._self, this._then);

  final _GroupApplication _self;
  final $Res Function(_GroupApplication) _then;

/// Create a copy of GroupApplication
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? groupId = null,Object? userId = null,Object? nickname = null,Object? faceUrl = null,Object? reason = null,Object? handleResult = null,Object? ex = freezed,}) {
  return _then(_GroupApplication(
groupId: null == groupId ? _self.groupId : groupId // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,nickname: null == nickname ? _self.nickname : nickname // ignore: cast_nullable_to_non_nullable
as String,faceUrl: null == faceUrl ? _self.faceUrl : faceUrl // ignore: cast_nullable_to_non_nullable
as String,reason: null == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String,handleResult: null == handleResult ? _self.handleResult : handleResult // ignore: cast_nullable_to_non_nullable
as int,ex: freezed == ex ? _self.ex : ex // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
