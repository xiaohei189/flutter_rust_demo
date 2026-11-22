// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'friend_search_result.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$FriendSearchResult {

 String get userId; String get nickname; String get faceUrl; String get remark; String get ex; int get relationship; DateTime? get createdTime;
/// Create a copy of FriendSearchResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FriendSearchResultCopyWith<FriendSearchResult> get copyWith => _$FriendSearchResultCopyWithImpl<FriendSearchResult>(this as FriendSearchResult, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FriendSearchResult&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.nickname, nickname) || other.nickname == nickname)&&(identical(other.faceUrl, faceUrl) || other.faceUrl == faceUrl)&&(identical(other.remark, remark) || other.remark == remark)&&(identical(other.ex, ex) || other.ex == ex)&&(identical(other.relationship, relationship) || other.relationship == relationship)&&(identical(other.createdTime, createdTime) || other.createdTime == createdTime));
}


@override
int get hashCode => Object.hash(runtimeType,userId,nickname,faceUrl,remark,ex,relationship,createdTime);

@override
String toString() {
  return 'FriendSearchResult(userId: $userId, nickname: $nickname, faceUrl: $faceUrl, remark: $remark, ex: $ex, relationship: $relationship, createdTime: $createdTime)';
}


}

/// @nodoc
abstract mixin class $FriendSearchResultCopyWith<$Res>  {
  factory $FriendSearchResultCopyWith(FriendSearchResult value, $Res Function(FriendSearchResult) _then) = _$FriendSearchResultCopyWithImpl;
@useResult
$Res call({
 String userId, String nickname, String faceUrl, String remark, String ex, int relationship, DateTime? createdTime
});




}
/// @nodoc
class _$FriendSearchResultCopyWithImpl<$Res>
    implements $FriendSearchResultCopyWith<$Res> {
  _$FriendSearchResultCopyWithImpl(this._self, this._then);

  final FriendSearchResult _self;
  final $Res Function(FriendSearchResult) _then;

/// Create a copy of FriendSearchResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? userId = null,Object? nickname = null,Object? faceUrl = null,Object? remark = null,Object? ex = null,Object? relationship = null,Object? createdTime = freezed,}) {
  return _then(_self.copyWith(
userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,nickname: null == nickname ? _self.nickname : nickname // ignore: cast_nullable_to_non_nullable
as String,faceUrl: null == faceUrl ? _self.faceUrl : faceUrl // ignore: cast_nullable_to_non_nullable
as String,remark: null == remark ? _self.remark : remark // ignore: cast_nullable_to_non_nullable
as String,ex: null == ex ? _self.ex : ex // ignore: cast_nullable_to_non_nullable
as String,relationship: null == relationship ? _self.relationship : relationship // ignore: cast_nullable_to_non_nullable
as int,createdTime: freezed == createdTime ? _self.createdTime : createdTime // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [FriendSearchResult].
extension FriendSearchResultPatterns on FriendSearchResult {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FriendSearchResult value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FriendSearchResult() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FriendSearchResult value)  $default,){
final _that = this;
switch (_that) {
case _FriendSearchResult():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FriendSearchResult value)?  $default,){
final _that = this;
switch (_that) {
case _FriendSearchResult() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String userId,  String nickname,  String faceUrl,  String remark,  String ex,  int relationship,  DateTime? createdTime)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FriendSearchResult() when $default != null:
return $default(_that.userId,_that.nickname,_that.faceUrl,_that.remark,_that.ex,_that.relationship,_that.createdTime);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String userId,  String nickname,  String faceUrl,  String remark,  String ex,  int relationship,  DateTime? createdTime)  $default,) {final _that = this;
switch (_that) {
case _FriendSearchResult():
return $default(_that.userId,_that.nickname,_that.faceUrl,_that.remark,_that.ex,_that.relationship,_that.createdTime);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String userId,  String nickname,  String faceUrl,  String remark,  String ex,  int relationship,  DateTime? createdTime)?  $default,) {final _that = this;
switch (_that) {
case _FriendSearchResult() when $default != null:
return $default(_that.userId,_that.nickname,_that.faceUrl,_that.remark,_that.ex,_that.relationship,_that.createdTime);case _:
  return null;

}
}

}

/// @nodoc


class _FriendSearchResult implements FriendSearchResult {
  const _FriendSearchResult({required this.userId, required this.nickname, required this.faceUrl, required this.remark, required this.ex, required this.relationship, this.createdTime});
  

@override final  String userId;
@override final  String nickname;
@override final  String faceUrl;
@override final  String remark;
@override final  String ex;
@override final  int relationship;
@override final  DateTime? createdTime;

/// Create a copy of FriendSearchResult
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FriendSearchResultCopyWith<_FriendSearchResult> get copyWith => __$FriendSearchResultCopyWithImpl<_FriendSearchResult>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FriendSearchResult&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.nickname, nickname) || other.nickname == nickname)&&(identical(other.faceUrl, faceUrl) || other.faceUrl == faceUrl)&&(identical(other.remark, remark) || other.remark == remark)&&(identical(other.ex, ex) || other.ex == ex)&&(identical(other.relationship, relationship) || other.relationship == relationship)&&(identical(other.createdTime, createdTime) || other.createdTime == createdTime));
}


@override
int get hashCode => Object.hash(runtimeType,userId,nickname,faceUrl,remark,ex,relationship,createdTime);

@override
String toString() {
  return 'FriendSearchResult(userId: $userId, nickname: $nickname, faceUrl: $faceUrl, remark: $remark, ex: $ex, relationship: $relationship, createdTime: $createdTime)';
}


}

/// @nodoc
abstract mixin class _$FriendSearchResultCopyWith<$Res> implements $FriendSearchResultCopyWith<$Res> {
  factory _$FriendSearchResultCopyWith(_FriendSearchResult value, $Res Function(_FriendSearchResult) _then) = __$FriendSearchResultCopyWithImpl;
@override @useResult
$Res call({
 String userId, String nickname, String faceUrl, String remark, String ex, int relationship, DateTime? createdTime
});




}
/// @nodoc
class __$FriendSearchResultCopyWithImpl<$Res>
    implements _$FriendSearchResultCopyWith<$Res> {
  __$FriendSearchResultCopyWithImpl(this._self, this._then);

  final _FriendSearchResult _self;
  final $Res Function(_FriendSearchResult) _then;

/// Create a copy of FriendSearchResult
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? userId = null,Object? nickname = null,Object? faceUrl = null,Object? remark = null,Object? ex = null,Object? relationship = null,Object? createdTime = freezed,}) {
  return _then(_FriendSearchResult(
userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,nickname: null == nickname ? _self.nickname : nickname // ignore: cast_nullable_to_non_nullable
as String,faceUrl: null == faceUrl ? _self.faceUrl : faceUrl // ignore: cast_nullable_to_non_nullable
as String,remark: null == remark ? _self.remark : remark // ignore: cast_nullable_to_non_nullable
as String,ex: null == ex ? _self.ex : ex // ignore: cast_nullable_to_non_nullable
as String,relationship: null == relationship ? _self.relationship : relationship // ignore: cast_nullable_to_non_nullable
as int,createdTime: freezed == createdTime ? _self.createdTime : createdTime // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
