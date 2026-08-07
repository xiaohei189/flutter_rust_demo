// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'user.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$UserEvent {
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(UserInfo user) userInfoUpdated,
    required TResult Function(String userId, int status, Int32List platformIds)
    userStatusChanged,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(UserInfo user)? userInfoUpdated,
    TResult? Function(String userId, int status, Int32List platformIds)?
    userStatusChanged,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(UserInfo user)? userInfoUpdated,
    TResult Function(String userId, int status, Int32List platformIds)?
    userStatusChanged,
    required TResult orElse(),
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(UserEvent_UserInfoUpdated value) userInfoUpdated,
    required TResult Function(UserEvent_UserStatusChanged value)
    userStatusChanged,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(UserEvent_UserInfoUpdated value)? userInfoUpdated,
    TResult? Function(UserEvent_UserStatusChanged value)? userStatusChanged,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(UserEvent_UserInfoUpdated value)? userInfoUpdated,
    TResult Function(UserEvent_UserStatusChanged value)? userStatusChanged,
    required TResult orElse(),
  }) => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $UserEventCopyWith<$Res> {
  factory $UserEventCopyWith(UserEvent value, $Res Function(UserEvent) then) =
      _$UserEventCopyWithImpl<$Res, UserEvent>;
}

/// @nodoc
class _$UserEventCopyWithImpl<$Res, $Val extends UserEvent>
    implements $UserEventCopyWith<$Res> {
  _$UserEventCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of UserEvent
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc
abstract class _$$UserEvent_UserInfoUpdatedImplCopyWith<$Res> {
  factory _$$UserEvent_UserInfoUpdatedImplCopyWith(
    _$UserEvent_UserInfoUpdatedImpl value,
    $Res Function(_$UserEvent_UserInfoUpdatedImpl) then,
  ) = __$$UserEvent_UserInfoUpdatedImplCopyWithImpl<$Res>;
  @useResult
  $Res call({UserInfo user});
}

/// @nodoc
class __$$UserEvent_UserInfoUpdatedImplCopyWithImpl<$Res>
    extends _$UserEventCopyWithImpl<$Res, _$UserEvent_UserInfoUpdatedImpl>
    implements _$$UserEvent_UserInfoUpdatedImplCopyWith<$Res> {
  __$$UserEvent_UserInfoUpdatedImplCopyWithImpl(
    _$UserEvent_UserInfoUpdatedImpl _value,
    $Res Function(_$UserEvent_UserInfoUpdatedImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of UserEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? user = null}) {
    return _then(
      _$UserEvent_UserInfoUpdatedImpl(
        user: null == user
            ? _value.user
            : user // ignore: cast_nullable_to_non_nullable
                  as UserInfo,
      ),
    );
  }
}

/// @nodoc

class _$UserEvent_UserInfoUpdatedImpl extends UserEvent_UserInfoUpdated {
  const _$UserEvent_UserInfoUpdatedImpl({required this.user}) : super._();

  @override
  final UserInfo user;

  @override
  String toString() {
    return 'UserEvent.userInfoUpdated(user: $user)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$UserEvent_UserInfoUpdatedImpl &&
            (identical(other.user, user) || other.user == user));
  }

  @override
  int get hashCode => Object.hash(runtimeType, user);

  /// Create a copy of UserEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$UserEvent_UserInfoUpdatedImplCopyWith<_$UserEvent_UserInfoUpdatedImpl>
  get copyWith =>
      __$$UserEvent_UserInfoUpdatedImplCopyWithImpl<
        _$UserEvent_UserInfoUpdatedImpl
      >(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(UserInfo user) userInfoUpdated,
    required TResult Function(String userId, int status, Int32List platformIds)
    userStatusChanged,
  }) {
    return userInfoUpdated(user);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(UserInfo user)? userInfoUpdated,
    TResult? Function(String userId, int status, Int32List platformIds)?
    userStatusChanged,
  }) {
    return userInfoUpdated?.call(user);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(UserInfo user)? userInfoUpdated,
    TResult Function(String userId, int status, Int32List platformIds)?
    userStatusChanged,
    required TResult orElse(),
  }) {
    if (userInfoUpdated != null) {
      return userInfoUpdated(user);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(UserEvent_UserInfoUpdated value) userInfoUpdated,
    required TResult Function(UserEvent_UserStatusChanged value)
    userStatusChanged,
  }) {
    return userInfoUpdated(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(UserEvent_UserInfoUpdated value)? userInfoUpdated,
    TResult? Function(UserEvent_UserStatusChanged value)? userStatusChanged,
  }) {
    return userInfoUpdated?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(UserEvent_UserInfoUpdated value)? userInfoUpdated,
    TResult Function(UserEvent_UserStatusChanged value)? userStatusChanged,
    required TResult orElse(),
  }) {
    if (userInfoUpdated != null) {
      return userInfoUpdated(this);
    }
    return orElse();
  }
}

