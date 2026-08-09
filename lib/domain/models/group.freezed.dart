// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'group.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$Group {
  String get groupId => throw _privateConstructorUsedError;
  String get groupName => throw _privateConstructorUsedError;
  String get faceUrl => throw _privateConstructorUsedError;
  String get introduction => throw _privateConstructorUsedError;
  String get notification => throw _privateConstructorUsedError;
  String get ownerUserId => throw _privateConstructorUsedError;
  int get memberCount => throw _privateConstructorUsedError;
  int get status => throw _privateConstructorUsedError;
  DateTime? get createdTime => throw _privateConstructorUsedError;

  /// Create a copy of Group
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $GroupCopyWith<Group> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $GroupCopyWith<$Res> {
  factory $GroupCopyWith(Group value, $Res Function(Group) then) =
      _$GroupCopyWithImpl<$Res, Group>;
  @useResult
  $Res call({
    String groupId,
    String groupName,
    String faceUrl,
    String introduction,
    String notification,
    String ownerUserId,
    int memberCount,
    int status,
    DateTime? createdTime,
  });
}

/// @nodoc
class _$GroupCopyWithImpl<$Res, $Val extends Group>
    implements $GroupCopyWith<$Res> {
  _$GroupCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Group
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? groupId = null,
    Object? groupName = null,
    Object? faceUrl = null,
    Object? introduction = null,
    Object? notification = null,
    Object? ownerUserId = null,
    Object? memberCount = null,
    Object? status = null,
    Object? createdTime = freezed,
  }) {
    return _then(
      _value.copyWith(
            groupId: null == groupId
                ? _value.groupId
                : groupId // ignore: cast_nullable_to_non_nullable
                      as String,
            groupName: null == groupName
                ? _value.groupName
                : groupName // ignore: cast_nullable_to_non_nullable
                      as String,
            faceUrl: null == faceUrl
                ? _value.faceUrl
                : faceUrl // ignore: cast_nullable_to_non_nullable
                      as String,
            introduction: null == introduction
                ? _value.introduction
                : introduction // ignore: cast_nullable_to_non_nullable
                      as String,
            notification: null == notification
                ? _value.notification
                : notification // ignore: cast_nullable_to_non_nullable
                      as String,
            ownerUserId: null == ownerUserId
                ? _value.ownerUserId
                : ownerUserId // ignore: cast_nullable_to_non_nullable
                      as String,
            memberCount: null == memberCount
                ? _value.memberCount
                : memberCount // ignore: cast_nullable_to_non_nullable
                      as int,
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
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
abstract class _$$GroupImplCopyWith<$Res> implements $GroupCopyWith<$Res> {
  factory _$$GroupImplCopyWith(
    _$GroupImpl value,
    $Res Function(_$GroupImpl) then,
  ) = __$$GroupImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String groupId,
    String groupName,
    String faceUrl,
    String introduction,
    String notification,
    String ownerUserId,
    int memberCount,
    int status,
    DateTime? createdTime,
  });
}

/// @nodoc
class __$$GroupImplCopyWithImpl<$Res>
    extends _$GroupCopyWithImpl<$Res, _$GroupImpl>
    implements _$$GroupImplCopyWith<$Res> {
  __$$GroupImplCopyWithImpl(
    _$GroupImpl _value,
    $Res Function(_$GroupImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Group
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? groupId = null,
    Object? groupName = null,
    Object? faceUrl = null,
    Object? introduction = null,
    Object? notification = null,
    Object? ownerUserId = null,
    Object? memberCount = null,
    Object? status = null,
    Object? createdTime = freezed,
  }) {
    return _then(
      _$GroupImpl(
        groupId: null == groupId
            ? _value.groupId
            : groupId // ignore: cast_nullable_to_non_nullable
                  as String,
        groupName: null == groupName
            ? _value.groupName
            : groupName // ignore: cast_nullable_to_non_nullable
                  as String,
        faceUrl: null == faceUrl
            ? _value.faceUrl
            : faceUrl // ignore: cast_nullable_to_non_nullable
                  as String,
        introduction: null == introduction
            ? _value.introduction
            : introduction // ignore: cast_nullable_to_non_nullable
                  as String,
        notification: null == notification
            ? _value.notification
            : notification // ignore: cast_nullable_to_non_nullable
                  as String,
        ownerUserId: null == ownerUserId
            ? _value.ownerUserId
            : ownerUserId // ignore: cast_nullable_to_non_nullable
                  as String,
        memberCount: null == memberCount
            ? _value.memberCount
            : memberCount // ignore: cast_nullable_to_non_nullable
                  as int,
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
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

class _$GroupImpl implements _Group {
  const _$GroupImpl({
    required this.groupId,
    required this.groupName,
    required this.faceUrl,
    required this.introduction,
    required this.notification,
    required this.ownerUserId,
    required this.memberCount,
    required this.status,
    this.createdTime,
  });

  @override
  final String groupId;
  @override
  final String groupName;
  @override
  final String faceUrl;
  @override
  final String introduction;
  @override
  final String notification;
  @override
  final String ownerUserId;
  @override
  final int memberCount;
  @override
  final int status;
  @override
  final DateTime? createdTime;

  @override
  String toString() {
    return 'Group(groupId: $groupId, groupName: $groupName, faceUrl: $faceUrl, introduction: $introduction, notification: $notification, ownerUserId: $ownerUserId, memberCount: $memberCount, status: $status, createdTime: $createdTime)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$GroupImpl &&
            (identical(other.groupId, groupId) || other.groupId == groupId) &&
            (identical(other.groupName, groupName) ||
                other.groupName == groupName) &&
            (identical(other.faceUrl, faceUrl) || other.faceUrl == faceUrl) &&
            (identical(other.introduction, introduction) ||
                other.introduction == introduction) &&
            (identical(other.notification, notification) ||
                other.notification == notification) &&
            (identical(other.ownerUserId, ownerUserId) ||
                other.ownerUserId == ownerUserId) &&
            (identical(other.memberCount, memberCount) ||
                other.memberCount == memberCount) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.createdTime, createdTime) ||
                other.createdTime == createdTime));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    groupId,
    groupName,
    faceUrl,
    introduction,
    notification,
    ownerUserId,
    memberCount,
    status,
    createdTime,
  );

  /// Create a copy of Group
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$GroupImplCopyWith<_$GroupImpl> get copyWith =>
      __$$GroupImplCopyWithImpl<_$GroupImpl>(this, _$identity);
}

abstract class _Group implements Group {
  const factory _Group({
    required final String groupId,
    required final String groupName,
    required final String faceUrl,
    required final String introduction,
    required final String notification,
    required final String ownerUserId,
    required final int memberCount,
    required final int status,
    final DateTime? createdTime,
  }) = _$GroupImpl;

  @override
  String get groupId;
  @override
  String get groupName;
  @override
  String get faceUrl;
  @override
  String get introduction;
  @override
  String get notification;
  @override
  String get ownerUserId;
  @override
  int get memberCount;
  @override
  int get status;
  @override
  DateTime? get createdTime;

  /// Create a copy of Group
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$GroupImplCopyWith<_$GroupImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
