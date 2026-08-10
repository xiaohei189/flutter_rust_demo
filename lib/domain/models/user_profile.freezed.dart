// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'user_profile.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$UserProfile {
  String get userId => throw _privateConstructorUsedError;
  String get nickname => throw _privateConstructorUsedError;
  String get faceUrl => throw _privateConstructorUsedError;
  int get gender => throw _privateConstructorUsedError;
  String get telephone => throw _privateConstructorUsedError;
  String get email => throw _privateConstructorUsedError;
  String get remark => throw _privateConstructorUsedError;
  int get globalRecvMsgOpt => throw _privateConstructorUsedError;

  /// Create a copy of UserProfile
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $UserProfileCopyWith<UserProfile> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $UserProfileCopyWith<$Res> {
  factory $UserProfileCopyWith(
    UserProfile value,
    $Res Function(UserProfile) then,
  ) = _$UserProfileCopyWithImpl<$Res, UserProfile>;
  @useResult
  $Res call({
    String userId,
    String nickname,
    String faceUrl,
    int gender,
    String telephone,
    String email,
    String remark,
    int globalRecvMsgOpt,
  });
}

/// @nodoc
class _$UserProfileCopyWithImpl<$Res, $Val extends UserProfile>
    implements $UserProfileCopyWith<$Res> {
  _$UserProfileCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of UserProfile
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? userId = null,
    Object? nickname = null,
    Object? faceUrl = null,
    Object? gender = null,
    Object? telephone = null,
    Object? email = null,
    Object? remark = null,
    Object? globalRecvMsgOpt = null,
  }) {
    return _then(
      _value.copyWith(
            userId: null == userId
                ? _value.userId
                : userId // ignore: cast_nullable_to_non_nullable
                      as String,
            nickname: null == nickname
                ? _value.nickname
                : nickname // ignore: cast_nullable_to_non_nullable
                      as String,
            faceUrl: null == faceUrl
                ? _value.faceUrl
                : faceUrl // ignore: cast_nullable_to_non_nullable
                      as String,
            gender: null == gender
                ? _value.gender
                : gender // ignore: cast_nullable_to_non_nullable
                      as int,
            telephone: null == telephone
                ? _value.telephone
                : telephone // ignore: cast_nullable_to_non_nullable
                      as String,
            email: null == email
                ? _value.email
                : email // ignore: cast_nullable_to_non_nullable
                      as String,
            remark: null == remark
                ? _value.remark
                : remark // ignore: cast_nullable_to_non_nullable
                      as String,
            globalRecvMsgOpt: null == globalRecvMsgOpt
                ? _value.globalRecvMsgOpt
                : globalRecvMsgOpt // ignore: cast_nullable_to_non_nullable
                      as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$UserProfileImplCopyWith<$Res>
    implements $UserProfileCopyWith<$Res> {
  factory _$$UserProfileImplCopyWith(
    _$UserProfileImpl value,
    $Res Function(_$UserProfileImpl) then,
  ) = __$$UserProfileImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String userId,
    String nickname,
    String faceUrl,
    int gender,
    String telephone,
    String email,
    String remark,
    int globalRecvMsgOpt,
  });
}

/// @nodoc
class __$$UserProfileImplCopyWithImpl<$Res>
    extends _$UserProfileCopyWithImpl<$Res, _$UserProfileImpl>
    implements _$$UserProfileImplCopyWith<$Res> {
  __$$UserProfileImplCopyWithImpl(
    _$UserProfileImpl _value,
    $Res Function(_$UserProfileImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of UserProfile
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? userId = null,
    Object? nickname = null,
    Object? faceUrl = null,
    Object? gender = null,
    Object? telephone = null,
    Object? email = null,
    Object? remark = null,
    Object? globalRecvMsgOpt = null,
  }) {
    return _then(
      _$UserProfileImpl(
        userId: null == userId
            ? _value.userId
            : userId // ignore: cast_nullable_to_non_nullable
                  as String,
        nickname: null == nickname
            ? _value.nickname
            : nickname // ignore: cast_nullable_to_non_nullable
                  as String,
        faceUrl: null == faceUrl
            ? _value.faceUrl
            : faceUrl // ignore: cast_nullable_to_non_nullable
                  as String,
        gender: null == gender
            ? _value.gender
            : gender // ignore: cast_nullable_to_non_nullable
                  as int,
        telephone: null == telephone
            ? _value.telephone
            : telephone // ignore: cast_nullable_to_non_nullable
                  as String,
        email: null == email
            ? _value.email
            : email // ignore: cast_nullable_to_non_nullable
                  as String,
        remark: null == remark
            ? _value.remark
            : remark // ignore: cast_nullable_to_non_nullable
                  as String,
        globalRecvMsgOpt: null == globalRecvMsgOpt
            ? _value.globalRecvMsgOpt
            : globalRecvMsgOpt // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc

class _$UserProfileImpl implements _UserProfile {
  const _$UserProfileImpl({
    required this.userId,
    required this.nickname,
    required this.faceUrl,
    required this.gender,
    required this.telephone,
    required this.email,
    required this.remark,
    required this.globalRecvMsgOpt,
  });

  @override
  final String userId;
  @override
  final String nickname;
  @override
  final String faceUrl;
  @override
  final int gender;
  @override
  final String telephone;
  @override
  final String email;
  @override
  final String remark;
  @override
  final int globalRecvMsgOpt;

  @override
  String toString() {
    return 'UserProfile(userId: $userId, nickname: $nickname, faceUrl: $faceUrl, gender: $gender, telephone: $telephone, email: $email, remark: $remark, globalRecvMsgOpt: $globalRecvMsgOpt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$UserProfileImpl &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.nickname, nickname) ||
                other.nickname == nickname) &&
            (identical(other.faceUrl, faceUrl) || other.faceUrl == faceUrl) &&
            (identical(other.gender, gender) || other.gender == gender) &&
            (identical(other.telephone, telephone) ||
                other.telephone == telephone) &&
            (identical(other.email, email) || other.email == email) &&
            (identical(other.remark, remark) || other.remark == remark) &&
            (identical(other.globalRecvMsgOpt, globalRecvMsgOpt) ||
                other.globalRecvMsgOpt == globalRecvMsgOpt));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    userId,
    nickname,
    faceUrl,
    gender,
    telephone,
    email,
    remark,
    globalRecvMsgOpt,
  );

  /// Create a copy of UserProfile
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$UserProfileImplCopyWith<_$UserProfileImpl> get copyWith =>
      __$$UserProfileImplCopyWithImpl<_$UserProfileImpl>(this, _$identity);
}

abstract class _UserProfile implements UserProfile {
  const factory _UserProfile({
    required final String userId,
    required final String nickname,
    required final String faceUrl,
    required final int gender,
    required final String telephone,
    required final String email,
    required final String remark,
    required final int globalRecvMsgOpt,
  }) = _$UserProfileImpl;

  @override
  String get userId;
  @override
  String get nickname;
  @override
  String get faceUrl;
  @override
  int get gender;
  @override
  String get telephone;
  @override
  String get email;
  @override
  String get remark;
  @override
  int get globalRecvMsgOpt;

  /// Create a copy of UserProfile
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$UserProfileImplCopyWith<_$UserProfileImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
