// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'group_application.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$GroupApplication {
  String get groupId => throw _privateConstructorUsedError;
  String get userId => throw _privateConstructorUsedError;
  String get nickname => throw _privateConstructorUsedError;
  String get faceUrl => throw _privateConstructorUsedError;
  String get reason => throw _privateConstructorUsedError;
  int get handleResult => throw _privateConstructorUsedError;
  String? get ex => throw _privateConstructorUsedError;

  /// Create a copy of GroupApplication
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $GroupApplicationCopyWith<GroupApplication> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $GroupApplicationCopyWith<$Res> {
  factory $GroupApplicationCopyWith(
    GroupApplication value,
    $Res Function(GroupApplication) then,
  ) = _$GroupApplicationCopyWithImpl<$Res, GroupApplication>;
  @useResult
  $Res call({
    String groupId,
    String userId,
    String nickname,
    String faceUrl,
    String reason,
    int handleResult,
    String? ex,
  });
}

/// @nodoc
class _$GroupApplicationCopyWithImpl<$Res, $Val extends GroupApplication>
    implements $GroupApplicationCopyWith<$Res> {
  _$GroupApplicationCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of GroupApplication
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? groupId = null,
    Object? userId = null,
    Object? nickname = null,
    Object? faceUrl = null,
    Object? reason = null,
    Object? handleResult = null,
    Object? ex = freezed,
  }) {
    return _then(
      _value.copyWith(
            groupId: null == groupId
                ? _value.groupId
                : groupId // ignore: cast_nullable_to_non_nullable
                      as String,
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
            reason: null == reason
                ? _value.reason
                : reason // ignore: cast_nullable_to_non_nullable
                      as String,
            handleResult: null == handleResult
                ? _value.handleResult
                : handleResult // ignore: cast_nullable_to_non_nullable
                      as int,
            ex: freezed == ex
                ? _value.ex
                : ex // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$GroupApplicationImplCopyWith<$Res>
    implements $GroupApplicationCopyWith<$Res> {
  factory _$$GroupApplicationImplCopyWith(
    _$GroupApplicationImpl value,
    $Res Function(_$GroupApplicationImpl) then,
  ) = __$$GroupApplicationImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String groupId,
    String userId,
    String nickname,
    String faceUrl,
    String reason,
    int handleResult,
    String? ex,
  });
}

/// @nodoc
class __$$GroupApplicationImplCopyWithImpl<$Res>
    extends _$GroupApplicationCopyWithImpl<$Res, _$GroupApplicationImpl>
    implements _$$GroupApplicationImplCopyWith<$Res> {
  __$$GroupApplicationImplCopyWithImpl(
    _$GroupApplicationImpl _value,
    $Res Function(_$GroupApplicationImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of GroupApplication
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? groupId = null,
    Object? userId = null,
    Object? nickname = null,
    Object? faceUrl = null,
    Object? reason = null,
    Object? handleResult = null,
    Object? ex = freezed,
  }) {
    return _then(
      _$GroupApplicationImpl(
        groupId: null == groupId
            ? _value.groupId
            : groupId // ignore: cast_nullable_to_non_nullable
                  as String,
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
        reason: null == reason
            ? _value.reason
            : reason // ignore: cast_nullable_to_non_nullable
                  as String,
        handleResult: null == handleResult
            ? _value.handleResult
            : handleResult // ignore: cast_nullable_to_non_nullable
                  as int,
        ex: freezed == ex
            ? _value.ex
            : ex // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc

class _$GroupApplicationImpl implements _GroupApplication {
  const _$GroupApplicationImpl({
    required this.groupId,
    required this.userId,
    required this.nickname,
    required this.faceUrl,
    required this.reason,
    required this.handleResult,
    this.ex,
  });

  @override
  final String groupId;
  @override
  final String userId;
  @override
  final String nickname;
  @override
  final String faceUrl;
  @override
  final String reason;
  @override
  final int handleResult;
  @override
  final String? ex;

  @override
  String toString() {
    return 'GroupApplication(groupId: $groupId, userId: $userId, nickname: $nickname, faceUrl: $faceUrl, reason: $reason, handleResult: $handleResult, ex: $ex)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$GroupApplicationImpl &&
            (identical(other.groupId, groupId) || other.groupId == groupId) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.nickname, nickname) ||
                other.nickname == nickname) &&
            (identical(other.faceUrl, faceUrl) || other.faceUrl == faceUrl) &&
            (identical(other.reason, reason) || other.reason == reason) &&
            (identical(other.handleResult, handleResult) ||
                other.handleResult == handleResult) &&
            (identical(other.ex, ex) || other.ex == ex));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    groupId,
    userId,
    nickname,
    faceUrl,
    reason,
    handleResult,
    ex,
  );

  /// Create a copy of GroupApplication
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$GroupApplicationImplCopyWith<_$GroupApplicationImpl> get copyWith =>
      __$$GroupApplicationImplCopyWithImpl<_$GroupApplicationImpl>(
        this,
        _$identity,
      );
}

abstract class _GroupApplication implements GroupApplication {
  const factory _GroupApplication({
    required final String groupId,
    required final String userId,
    required final String nickname,
    required final String faceUrl,
    required final String reason,
    required final int handleResult,
    final String? ex,
  }) = _$GroupApplicationImpl;

  @override
  String get groupId;
  @override
  String get userId;
  @override
  String get nickname;
  @override
  String get faceUrl;
  @override
  String get reason;
  @override
  int get handleResult;
  @override
  String? get ex;

  /// Create a copy of GroupApplication
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$GroupApplicationImplCopyWith<_$GroupApplicationImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
