// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'friend_search_result.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$FriendSearchResult {
  String get userId => throw _privateConstructorUsedError;
  String get nickname => throw _privateConstructorUsedError;
  String get faceUrl => throw _privateConstructorUsedError;
  String get remark => throw _privateConstructorUsedError;
  String get ex => throw _privateConstructorUsedError;
  int get relationship => throw _privateConstructorUsedError;
  DateTime? get createdTime => throw _privateConstructorUsedError;

  /// Create a copy of FriendSearchResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $FriendSearchResultCopyWith<FriendSearchResult> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $FriendSearchResultCopyWith<$Res> {
  factory $FriendSearchResultCopyWith(
    FriendSearchResult value,
    $Res Function(FriendSearchResult) then,
  ) = _$FriendSearchResultCopyWithImpl<$Res, FriendSearchResult>;
  @useResult
  $Res call({
    String userId,
    String nickname,
    String faceUrl,
    String remark,
    String ex,
    int relationship,
    DateTime? createdTime,
  });
}

/// @nodoc
class _$FriendSearchResultCopyWithImpl<$Res, $Val extends FriendSearchResult>
    implements $FriendSearchResultCopyWith<$Res> {
  _$FriendSearchResultCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of FriendSearchResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? userId = null,
    Object? nickname = null,
    Object? faceUrl = null,
    Object? remark = null,
    Object? ex = null,
    Object? relationship = null,
    Object? createdTime = freezed,
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
            remark: null == remark
                ? _value.remark
                : remark // ignore: cast_nullable_to_non_nullable
                      as String,
            ex: null == ex
                ? _value.ex
                : ex // ignore: cast_nullable_to_non_nullable
                      as String,
            relationship: null == relationship
                ? _value.relationship
                : relationship // ignore: cast_nullable_to_non_nullable
                      as int,
            createdTime: freezed == createdTime
                ? _value.createdTime
                : createdTime // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$FriendSearchResultImplCopyWith<$Res>
    implements $FriendSearchResultCopyWith<$Res> {
  factory _$$FriendSearchResultImplCopyWith(
    _$FriendSearchResultImpl value,
    $Res Function(_$FriendSearchResultImpl) then,
  ) = __$$FriendSearchResultImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String userId,
    String nickname,
    String faceUrl,
    String remark,
    String ex,
    int relationship,
    DateTime? createdTime,
  });
}

/// @nodoc
class __$$FriendSearchResultImplCopyWithImpl<$Res>
    extends _$FriendSearchResultCopyWithImpl<$Res, _$FriendSearchResultImpl>
    implements _$$FriendSearchResultImplCopyWith<$Res> {
  __$$FriendSearchResultImplCopyWithImpl(
    _$FriendSearchResultImpl _value,
    $Res Function(_$FriendSearchResultImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of FriendSearchResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? userId = null,
    Object? nickname = null,
    Object? faceUrl = null,
    Object? remark = null,
    Object? ex = null,
    Object? relationship = null,
    Object? createdTime = freezed,
  }) {
    return _then(
      _$FriendSearchResultImpl(
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
        remark: null == remark
            ? _value.remark
            : remark // ignore: cast_nullable_to_non_nullable
                  as String,
        ex: null == ex
            ? _value.ex
            : ex // ignore: cast_nullable_to_non_nullable
                  as String,
        relationship: null == relationship
            ? _value.relationship
            : relationship // ignore: cast_nullable_to_non_nullable
                  as int,
        createdTime: freezed == createdTime
            ? _value.createdTime
            : createdTime // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
      ),
    );
  }
}

/// @nodoc

class _$FriendSearchResultImpl implements _FriendSearchResult {
  const _$FriendSearchResultImpl({
    required this.userId,
    required this.nickname,
    required this.faceUrl,
    required this.remark,
    required this.ex,
    required this.relationship,
    this.createdTime,
  });

  @override
  final String userId;
  @override
  final String nickname;
  @override
  final String faceUrl;
  @override
  final String remark;
  @override
  final String ex;
  @override
  final int relationship;
  @override
  final DateTime? createdTime;

  @override
  String toString() {
    return 'FriendSearchResult(userId: $userId, nickname: $nickname, faceUrl: $faceUrl, remark: $remark, ex: $ex, relationship: $relationship, createdTime: $createdTime)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FriendSearchResultImpl &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.nickname, nickname) ||
                other.nickname == nickname) &&
            (identical(other.faceUrl, faceUrl) || other.faceUrl == faceUrl) &&
            (identical(other.remark, remark) || other.remark == remark) &&
            (identical(other.ex, ex) || other.ex == ex) &&
            (identical(other.relationship, relationship) ||
                other.relationship == relationship) &&
            (identical(other.createdTime, createdTime) ||
                other.createdTime == createdTime));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    userId,
    nickname,
    faceUrl,
    remark,
    ex,
    relationship,
    createdTime,
  );

  /// Create a copy of FriendSearchResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$FriendSearchResultImplCopyWith<_$FriendSearchResultImpl> get copyWith =>
      __$$FriendSearchResultImplCopyWithImpl<_$FriendSearchResultImpl>(
        this,
        _$identity,
      );
}

abstract class _FriendSearchResult implements FriendSearchResult {
  const factory _FriendSearchResult({
    required final String userId,
    required final String nickname,
    required final String faceUrl,
    required final String remark,
    required final String ex,
    required final int relationship,
    final DateTime? createdTime,
  }) = _$FriendSearchResultImpl;

  @override
  String get userId;
  @override
  String get nickname;
  @override
  String get faceUrl;
  @override
  String get remark;
  @override
  String get ex;
  @override
  int get relationship;
  @override
  DateTime? get createdTime;

  /// Create a copy of FriendSearchResult
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$FriendSearchResultImplCopyWith<_$FriendSearchResultImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
