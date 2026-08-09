// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'group_member.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$GroupMember {
  String get groupId => throw _privateConstructorUsedError;
  String get userId => throw _privateConstructorUsedError;
  String get nickname => throw _privateConstructorUsedError;
  String get faceUrl => throw _privateConstructorUsedError;
  int get roleLevel => throw _privateConstructorUsedError;
  String get joinSource => throw _privateConstructorUsedError;
  DateTime? get joinTime => throw _privateConstructorUsedError;

  /// Create a copy of GroupMember
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $GroupMemberCopyWith<GroupMember> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $GroupMemberCopyWith<$Res> {
  factory $GroupMemberCopyWith(
    GroupMember value,
    $Res Function(GroupMember) then,
  ) = _$GroupMemberCopyWithImpl<$Res, GroupMember>;
  @useResult
  $Res call({
    String groupId,
    String userId,
    String nickname,
    String faceUrl,
    int roleLevel,
    String joinSource,
    DateTime? joinTime,
  });
}

/// @nodoc
class _$GroupMemberCopyWithImpl<$Res, $Val extends GroupMember>
    implements $GroupMemberCopyWith<$Res> {
  _$GroupMemberCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of GroupMember
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? groupId = null,
    Object? userId = null,
    Object? nickname = null,
    Object? faceUrl = null,
    Object? roleLevel = null,
    Object? joinSource = null,
    Object? joinTime = freezed,
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
            roleLevel: null == roleLevel
                ? _value.roleLevel
                : roleLevel // ignore: cast_nullable_to_non_nullable
                      as int,
            joinSource: null == joinSource
                ? _value.joinSource
                : joinSource // ignore: cast_nullable_to_non_nullable
                      as String,
            joinTime: freezed == joinTime
                ? _value.joinTime
                : joinTime // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$GroupMemberImplCopyWith<$Res>
    implements $GroupMemberCopyWith<$Res> {
  factory _$$GroupMemberImplCopyWith(
    _$GroupMemberImpl value,
    $Res Function(_$GroupMemberImpl) then,
  ) = __$$GroupMemberImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String groupId,
    String userId,
    String nickname,
    String faceUrl,
    int roleLevel,
    String joinSource,
    DateTime? joinTime,
  });
}

/// @nodoc
class __$$GroupMemberImplCopyWithImpl<$Res>
    extends _$GroupMemberCopyWithImpl<$Res, _$GroupMemberImpl>
    implements _$$GroupMemberImplCopyWith<$Res> {
  __$$GroupMemberImplCopyWithImpl(
    _$GroupMemberImpl _value,
    $Res Function(_$GroupMemberImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of GroupMember
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? groupId = null,
    Object? userId = null,
    Object? nickname = null,
    Object? faceUrl = null,
    Object? roleLevel = null,
    Object? joinSource = null,
    Object? joinTime = freezed,
  }) {
    return _then(
      _$GroupMemberImpl(
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
        roleLevel: null == roleLevel
            ? _value.roleLevel
            : roleLevel // ignore: cast_nullable_to_non_nullable
                  as int,
        joinSource: null == joinSource
            ? _value.joinSource
            : joinSource // ignore: cast_nullable_to_non_nullable
                  as String,
        joinTime: freezed == joinTime
            ? _value.joinTime
            : joinTime // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
      ),
    );
  }
}

/// @nodoc

class _$GroupMemberImpl implements _GroupMember {
  const _$GroupMemberImpl({
    required this.groupId,
    required this.userId,
    required this.nickname,
    required this.faceUrl,
    required this.roleLevel,
    required this.joinSource,
    this.joinTime,
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
  final int roleLevel;
  @override
  final String joinSource;
  @override
  final DateTime? joinTime;

  @override
  String toString() {
    return 'GroupMember(groupId: $groupId, userId: $userId, nickname: $nickname, faceUrl: $faceUrl, roleLevel: $roleLevel, joinSource: $joinSource, joinTime: $joinTime)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$GroupMemberImpl &&
            (identical(other.groupId, groupId) || other.groupId == groupId) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.nickname, nickname) ||
                other.nickname == nickname) &&
            (identical(other.faceUrl, faceUrl) || other.faceUrl == faceUrl) &&
            (identical(other.roleLevel, roleLevel) ||
                other.roleLevel == roleLevel) &&
            (identical(other.joinSource, joinSource) ||
                other.joinSource == joinSource) &&
            (identical(other.joinTime, joinTime) ||
                other.joinTime == joinTime));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    groupId,
    userId,
    nickname,
    faceUrl,
    roleLevel,
    joinSource,
    joinTime,
  );

  /// Create a copy of GroupMember
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$GroupMemberImplCopyWith<_$GroupMemberImpl> get copyWith =>
      __$$GroupMemberImplCopyWithImpl<_$GroupMemberImpl>(this, _$identity);
}

abstract class _GroupMember implements GroupMember {
  const factory _GroupMember({
    required final String groupId,
    required final String userId,
    required final String nickname,
    required final String faceUrl,
    required final int roleLevel,
    required final String joinSource,
    final DateTime? joinTime,
  }) = _$GroupMemberImpl;

  @override
  String get groupId;
  @override
  String get userId;
  @override
  String get nickname;
  @override
  String get faceUrl;
  @override
  int get roleLevel;
  @override
  String get joinSource;
  @override
  DateTime? get joinTime;

  /// Create a copy of GroupMember
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$GroupMemberImplCopyWith<_$GroupMemberImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
