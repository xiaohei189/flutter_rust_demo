// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'user_profile.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$UserProfile {

 String get userId; String get nickname; String get faceUrl; int get gender; String get telephone; String get areaCode; String get phoneNumber; String get email; String get remark; int get globalRecvMsgOpt;
/// Create a copy of UserProfile
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UserProfileCopyWith<UserProfile> get copyWith => _$UserProfileCopyWithImpl<UserProfile>(this as UserProfile, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UserProfile&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.nickname, nickname) || other.nickname == nickname)&&(identical(other.faceUrl, faceUrl) || other.faceUrl == faceUrl)&&(identical(other.gender, gender) || other.gender == gender)&&(identical(other.telephone, telephone) || other.telephone == telephone)&&(identical(other.areaCode, areaCode) || other.areaCode == areaCode)&&(identical(other.phoneNumber, phoneNumber) || other.phoneNumber == phoneNumber)&&(identical(other.email, email) || other.email == email)&&(identical(other.remark, remark) || other.remark == remark)&&(identical(other.globalRecvMsgOpt, globalRecvMsgOpt) || other.globalRecvMsgOpt == globalRecvMsgOpt));
}


@override
int get hashCode => Object.hash(runtimeType,userId,nickname,faceUrl,gender,telephone,areaCode,phoneNumber,email,remark,globalRecvMsgOpt);

@override
String toString() {
  return 'UserProfile(userId: $userId, nickname: $nickname, faceUrl: $faceUrl, gender: $gender, telephone: $telephone, areaCode: $areaCode, phoneNumber: $phoneNumber, email: $email, remark: $remark, globalRecvMsgOpt: $globalRecvMsgOpt)';
}


}

/// @nodoc
abstract mixin class $UserProfileCopyWith<$Res>  {
  factory $UserProfileCopyWith(UserProfile value, $Res Function(UserProfile) _then) = _$UserProfileCopyWithImpl;
@useResult
$Res call({
 String userId, String nickname, String faceUrl, int gender, String telephone, String areaCode, String phoneNumber, String email, String remark, int globalRecvMsgOpt
});




}
/// @nodoc
class _$UserProfileCopyWithImpl<$Res>
    implements $UserProfileCopyWith<$Res> {
  _$UserProfileCopyWithImpl(this._self, this._then);

  final UserProfile _self;
  final $Res Function(UserProfile) _then;

/// Create a copy of UserProfile
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? userId = null,Object? nickname = null,Object? faceUrl = null,Object? gender = null,Object? telephone = null,Object? areaCode = null,Object? phoneNumber = null,Object? email = null,Object? remark = null,Object? globalRecvMsgOpt = null,}) {
  return _then(_self.copyWith(
userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,nickname: null == nickname ? _self.nickname : nickname // ignore: cast_nullable_to_non_nullable
as String,faceUrl: null == faceUrl ? _self.faceUrl : faceUrl // ignore: cast_nullable_to_non_nullable
as String,gender: null == gender ? _self.gender : gender // ignore: cast_nullable_to_non_nullable
as int,telephone: null == telephone ? _self.telephone : telephone // ignore: cast_nullable_to_non_nullable
as String,areaCode: null == areaCode ? _self.areaCode : areaCode // ignore: cast_nullable_to_non_nullable
as String,phoneNumber: null == phoneNumber ? _self.phoneNumber : phoneNumber // ignore: cast_nullable_to_non_nullable
as String,email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,remark: null == remark ? _self.remark : remark // ignore: cast_nullable_to_non_nullable
as String,globalRecvMsgOpt: null == globalRecvMsgOpt ? _self.globalRecvMsgOpt : globalRecvMsgOpt // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [UserProfile].
extension UserProfilePatterns on UserProfile {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UserProfile value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UserProfile() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UserProfile value)  $default,){
final _that = this;
switch (_that) {
case _UserProfile():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UserProfile value)?  $default,){
final _that = this;
switch (_that) {
case _UserProfile() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String userId,  String nickname,  String faceUrl,  int gender,  String telephone,  String areaCode,  String phoneNumber,  String email,  String remark,  int globalRecvMsgOpt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UserProfile() when $default != null:
return $default(_that.userId,_that.nickname,_that.faceUrl,_that.gender,_that.telephone,_that.areaCode,_that.phoneNumber,_that.email,_that.remark,_that.globalRecvMsgOpt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String userId,  String nickname,  String faceUrl,  int gender,  String telephone,  String areaCode,  String phoneNumber,  String email,  String remark,  int globalRecvMsgOpt)  $default,) {final _that = this;
switch (_that) {
case _UserProfile():
return $default(_that.userId,_that.nickname,_that.faceUrl,_that.gender,_that.telephone,_that.areaCode,_that.phoneNumber,_that.email,_that.remark,_that.globalRecvMsgOpt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String userId,  String nickname,  String faceUrl,  int gender,  String telephone,  String areaCode,  String phoneNumber,  String email,  String remark,  int globalRecvMsgOpt)?  $default,) {final _that = this;
switch (_that) {
case _UserProfile() when $default != null:
return $default(_that.userId,_that.nickname,_that.faceUrl,_that.gender,_that.telephone,_that.areaCode,_that.phoneNumber,_that.email,_that.remark,_that.globalRecvMsgOpt);case _:
  return null;

}
}

}

/// @nodoc


class _UserProfile implements UserProfile {
  const _UserProfile({required this.userId, required this.nickname, required this.faceUrl, required this.gender, required this.telephone, this.areaCode = '', this.phoneNumber = '', required this.email, required this.remark, required this.globalRecvMsgOpt});
  

@override final  String userId;
@override final  String nickname;
@override final  String faceUrl;
@override final  int gender;
@override final  String telephone;
@override@JsonKey() final  String areaCode;
@override@JsonKey() final  String phoneNumber;
@override final  String email;
@override final  String remark;
@override final  int globalRecvMsgOpt;

/// Create a copy of UserProfile
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UserProfileCopyWith<_UserProfile> get copyWith => __$UserProfileCopyWithImpl<_UserProfile>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UserProfile&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.nickname, nickname) || other.nickname == nickname)&&(identical(other.faceUrl, faceUrl) || other.faceUrl == faceUrl)&&(identical(other.gender, gender) || other.gender == gender)&&(identical(other.telephone, telephone) || other.telephone == telephone)&&(identical(other.areaCode, areaCode) || other.areaCode == areaCode)&&(identical(other.phoneNumber, phoneNumber) || other.phoneNumber == phoneNumber)&&(identical(other.email, email) || other.email == email)&&(identical(other.remark, remark) || other.remark == remark)&&(identical(other.globalRecvMsgOpt, globalRecvMsgOpt) || other.globalRecvMsgOpt == globalRecvMsgOpt));
}