abstract class UserEvent_UserInfoUpdated extends UserEvent {
  const factory UserEvent_UserInfoUpdated({required final UserInfo user}) =
      _$UserEvent_UserInfoUpdatedImpl;
  const UserEvent_UserInfoUpdated._() : super._();

  UserInfo get user;

  /// Create a copy of UserEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$UserEvent_UserInfoUpdatedImplCopyWith<_$UserEvent_UserInfoUpdatedImpl>
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$UserEvent_UserStatusChangedImplCopyWith<$Res> {
  factory _$$UserEvent_UserStatusChangedImplCopyWith(
    _$UserEvent_UserStatusChangedImpl value,
    $Res Function(_$UserEvent_UserStatusChangedImpl) then,
  ) = __$$UserEvent_UserStatusChangedImplCopyWithImpl<$Res>;
  @useResult
  $Res call({String userId, int status, Int32List platformIds});
}

/// @nodoc
class __$$UserEvent_UserStatusChangedImplCopyWithImpl<$Res>
    extends _$UserEventCopyWithImpl<$Res, _$UserEvent_UserStatusChangedImpl>
    implements _$$UserEvent_UserStatusChangedImplCopyWith<$Res> {
  __$$UserEvent_UserStatusChangedImplCopyWithImpl(
    _$UserEvent_UserStatusChangedImpl _value,
    $Res Function(_$UserEvent_UserStatusChangedImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of UserEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? userId = null,
    Object? status = null,
    Object? platformIds = null,
  }) {
    return _then(
      _$UserEvent_UserStatusChangedImpl(
        userId: null == userId
            ? _value.userId
            : userId // ignore: cast_nullable_to_non_nullable
                  as String,
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as int,
        platformIds: null == platformIds
            ? _value.platformIds
            : platformIds // ignore: cast_nullable_to_non_nullable
                  as Int32List,
      ),
    );
  }
}

/// @nodoc

class _$UserEvent_UserStatusChangedImpl extends UserEvent_UserStatusChanged {
  const _$UserEvent_UserStatusChangedImpl({
    required this.userId,
    required this.status,
    required this.platformIds,
  }) : super._();

  @override
  final String userId;
  @override
  final int status;
  @override
  final Int32List platformIds;

  @override
  String toString() {
    return 'UserEvent.userStatusChanged(userId: $userId, status: $status, platformIds: $platformIds)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$UserEvent_UserStatusChangedImpl &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.status, status) || other.status == status) &&
            const DeepCollectionEquality().equals(
              other.platformIds,
              platformIds,
            ));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    userId,
    status,
    const DeepCollectionEquality().hash(platformIds),
  );

  /// Create a copy of UserEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$UserEvent_UserStatusChangedImplCopyWith<_$UserEvent_UserStatusChangedImpl>
  get copyWith =>
      __$$UserEvent_UserStatusChangedImplCopyWithImpl<
        _$UserEvent_UserStatusChangedImpl
      >(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(UserInfo user) userInfoUpdated,
    required TResult Function(String userId, int status, Int32List platformIds)
    userStatusChanged,
  }) {
    return userStatusChanged(userId, status, platformIds);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(UserInfo user)? userInfoUpdated,
    TResult? Function(String userId, int status, Int32List platformIds)?
    userStatusChanged,
  }) {
    return userStatusChanged?.call(userId, status, platformIds);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(UserInfo user)? userInfoUpdated,
    TResult Function(String userId, int status, Int32List platformIds)?
    userStatusChanged,
    required TResult orElse(),
  }) {
    if (userStatusChanged != null) {
      return userStatusChanged(userId, status, platformIds);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(UserEvent_UserInfoUpdated value) userInfoUpdated,
    required TResult Function(UserEvent_UserStatusChanged value)
    userStatusChanged,
  }) {
    return userStatusChanged(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(UserEvent_UserInfoUpdated value)? userInfoUpdated,
    TResult? Function(UserEvent_UserStatusChanged value)? userStatusChanged,
  }) {
    return userStatusChanged?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(UserEvent_UserInfoUpdated value)? userInfoUpdated,
    TResult Function(UserEvent_UserStatusChanged value)? userStatusChanged,
    required TResult orElse(),
  }) {
    if (userStatusChanged != null) {
      return userStatusChanged(this);
    }
    return orElse();
  }
}

abstract class UserEvent_UserStatusChanged extends UserEvent {
  const factory UserEvent_UserStatusChanged({
    required final String userId,
    required final int status,
    required final Int32List platformIds,
  }) = _$UserEvent_UserStatusChangedImpl;
  const UserEvent_UserStatusChanged._() : super._();

  String get userId;
  int get status;
  Int32List get platformIds;

  /// Create a copy of UserEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$UserEvent_UserStatusChangedImplCopyWith<_$UserEvent_UserStatusChangedImpl>
  get copyWith => throw _privateConstructorUsedError;
}
