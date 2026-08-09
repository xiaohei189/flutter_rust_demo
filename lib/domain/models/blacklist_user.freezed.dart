// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'blacklist_user.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$BlacklistUser {
  String get userId => throw _privateConstructorUsedError;
  String get nickname => throw _privateConstructorUsedError;
  String get faceUrl => throw _privateConstructorUsedError;

  /// Create a copy of BlacklistUser
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $BlacklistUserCopyWith<BlacklistUser> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $BlacklistUserCopyWith<$Res> {
  factory $BlacklistUserCopyWith(
    BlacklistUser value,
    $Res Function(BlacklistUser) then,
  ) = _$BlacklistUserCopyWithImpl<$Res, BlacklistUser>;
  @useResult
  $Res call({String userId, String nickname, String faceUrl});
}

/// @nodoc
class _$BlacklistUserCopyWithImpl<$Res, $Val extends BlacklistUser>
    implements $BlacklistUserCopyWith<$Res> {
  _$BlacklistUserCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of BlacklistUser
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? userId = null,
    Object? nickname = null,
    Object? faceUrl = null,
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
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$BlacklistUserImplCopyWith<$Res>
    implements $BlacklistUserCopyWith<$Res> {
  factory _$$BlacklistUserImplCopyWith(
    _$BlacklistUserImpl value,
    $Res Function(_$BlacklistUserImpl) then,
  ) = __$$BlacklistUserImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String userId, String nickname, String faceUrl});
}

/// @nodoc
class __$$BlacklistUserImplCopyWithImpl<$Res>
    extends _$BlacklistUserCopyWithImpl<$Res, _$BlacklistUserImpl>
    implements _$$BlacklistUserImplCopyWith<$Res> {
  __$$BlacklistUserImplCopyWithImpl(
    _$BlacklistUserImpl _value,
    $Res Function(_$BlacklistUserImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of BlacklistUser
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? userId = null,
    Object? nickname = null,
    Object? faceUrl = null,
  }) {
    return _then(
      _$BlacklistUserImpl(
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
      ),
    );
  }
}

/// @nodoc

class _$BlacklistUserImpl implements _BlacklistUser {
  const _$BlacklistUserImpl({
    required this.userId,
    required this.nickname,
    required this.faceUrl,
  });

  @override
  final String userId;
  @override
  final String nickname;
  @override
  final String faceUrl;

  @override
  String toString() {
    return 'BlacklistUser(userId: $userId, nickname: $nickname, faceUrl: $faceUrl)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BlacklistUserImpl &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.nickname, nickname) ||
                other.nickname == nickname) &&
            (identical(other.faceUrl, faceUrl) || other.faceUrl == faceUrl));
  }

  @override
  int get hashCode => Object.hash(runtimeType, userId, nickname, faceUrl);

  /// Create a copy of BlacklistUser
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$BlacklistUserImplCopyWith<_$BlacklistUserImpl> get copyWith =>
      __$$BlacklistUserImplCopyWithImpl<_$BlacklistUserImpl>(this, _$identity);
}

abstract class _BlacklistUser implements BlacklistUser {
  const factory _BlacklistUser({
    required final String userId,
    required final String nickname,
    required final String faceUrl,
  }) = _$BlacklistUserImpl;

  @override
  String get userId;
  @override
  String get nickname;
  @override
  String get faceUrl;

  /// Create a copy of BlacklistUser
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$BlacklistUserImplCopyWith<_$BlacklistUserImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