@override
int get hashCode => Object.hash(runtimeType,userId,nickname,faceUrl,gender,telephone,areaCode,phoneNumber,email,remark,globalRecvMsgOpt);

@override
String toString() {
  return 'UserProfile(userId: $userId, nickname: $nickname, faceUrl: $faceUrl, gender: $gender, telephone: $telephone, areaCode: $areaCode, phoneNumber: $phoneNumber, email: $email, remark: $remark, globalRecvMsgOpt: $globalRecvMsgOpt)';
}


}

/// @nodoc
abstract mixin class _$UserProfileCopyWith<$Res> implements $UserProfileCopyWith<$Res> {
  factory _$UserProfileCopyWith(_UserProfile value, $Res Function(_UserProfile) _then) = __$UserProfileCopyWithImpl;
@override @useResult
$Res call({
 String userId, String nickname, String faceUrl, int gender, String telephone, String areaCode, String phoneNumber, String email, String remark, int globalRecvMsgOpt
});




}
/// @nodoc
class __$UserProfileCopyWithImpl<$Res>
    implements _$UserProfileCopyWith<$Res> {
  __$UserProfileCopyWithImpl(this._self, this._then);

  final _UserProfile _self;
  final $Res Function(_UserProfile) _then;

/// Create a copy of UserProfile
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? userId = null,Object? nickname = null,Object? faceUrl = null,Object? gender = null,Object? telephone = null,Object? areaCode = null,Object? phoneNumber = null,Object? email = null,Object? remark = null,Object? globalRecvMsgOpt = null,}) {
  return _then(_UserProfile(
userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,nickname: null == nickname ? _self.nickname : nickname // ignore: cast_nullable_to_non_nullable
as String,faceUrl: null == faceUrl ? _self.faceUrl : faceUrl // ignore: cast_nullable_to_non_nullable
as String,gender: null == gender ? _self.gender : gender // ignore: cast_nullable_to_non_nullable
as int,telephone: null == telephone ? _self.telephone : telephone // ignore: cast_nullable_to_non_nullable
as String,areaCode: null == areaCode ? _self.areaCode : areaCode // ignore: cast_nullable_to_non_nullable
as String,phoneNumber: null == phoneNumber ? _self.phoneNumber : phoneNumber // ignore: cast_nullable_to_non_nullable
as String,email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,remark: null == remark ? _self.remark : remark // ignore: cast_nullable_to_non_nullable
as String,globalRecvMsgOpt: null == globalRecvMsgOpt ? _self.globalRecvMsgOpt : globalRecvMsgOpt // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
