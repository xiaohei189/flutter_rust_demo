// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'connection.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$ConnectionEvent {
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() connecting,
    required TResult Function() connected,
    required TResult Function(String field0) disconnected,
    required TResult Function(String field0) connectFailed,
    required TResult Function(String field0) kickedOffline,
    required TResult Function() tokenExpired,
    required TResult Function(int attempt, int maxAttempts) reconnecting,
    required TResult Function(String field0) loginSuccess,
    required TResult Function() logout,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? connecting,
    TResult? Function()? connected,
    TResult? Function(String field0)? disconnected,
    TResult? Function(String field0)? connectFailed,
    TResult? Function(String field0)? kickedOffline,
    TResult? Function()? tokenExpired,
    TResult? Function(int attempt, int maxAttempts)? reconnecting,
    TResult? Function(String field0)? loginSuccess,
    TResult? Function()? logout,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? connecting,
    TResult Function()? connected,
    TResult Function(String field0)? disconnected,
    TResult Function(String field0)? connectFailed,
    TResult Function(String field0)? kickedOffline,
    TResult Function()? tokenExpired,
    TResult Function(int attempt, int maxAttempts)? reconnecting,
    TResult Function(String field0)? loginSuccess,
    TResult Function()? logout,
    required TResult orElse(),
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(ConnectionEvent_Connecting value) connecting,
    required TResult Function(ConnectionEvent_Connected value) connected,
    required TResult Function(ConnectionEvent_Disconnected value) disconnected,
    required TResult Function(ConnectionEvent_ConnectFailed value)
    connectFailed,
    required TResult Function(ConnectionEvent_KickedOffline value)
    kickedOffline,
    required TResult Function(ConnectionEvent_TokenExpired value) tokenExpired,
    required TResult Function(ConnectionEvent_Reconnecting value) reconnecting,
    required TResult Function(ConnectionEvent_LoginSuccess value) loginSuccess,
    required TResult Function(ConnectionEvent_Logout value) logout,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(ConnectionEvent_Connecting value)? connecting,
    TResult? Function(ConnectionEvent_Connected value)? connected,
    TResult? Function(ConnectionEvent_Disconnected value)? disconnected,
    TResult? Function(ConnectionEvent_ConnectFailed value)? connectFailed,
    TResult? Function(ConnectionEvent_KickedOffline value)? kickedOffline,
    TResult? Function(ConnectionEvent_TokenExpired value)? tokenExpired,
    TResult? Function(ConnectionEvent_Reconnecting value)? reconnecting,
    TResult? Function(ConnectionEvent_LoginSuccess value)? loginSuccess,
    TResult? Function(ConnectionEvent_Logout value)? logout,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(ConnectionEvent_Connecting value)? connecting,
    TResult Function(ConnectionEvent_Connected value)? connected,
    TResult Function(ConnectionEvent_Disconnected value)? disconnected,
    TResult Function(ConnectionEvent_ConnectFailed value)? connectFailed,
    TResult Function(ConnectionEvent_KickedOffline value)? kickedOffline,
    TResult Function(ConnectionEvent_TokenExpired value)? tokenExpired,
    TResult Function(ConnectionEvent_Reconnecting value)? reconnecting,
    TResult Function(ConnectionEvent_LoginSuccess value)? loginSuccess,
    TResult Function(ConnectionEvent_Logout value)? logout,
    required TResult orElse(),
  }) => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ConnectionEventCopyWith<$Res> {
  factory $ConnectionEventCopyWith(
    ConnectionEvent value,
    $Res Function(ConnectionEvent) then,
  ) = _$ConnectionEventCopyWithImpl<$Res, ConnectionEvent>;
}

/// @nodoc
class _$ConnectionEventCopyWithImpl<$Res, $Val extends ConnectionEvent>
    implements $ConnectionEventCopyWith<$Res> {
  _$ConnectionEventCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ConnectionEvent
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc
abstract class _$$ConnectionEvent_ConnectingImplCopyWith<$Res> {
  factory _$$ConnectionEvent_ConnectingImplCopyWith(
    _$ConnectionEvent_ConnectingImpl value,
    $Res Function(_$ConnectionEvent_ConnectingImpl) then,
  ) = __$$ConnectionEvent_ConnectingImplCopyWithImpl<$Res>;
}

/// @nodoc
class __$$ConnectionEvent_ConnectingImplCopyWithImpl<$Res>
    extends
        _$ConnectionEventCopyWithImpl<$Res, _$ConnectionEvent_ConnectingImpl>
    implements _$$ConnectionEvent_ConnectingImplCopyWith<$Res> {
  __$$ConnectionEvent_ConnectingImplCopyWithImpl(
    _$ConnectionEvent_ConnectingImpl _value,
    $Res Function(_$ConnectionEvent_ConnectingImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ConnectionEvent
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc

class _$ConnectionEvent_ConnectingImpl extends ConnectionEvent_Connecting {
  const _$ConnectionEvent_ConnectingImpl() : super._();

  @override
  String toString() {
    return 'ConnectionEvent.connecting()';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ConnectionEvent_ConnectingImpl);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() connecting,
    required TResult Function() connected,
    required TResult Function(String field0) disconnected,
    required TResult Function(String field0) connectFailed,
    required TResult Function(String field0) kickedOffline,
    required TResult Function() tokenExpired,
    required TResult Function(int attempt, int maxAttempts) reconnecting,
    required TResult Function(String field0) loginSuccess,
    required TResult Function() logout,
  }) {
    return connecting();
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? connecting,
    TResult? Function()? connected,
    TResult? Function(String field0)? disconnected,
    TResult? Function(String field0)? connectFailed,
    TResult? Function(String field0)? kickedOffline,
    TResult? Function()? tokenExpired,
    TResult? Function(int attempt, int maxAttempts)? reconnecting,
    TResult? Function(String field0)? loginSuccess,
    TResult? Function()? logout,
  }) {
    return connecting?.call();
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? connecting,
    TResult Function()? connected,
    TResult Function(String field0)? disconnected,
    TResult Function(String field0)? connectFailed,
    TResult Function(String field0)? kickedOffline,
    TResult Function()? tokenExpired,
    TResult Function(int attempt, int maxAttempts)? reconnecting,
    TResult Function(String field0)? loginSuccess,
    TResult Function()? logout,
    required TResult orElse(),
  }) {
    if (connecting != null) {
      return connecting();
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(ConnectionEvent_Connecting value) connecting,
    required TResult Function(ConnectionEvent_Connected value) connected,
    required TResult Function(ConnectionEvent_Disconnected value) disconnected,
    required TResult Function(ConnectionEvent_ConnectFailed value)
    connectFailed,
    required TResult Function(ConnectionEvent_KickedOffline value)
    kickedOffline,
    required TResult Function(ConnectionEvent_TokenExpired value) tokenExpired,
    required TResult Function(ConnectionEvent_Reconnecting value) reconnecting,
    required TResult Function(ConnectionEvent_LoginSuccess value) loginSuccess,
    required TResult Function(ConnectionEvent_Logout value) logout,
  }) {
    return connecting(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(ConnectionEvent_Connecting value)? connecting,
    TResult? Function(ConnectionEvent_Connected value)? connected,
    TResult? Function(ConnectionEvent_Disconnected value)? disconnected,
    TResult? Function(ConnectionEvent_ConnectFailed value)? connectFailed,
    TResult? Function(ConnectionEvent_KickedOffline value)? kickedOffline,
    TResult? Function(ConnectionEvent_TokenExpired value)? tokenExpired,
    TResult? Function(ConnectionEvent_Reconnecting value)? reconnecting,
    TResult? Function(ConnectionEvent_LoginSuccess value)? loginSuccess,
    TResult? Function(ConnectionEvent_Logout value)? logout,
  }) {
    return connecting?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(ConnectionEvent_Connecting value)? connecting,
    TResult Function(ConnectionEvent_Connected value)? connected,
    TResult Function(ConnectionEvent_Disconnected value)? disconnected,
    TResult Function(ConnectionEvent_ConnectFailed value)? connectFailed,
    TResult Function(ConnectionEvent_KickedOffline value)? kickedOffline,
    TResult Function(ConnectionEvent_TokenExpired value)? tokenExpired,
    TResult Function(ConnectionEvent_Reconnecting value)? reconnecting,
    TResult Function(ConnectionEvent_LoginSuccess value)? loginSuccess,
    TResult Function(ConnectionEvent_Logout value)? logout,
    required TResult orElse(),
  }) {
    if (connecting != null) {
      return connecting(this);
    }
    return orElse();
  }
}

abstract class ConnectionEvent_Connecting extends ConnectionEvent {
  const factory ConnectionEvent_Connecting() = _$ConnectionEvent_ConnectingImpl;
  const ConnectionEvent_Connecting._() : super._();
}

/// @nodoc
abstract class _$$ConnectionEvent_ConnectedImplCopyWith<$Res> {
  factory _$$ConnectionEvent_ConnectedImplCopyWith(
    _$ConnectionEvent_ConnectedImpl value,
    $Res Function(_$ConnectionEvent_ConnectedImpl) then,
  ) = __$$ConnectionEvent_ConnectedImplCopyWithImpl<$Res>;
}

/// @nodoc
class __$$ConnectionEvent_ConnectedImplCopyWithImpl<$Res>
    extends _$ConnectionEventCopyWithImpl<$Res, _$ConnectionEvent_ConnectedImpl>
    implements _$$ConnectionEvent_ConnectedImplCopyWith<$Res> {
  __$$ConnectionEvent_ConnectedImplCopyWithImpl(
    _$ConnectionEvent_ConnectedImpl _value,
    $Res Function(_$ConnectionEvent_ConnectedImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ConnectionEvent
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc

class _$ConnectionEvent_ConnectedImpl extends ConnectionEvent_Connected {
  const _$ConnectionEvent_ConnectedImpl() : super._();

  @override
  String toString() {
    return 'ConnectionEvent.connected()';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ConnectionEvent_ConnectedImpl);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() connecting,
    required TResult Function() connected,
    required TResult Function(String field0) disconnected,
    required TResult Function(String field0) connectFailed,
    required TResult Function(String field0) kickedOffline,
    required TResult Function() tokenExpired,
    required TResult Function(int attempt, int maxAttempts) reconnecting,
    required TResult Function(String field0) loginSuccess,
    required TResult Function() logout,
  }) {
    return connected();
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? connecting,
    TResult? Function()? connected,
    TResult? Function(String field0)? disconnected,
    TResult? Function(String field0)? connectFailed,
    TResult? Function(String field0)? kickedOffline,
    TResult? Function()? tokenExpired,
    TResult? Function(int attempt, int maxAttempts)? reconnecting,
    TResult? Function(String field0)? loginSuccess,
    TResult? Function()? logout,
  }) {
    return connected?.call();
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? connecting,
    TResult Function()? connected,
    TResult Function(String field0)? disconnected,
    TResult Function(String field0)? connectFailed,
    TResult Function(String field0)? kickedOffline,
    TResult Function()? tokenExpired,
    TResult Function(int attempt, int maxAttempts)? reconnecting,
    TResult Function(String field0)? loginSuccess,
    TResult Function()? logout,
    required TResult orElse(),
  }) {
    if (connected != null) {
      return connected();
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(ConnectionEvent_Connecting value) connecting,
    required TResult Function(ConnectionEvent_Connected value) connected,
    required TResult Function(ConnectionEvent_Disconnected value) disconnected,
    required TResult Function(ConnectionEvent_ConnectFailed value)
    connectFailed,
    required TResult Function(ConnectionEvent_KickedOffline value)
    kickedOffline,
    required TResult Function(ConnectionEvent_TokenExpired value) tokenExpired,
    required TResult Function(ConnectionEvent_Reconnecting value) reconnecting,
    required TResult Function(ConnectionEvent_LoginSuccess value) loginSuccess,
    required TResult Function(ConnectionEvent_Logout value) logout,
  }) {
    return connected(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(ConnectionEvent_Connecting value)? connecting,
    TResult? Function(ConnectionEvent_Connected value)? connected,
    TResult? Function(ConnectionEvent_Disconnected value)? disconnected,
    TResult? Function(ConnectionEvent_ConnectFailed value)? connectFailed,
    TResult? Function(ConnectionEvent_KickedOffline value)? kickedOffline,
    TResult? Function(ConnectionEvent_TokenExpired value)? tokenExpired,
    TResult? Function(ConnectionEvent_Reconnecting value)? reconnecting,
    TResult? Function(ConnectionEvent_LoginSuccess value)? loginSuccess,
    TResult? Function(ConnectionEvent_Logout value)? logout,
  }) {
    return connected?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(ConnectionEvent_Connecting value)? connecting,
    TResult Function(ConnectionEvent_Connected value)? connected,
    TResult Function(ConnectionEvent_Disconnected value)? disconnected,
    TResult Function(ConnectionEvent_ConnectFailed value)? connectFailed,
    TResult Function(ConnectionEvent_KickedOffline value)? kickedOffline,
    TResult Function(ConnectionEvent_TokenExpired value)? tokenExpired,
    TResult Function(ConnectionEvent_Reconnecting value)? reconnecting,
    TResult Function(ConnectionEvent_LoginSuccess value)? loginSuccess,
    TResult Function(ConnectionEvent_Logout value)? logout,
    required TResult orElse(),
  }) {
    if (connected != null) {
      return connected(this);
    }
    return orElse();
  }
}

abstract class ConnectionEvent_Connected extends ConnectionEvent {
  const factory ConnectionEvent_Connected() = _$ConnectionEvent_ConnectedImpl;
  const ConnectionEvent_Connected._() : super._();
}

/// @nodoc
abstract class _$$ConnectionEvent_DisconnectedImplCopyWith<$Res> {
  factory _$$ConnectionEvent_DisconnectedImplCopyWith(
    _$ConnectionEvent_DisconnectedImpl value,
    $Res Function(_$ConnectionEvent_DisconnectedImpl) then,
  ) = __$$ConnectionEvent_DisconnectedImplCopyWithImpl<$Res>;
  @useResult
  $Res call({String field0});
}

/// @nodoc
class __$$ConnectionEvent_DisconnectedImplCopyWithImpl<$Res>
    extends
        _$ConnectionEventCopyWithImpl<$Res, _$ConnectionEvent_DisconnectedImpl>
    implements _$$ConnectionEvent_DisconnectedImplCopyWith<$Res> {
  __$$ConnectionEvent_DisconnectedImplCopyWithImpl(
    _$ConnectionEvent_DisconnectedImpl _value,
    $Res Function(_$ConnectionEvent_DisconnectedImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ConnectionEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? field0 = null}) {
    return _then(
      _$ConnectionEvent_DisconnectedImpl(
        null == field0
            ? _value.field0
            : field0 // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc

class _$ConnectionEvent_DisconnectedImpl extends ConnectionEvent_Disconnected {
  const _$ConnectionEvent_DisconnectedImpl(this.field0) : super._();

  @override
  final String field0;

  @override
  String toString() {
    return 'ConnectionEvent.disconnected(field0: $field0)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ConnectionEvent_DisconnectedImpl &&
            (identical(other.field0, field0) || other.field0 == field0));
  }

  @override
  int get hashCode => Object.hash(runtimeType, field0);

  /// Create a copy of ConnectionEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ConnectionEvent_DisconnectedImplCopyWith<
    _$ConnectionEvent_DisconnectedImpl
  >
  get copyWith =>
      __$$ConnectionEvent_DisconnectedImplCopyWithImpl<
        _$ConnectionEvent_DisconnectedImpl
      >(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() connecting,
    required TResult Function() connected,
    required TResult Function(String field0) disconnected,
    required TResult Function(String field0) connectFailed,
    required TResult Function(String field0) kickedOffline,
    required TResult Function() tokenExpired,
    required TResult Function(int attempt, int maxAttempts) reconnecting,
    required TResult Function(String field0) loginSuccess,
    required TResult Function() logout,
  }) {
    return disconnected(field0);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? connecting,
    TResult? Function()? connected,
    TResult? Function(String field0)? disconnected,
    TResult? Function(String field0)? connectFailed,
    TResult? Function(String field0)? kickedOffline,
    TResult? Function()? tokenExpired,
    TResult? Function(int attempt, int maxAttempts)? reconnecting,
    TResult? Function(String field0)? loginSuccess,
    TResult? Function()? logout,
  }) {
    return disconnected?.call(field0);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? connecting,
    TResult Function()? connected,
    TResult Function(String field0)? disconnected,
    TResult Function(String field0)? connectFailed,
    TResult Function(String field0)? kickedOffline,
    TResult Function()? tokenExpired,
    TResult Function(int attempt, int maxAttempts)? reconnecting,
    TResult Function(String field0)? loginSuccess,
    TResult Function()? logout,
    required TResult orElse(),
  }) {
    if (disconnected != null) {
      return disconnected(field0);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(ConnectionEvent_Connecting value) connecting,
    required TResult Function(ConnectionEvent_Connected value) connected,
    required TResult Function(ConnectionEvent_Disconnected value) disconnected,
    required TResult Function(ConnectionEvent_ConnectFailed value)
    connectFailed,
    required TResult Function(ConnectionEvent_KickedOffline value)
    kickedOffline,
    required TResult Function(ConnectionEvent_TokenExpired value) tokenExpired,
    required TResult Function(ConnectionEvent_Reconnecting value) reconnecting,
    required TResult Function(ConnectionEvent_LoginSuccess value) loginSuccess,
    required TResult Function(ConnectionEvent_Logout value) logout,
  }) {
    return disconnected(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(ConnectionEvent_Connecting value)? connecting,
    TResult? Function(ConnectionEvent_Connected value)? connected,
    TResult? Function(ConnectionEvent_Disconnected value)? disconnected,
    TResult? Function(ConnectionEvent_ConnectFailed value)? connectFailed,
    TResult? Function(ConnectionEvent_KickedOffline value)? kickedOffline,
    TResult? Function(ConnectionEvent_TokenExpired value)? tokenExpired,
    TResult? Function(ConnectionEvent_Reconnecting value)? reconnecting,
    TResult? Function(ConnectionEvent_LoginSuccess value)? loginSuccess,
    TResult? Function(ConnectionEvent_Logout value)? logout,
  }) {
    return disconnected?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(ConnectionEvent_Connecting value)? connecting,
    TResult Function(ConnectionEvent_Connected value)? connected,
    TResult Function(ConnectionEvent_Disconnected value)? disconnected,
    TResult Function(ConnectionEvent_ConnectFailed value)? connectFailed,
    TResult Function(ConnectionEvent_KickedOffline value)? kickedOffline,
    TResult Function(ConnectionEvent_TokenExpired value)? tokenExpired,
    TResult Function(ConnectionEvent_Reconnecting value)? reconnecting,
    TResult Function(ConnectionEvent_LoginSuccess value)? loginSuccess,
    TResult Function(ConnectionEvent_Logout value)? logout,
    required TResult orElse(),
  }) {
    if (disconnected != null) {
      return disconnected(this);
    }
    return orElse();
  }
}

abstract class ConnectionEvent_Disconnected extends ConnectionEvent {
  const factory ConnectionEvent_Disconnected(final String field0) =
      _$ConnectionEvent_DisconnectedImpl;
  const ConnectionEvent_Disconnected._() : super._();

  String get field0;

  /// Create a copy of ConnectionEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ConnectionEvent_DisconnectedImplCopyWith<
    _$ConnectionEvent_DisconnectedImpl
  >
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$ConnectionEvent_ConnectFailedImplCopyWith<$Res> {
  factory _$$ConnectionEvent_ConnectFailedImplCopyWith(
    _$ConnectionEvent_ConnectFailedImpl value,
    $Res Function(_$ConnectionEvent_ConnectFailedImpl) then,
  ) = __$$ConnectionEvent_ConnectFailedImplCopyWithImpl<$Res>;
  @useResult
  $Res call({String field0});
}

/// @nodoc
class __$$ConnectionEvent_ConnectFailedImplCopyWithImpl<$Res>
    extends
        _$ConnectionEventCopyWithImpl<$Res, _$ConnectionEvent_ConnectFailedImpl>
    implements _$$ConnectionEvent_ConnectFailedImplCopyWith<$Res> {
  __$$ConnectionEvent_ConnectFailedImplCopyWithImpl(
    _$ConnectionEvent_ConnectFailedImpl _value,
    $Res Function(_$ConnectionEvent_ConnectFailedImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ConnectionEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? field0 = null}) {
    return _then(
      _$ConnectionEvent_ConnectFailedImpl(
        null == field0
            ? _value.field0
            : field0 // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc

class _$ConnectionEvent_ConnectFailedImpl
    extends ConnectionEvent_ConnectFailed {
  const _$ConnectionEvent_ConnectFailedImpl(this.field0) : super._();

  @override
  final String field0;

  @override
  String toString() {
    return 'ConnectionEvent.connectFailed(field0: $field0)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ConnectionEvent_ConnectFailedImpl &&
            (identical(other.field0, field0) || other.field0 == field0));
  }

  @override
  int get hashCode => Object.hash(runtimeType, field0);

  /// Create a copy of ConnectionEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ConnectionEvent_ConnectFailedImplCopyWith<
    _$ConnectionEvent_ConnectFailedImpl
  >
  get copyWith =>
      __$$ConnectionEvent_ConnectFailedImplCopyWithImpl<
        _$ConnectionEvent_ConnectFailedImpl
      >(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() connecting,
    required TResult Function() connected,
    required TResult Function(String field0) disconnected,
    required TResult Function(String field0) connectFailed,
    required TResult Function(String field0) kickedOffline,
    required TResult Function() tokenExpired,
    required TResult Function(int attempt, int maxAttempts) reconnecting,
    required TResult Function(String field0) loginSuccess,
    required TResult Function() logout,
  }) {
    return connectFailed(field0);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? connecting,
    TResult? Function()? connected,
    TResult? Function(String field0)? disconnected,
    TResult? Function(String field0)? connectFailed,
    TResult? Function(String field0)? kickedOffline,
    TResult? Function()? tokenExpired,
    TResult? Function(int attempt, int maxAttempts)? reconnecting,
    TResult? Function(String field0)? loginSuccess,
    TResult? Function()? logout,
  }) {
    return connectFailed?.call(field0);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? connecting,
    TResult Function()? connected,
    TResult Function(String field0)? disconnected,
    TResult Function(String field0)? connectFailed,
    TResult Function(String field0)? kickedOffline,
    TResult Function()? tokenExpired,
    TResult Function(int attempt, int maxAttempts)? reconnecting,
    TResult Function(String field0)? loginSuccess,
    TResult Function()? logout,
    required TResult orElse(),
  }) {
    if (connectFailed != null) {
      return connectFailed(field0);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(ConnectionEvent_Connecting value) connecting,
    required TResult Function(ConnectionEvent_Connected value) connected,
    required TResult Function(ConnectionEvent_Disconnected value) disconnected,
    required TResult Function(ConnectionEvent_ConnectFailed value)
    connectFailed,
    required TResult Function(ConnectionEvent_KickedOffline value)
    kickedOffline,
    required TResult Function(ConnectionEvent_TokenExpired value) tokenExpired,
    required TResult Function(ConnectionEvent_Reconnecting value) reconnecting,
    required TResult Function(ConnectionEvent_LoginSuccess value) loginSuccess,
    required TResult Function(ConnectionEvent_Logout value) logout,
  }) {
    return connectFailed(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(ConnectionEvent_Connecting value)? connecting,
    TResult? Function(ConnectionEvent_Connected value)? connected,
    TResult? Function(ConnectionEvent_Disconnected value)? disconnected,
    TResult? Function(ConnectionEvent_ConnectFailed value)? connectFailed,
    TResult? Function(ConnectionEvent_KickedOffline value)? kickedOffline,
    TResult? Function(ConnectionEvent_TokenExpired value)? tokenExpired,
    TResult? Function(ConnectionEvent_Reconnecting value)? reconnecting,
    TResult? Function(ConnectionEvent_LoginSuccess value)? loginSuccess,
    TResult? Function(ConnectionEvent_Logout value)? logout,
  }) {
    return connectFailed?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(ConnectionEvent_Connecting value)? connecting,
    TResult Function(ConnectionEvent_Connected value)? connected,
    TResult Function(ConnectionEvent_Disconnected value)? disconnected,
    TResult Function(ConnectionEvent_ConnectFailed value)? connectFailed,
    TResult Function(ConnectionEvent_KickedOffline value)? kickedOffline,
    TResult Function(ConnectionEvent_TokenExpired value)? tokenExpired,
    TResult Function(ConnectionEvent_Reconnecting value)? reconnecting,
    TResult Function(ConnectionEvent_LoginSuccess value)? loginSuccess,
    TResult Function(ConnectionEvent_Logout value)? logout,
    required TResult orElse(),
  }) {
    if (connectFailed != null) {
      return connectFailed(this);
    }
    return orElse();
  }
}

abstract class ConnectionEvent_ConnectFailed extends ConnectionEvent {
  const factory ConnectionEvent_ConnectFailed(final String field0) =
      _$ConnectionEvent_ConnectFailedImpl;
  const ConnectionEvent_ConnectFailed._() : super._();

  String get field0;

  /// Create a copy of ConnectionEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ConnectionEvent_ConnectFailedImplCopyWith<
    _$ConnectionEvent_ConnectFailedImpl
  >
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$ConnectionEvent_KickedOfflineImplCopyWith<$Res> {
  factory _$$ConnectionEvent_KickedOfflineImplCopyWith(
    _$ConnectionEvent_KickedOfflineImpl value,
    $Res Function(_$ConnectionEvent_KickedOfflineImpl) then,
  ) = __$$ConnectionEvent_KickedOfflineImplCopyWithImpl<$Res>;
  @useResult
  $Res call({String field0});
}

/// @nodoc
class __$$ConnectionEvent_KickedOfflineImplCopyWithImpl<$Res>
    extends
        _$ConnectionEventCopyWithImpl<$Res, _$ConnectionEvent_KickedOfflineImpl>
    implements _$$ConnectionEvent_KickedOfflineImplCopyWith<$Res> {
  __$$ConnectionEvent_KickedOfflineImplCopyWithImpl(
    _$ConnectionEvent_KickedOfflineImpl _value,
    $Res Function(_$ConnectionEvent_KickedOfflineImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ConnectionEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? field0 = null}) {
    return _then(
      _$ConnectionEvent_KickedOfflineImpl(
        null == field0
            ? _value.field0
            : field0 // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc

class _$ConnectionEvent_KickedOfflineImpl
    extends ConnectionEvent_KickedOffline {
  const _$ConnectionEvent_KickedOfflineImpl(this.field0) : super._();

  @override
  final String field0;

  @override
  String toString() {
    return 'ConnectionEvent.kickedOffline(field0: $field0)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ConnectionEvent_KickedOfflineImpl &&
            (identical(other.field0, field0) || other.field0 == field0));
  }

  @override
  int get hashCode => Object.hash(runtimeType, field0);

  /// Create a copy of ConnectionEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ConnectionEvent_KickedOfflineImplCopyWith<
    _$ConnectionEvent_KickedOfflineImpl
  >
  get copyWith =>
      __$$ConnectionEvent_KickedOfflineImplCopyWithImpl<
        _$ConnectionEvent_KickedOfflineImpl
      >(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() connecting,
    required TResult Function() connected,
    required TResult Function(String field0) disconnected,
    required TResult Function(String field0) connectFailed,
    required TResult Function(String field0) kickedOffline,
    required TResult Function() tokenExpired,
    required TResult Function(int attempt, int maxAttempts) reconnecting,
    required TResult Function(String field0) loginSuccess,
    required TResult Function() logout,
  }) {
    return kickedOffline(field0);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? connecting,
    TResult? Function()? connected,
    TResult? Function(String field0)? disconnected,
    TResult? Function(String field0)? connectFailed,
    TResult? Function(String field0)? kickedOffline,
    TResult? Function()? tokenExpired,
    TResult? Function(int attempt, int maxAttempts)? reconnecting,
    TResult? Function(String field0)? loginSuccess,
    TResult? Function()? logout,
  }) {
    return kickedOffline?.call(field0);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? connecting,
    TResult Function()? connected,
    TResult Function(String field0)? disconnected,
    TResult Function(String field0)? connectFailed,
    TResult Function(String field0)? kickedOffline,
    TResult Function()? tokenExpired,
    TResult Function(int attempt, int maxAttempts)? reconnecting,
    TResult Function(String field0)? loginSuccess,
    TResult Function()? logout,
    required TResult orElse(),
  }) {
    if (kickedOffline != null) {
      return kickedOffline(field0);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(ConnectionEvent_Connecting value) connecting,
    required TResult Function(ConnectionEvent_Connected value) connected,
    required TResult Function(ConnectionEvent_Disconnected value) disconnected,
    required TResult Function(ConnectionEvent_ConnectFailed value)
    connectFailed,
    required TResult Function(ConnectionEvent_KickedOffline value)
    kickedOffline,
    required TResult Function(ConnectionEvent_TokenExpired value) tokenExpired,
    required TResult Function(ConnectionEvent_Reconnecting value) reconnecting,
    required TResult Function(ConnectionEvent_LoginSuccess value) loginSuccess,
    required TResult Function(ConnectionEvent_Logout value) logout,
  }) {
    return kickedOffline(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(ConnectionEvent_Connecting value)? connecting,
    TResult? Function(ConnectionEvent_Connected value)? connected,
    TResult? Function(ConnectionEvent_Disconnected value)? disconnected,
    TResult? Function(ConnectionEvent_ConnectFailed value)? connectFailed,
    TResult? Function(ConnectionEvent_KickedOffline value)? kickedOffline,
    TResult? Function(ConnectionEvent_TokenExpired value)? tokenExpired,
    TResult? Function(ConnectionEvent_Reconnecting value)? reconnecting,
    TResult? Function(ConnectionEvent_LoginSuccess value)? loginSuccess,
    TResult? Function(ConnectionEvent_Logout value)? logout,
  }) {
    return kickedOffline?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(ConnectionEvent_Connecting value)? connecting,
    TResult Function(ConnectionEvent_Connected value)? connected,
    TResult Function(ConnectionEvent_Disconnected value)? disconnected,
    TResult Function(ConnectionEvent_ConnectFailed value)? connectFailed,
    TResult Function(ConnectionEvent_KickedOffline value)? kickedOffline,
    TResult Function(ConnectionEvent_TokenExpired value)? tokenExpired,
    TResult Function(ConnectionEvent_Reconnecting value)? reconnecting,
    TResult Function(ConnectionEvent_LoginSuccess value)? loginSuccess,
    TResult Function(ConnectionEvent_Logout value)? logout,
    required TResult orElse(),
  }) {
    if (kickedOffline != null) {
      return kickedOffline(this);
    }
    return orElse();
  }
}

abstract class ConnectionEvent_KickedOffline extends ConnectionEvent {
  const factory ConnectionEvent_KickedOffline(final String field0) =
      _$ConnectionEvent_KickedOfflineImpl;
  const ConnectionEvent_KickedOffline._() : super._();

  String get field0;

  /// Create a copy of ConnectionEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ConnectionEvent_KickedOfflineImplCopyWith<
    _$ConnectionEvent_KickedOfflineImpl
  >
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$ConnectionEvent_TokenExpiredImplCopyWith<$Res> {
  factory _$$ConnectionEvent_TokenExpiredImplCopyWith(
    _$ConnectionEvent_TokenExpiredImpl value,
    $Res Function(_$ConnectionEvent_TokenExpiredImpl) then,
  ) = __$$ConnectionEvent_TokenExpiredImplCopyWithImpl<$Res>;
}

/// @nodoc
class __$$ConnectionEvent_TokenExpiredImplCopyWithImpl<$Res>
    extends
        _$ConnectionEventCopyWithImpl<$Res, _$ConnectionEvent_TokenExpiredImpl>
    implements _$$ConnectionEvent_TokenExpiredImplCopyWith<$Res> {
  __$$ConnectionEvent_TokenExpiredImplCopyWithImpl(
    _$ConnectionEvent_TokenExpiredImpl _value,
    $Res Function(_$ConnectionEvent_TokenExpiredImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ConnectionEvent
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc

class _$ConnectionEvent_TokenExpiredImpl extends ConnectionEvent_TokenExpired {
  const _$ConnectionEvent_TokenExpiredImpl() : super._();

  @override
  String toString() {
    return 'ConnectionEvent.tokenExpired()';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ConnectionEvent_TokenExpiredImpl);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() connecting,
    required TResult Function() connected,
    required TResult Function(String field0) disconnected,
    required TResult Function(String field0) connectFailed,
    required TResult Function(String field0) kickedOffline,
    required TResult Function() tokenExpired,
    required TResult Function(int attempt, int maxAttempts) reconnecting,
    required TResult Function(String field0) loginSuccess,
    required TResult Function() logout,
  }) {
    return tokenExpired();
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? connecting,
    TResult? Function()? connected,
    TResult? Function(String field0)? disconnected,
    TResult? Function(String field0)? connectFailed,
    TResult? Function(String field0)? kickedOffline,
    TResult? Function()? tokenExpired,
    TResult? Function(int attempt, int maxAttempts)? reconnecting,
    TResult? Function(String field0)? loginSuccess,
    TResult? Function()? logout,
  }) {
    return tokenExpired?.call();
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? connecting,
    TResult Function()? connected,
    TResult Function(String field0)? disconnected,
    TResult Function(String field0)? connectFailed,
    TResult Function(String field0)? kickedOffline,
    TResult Function()? tokenExpired,
    TResult Function(int attempt, int maxAttempts)? reconnecting,
    TResult Function(String field0)? loginSuccess,
    TResult Function()? logout,
    required TResult orElse(),
  }) {
    if (tokenExpired != null) {
      return tokenExpired();
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(ConnectionEvent_Connecting value) connecting,
    required TResult Function(ConnectionEvent_Connected value) connected,
    required TResult Function(ConnectionEvent_Disconnected value) disconnected,
    required TResult Function(ConnectionEvent_ConnectFailed value)
    connectFailed,
    required TResult Function(ConnectionEvent_KickedOffline value)
    kickedOffline,
    required TResult Function(ConnectionEvent_TokenExpired value) tokenExpired,
    required TResult Function(ConnectionEvent_Reconnecting value) reconnecting,
    required TResult Function(ConnectionEvent_LoginSuccess value) loginSuccess,
    required TResult Function(ConnectionEvent_Logout value) logout,
  }) {
    return tokenExpired(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(ConnectionEvent_Connecting value)? connecting,
    TResult? Function(ConnectionEvent_Connected value)? connected,
    TResult? Function(ConnectionEvent_Disconnected value)? disconnected,
    TResult? Function(ConnectionEvent_ConnectFailed value)? connectFailed,
    TResult? Function(ConnectionEvent_KickedOffline value)? kickedOffline,
    TResult? Function(ConnectionEvent_TokenExpired value)? tokenExpired,
    TResult? Function(ConnectionEvent_Reconnecting value)? reconnecting,
    TResult? Function(ConnectionEvent_LoginSuccess value)? loginSuccess,
    TResult? Function(ConnectionEvent_Logout value)? logout,
  }) {
    return tokenExpired?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(ConnectionEvent_Connecting value)? connecting,
    TResult Function(ConnectionEvent_Connected value)? connected,
    TResult Function(ConnectionEvent_Disconnected value)? disconnected,
    TResult Function(ConnectionEvent_ConnectFailed value)? connectFailed,
    TResult Function(ConnectionEvent_KickedOffline value)? kickedOffline,
    TResult Function(ConnectionEvent_TokenExpired value)? tokenExpired,
    TResult Function(ConnectionEvent_Reconnecting value)? reconnecting,
    TResult Function(ConnectionEvent_LoginSuccess value)? loginSuccess,
    TResult Function(ConnectionEvent_Logout value)? logout,
    required TResult orElse(),
  }) {
    if (tokenExpired != null) {
      return tokenExpired(this);
    }
    return orElse();
  }
}

abstract class ConnectionEvent_TokenExpired extends ConnectionEvent {
  const factory ConnectionEvent_TokenExpired() =
      _$ConnectionEvent_TokenExpiredImpl;
  const ConnectionEvent_TokenExpired._() : super._();
}

/// @nodoc
abstract class _$$ConnectionEvent_ReconnectingImplCopyWith<$Res> {
  factory _$$ConnectionEvent_ReconnectingImplCopyWith(
    _$ConnectionEvent_ReconnectingImpl value,
    $Res Function(_$ConnectionEvent_ReconnectingImpl) then,
  ) = __$$ConnectionEvent_ReconnectingImplCopyWithImpl<$Res>;
  @useResult
  $Res call({int attempt, int maxAttempts});
}

/// @nodoc
class __$$ConnectionEvent_ReconnectingImplCopyWithImpl<$Res>
    extends
        _$ConnectionEventCopyWithImpl<$Res, _$ConnectionEvent_ReconnectingImpl>
    implements _$$ConnectionEvent_ReconnectingImplCopyWith<$Res> {
  __$$ConnectionEvent_ReconnectingImplCopyWithImpl(
    _$ConnectionEvent_ReconnectingImpl _value,
    $Res Function(_$ConnectionEvent_ReconnectingImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ConnectionEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? attempt = null, Object? maxAttempts = null}) {
    return _then(
      _$ConnectionEvent_ReconnectingImpl(
        attempt: null == attempt
            ? _value.attempt
            : attempt // ignore: cast_nullable_to_non_nullable
                  as int,
        maxAttempts: null == maxAttempts
            ? _value.maxAttempts
            : maxAttempts // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc

class _$ConnectionEvent_ReconnectingImpl extends ConnectionEvent_Reconnecting {
  const _$ConnectionEvent_ReconnectingImpl({
    required this.attempt,
    required this.maxAttempts,
  }) : super._();

  @override
  final int attempt;
  @override
  final int maxAttempts;

  @override
  String toString() {
    return 'ConnectionEvent.reconnecting(attempt: $attempt, maxAttempts: $maxAttempts)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ConnectionEvent_ReconnectingImpl &&
            (identical(other.attempt, attempt) || other.attempt == attempt) &&
            (identical(other.maxAttempts, maxAttempts) ||
                other.maxAttempts == maxAttempts));
  }

  @override
  int get hashCode => Object.hash(runtimeType, attempt, maxAttempts);

  /// Create a copy of ConnectionEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ConnectionEvent_ReconnectingImplCopyWith<
    _$ConnectionEvent_ReconnectingImpl
  >
  get copyWith =>
      __$$ConnectionEvent_ReconnectingImplCopyWithImpl<
        _$ConnectionEvent_ReconnectingImpl
      >(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() connecting,
    required TResult Function() connected,
    required TResult Function(String field0) disconnected,
    required TResult Function(String field0) connectFailed,
    required TResult Function(String field0) kickedOffline,
    required TResult Function() tokenExpired,
    required TResult Function(int attempt, int maxAttempts) reconnecting,
    required TResult Function(String field0) loginSuccess,
    required TResult Function() logout,
  }) {
    return reconnecting(attempt, maxAttempts);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? connecting,
    TResult? Function()? connected,
    TResult? Function(String field0)? disconnected,
    TResult? Function(String field0)? connectFailed,
    TResult? Function(String field0)? kickedOffline,
    TResult? Function()? tokenExpired,
    TResult? Function(int attempt, int maxAttempts)? reconnecting,
    TResult? Function(String field0)? loginSuccess,
    TResult? Function()? logout,
  }) {
    return reconnecting?.call(attempt, maxAttempts);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? connecting,
    TResult Function()? connected,
    TResult Function(String field0)? disconnected,
    TResult Function(String field0)? connectFailed,
    TResult Function(String field0)? kickedOffline,
    TResult Function()? tokenExpired,
    TResult Function(int attempt, int maxAttempts)? reconnecting,
    TResult Function(String field0)? loginSuccess,
    TResult Function()? logout,
    required TResult orElse(),
  }) {
    if (reconnecting != null) {
      return reconnecting(attempt, maxAttempts);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(ConnectionEvent_Connecting value) connecting,
    required TResult Function(ConnectionEvent_Connected value) connected,
    required TResult Function(ConnectionEvent_Disconnected value) disconnected,
    required TResult Function(ConnectionEvent_ConnectFailed value)
    connectFailed,
    required TResult Function(ConnectionEvent_KickedOffline value)
    kickedOffline,
    required TResult Function(ConnectionEvent_TokenExpired value) tokenExpired,
    required TResult Function(ConnectionEvent_Reconnecting value) reconnecting,
    required TResult Function(ConnectionEvent_LoginSuccess value) loginSuccess,
    required TResult Function(ConnectionEvent_Logout value) logout,
  }) {
    return reconnecting(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(ConnectionEvent_Connecting value)? connecting,
    TResult? Function(ConnectionEvent_Connected value)? connected,
    TResult? Function(ConnectionEvent_Disconnected value)? disconnected,
    TResult? Function(ConnectionEvent_ConnectFailed value)? connectFailed,
    TResult? Function(ConnectionEvent_KickedOffline value)? kickedOffline,
    TResult? Function(ConnectionEvent_TokenExpired value)? tokenExpired,
    TResult? Function(ConnectionEvent_Reconnecting value)? reconnecting,
    TResult? Function(ConnectionEvent_LoginSuccess value)? loginSuccess,
    TResult? Function(ConnectionEvent_Logout value)? logout,
  }) {
    return reconnecting?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(ConnectionEvent_Connecting value)? connecting,
    TResult Function(ConnectionEvent_Connected value)? connected,
    TResult Function(ConnectionEvent_Disconnected value)? disconnected,
    TResult Function(ConnectionEvent_ConnectFailed value)? connectFailed,
    TResult Function(ConnectionEvent_KickedOffline value)? kickedOffline,
    TResult Function(ConnectionEvent_TokenExpired value)? tokenExpired,
    TResult Function(ConnectionEvent_Reconnecting value)? reconnecting,
    TResult Function(ConnectionEvent_LoginSuccess value)? loginSuccess,
    TResult Function(ConnectionEvent_Logout value)? logout,
    required TResult orElse(),
  }) {
    if (reconnecting != null) {
      return reconnecting(this);
    }
    return orElse();
  }
}

abstract class ConnectionEvent_Reconnecting extends ConnectionEvent {
  const factory ConnectionEvent_Reconnecting({
    required final int attempt,
    required final int maxAttempts,
  }) = _$ConnectionEvent_ReconnectingImpl;
  const ConnectionEvent_Reconnecting._() : super._();

  int get attempt;
  int get maxAttempts;

  /// Create a copy of ConnectionEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ConnectionEvent_ReconnectingImplCopyWith<
    _$ConnectionEvent_ReconnectingImpl
  >
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$ConnectionEvent_LoginSuccessImplCopyWith<$Res> {
  factory _$$ConnectionEvent_LoginSuccessImplCopyWith(
    _$ConnectionEvent_LoginSuccessImpl value,
    $Res Function(_$ConnectionEvent_LoginSuccessImpl) then,
  ) = __$$ConnectionEvent_LoginSuccessImplCopyWithImpl<$Res>;
  @useResult
  $Res call({String field0});
}

/// @nodoc
class __$$ConnectionEvent_LoginSuccessImplCopyWithImpl<$Res>
    extends
        _$ConnectionEventCopyWithImpl<$Res, _$ConnectionEvent_LoginSuccessImpl>
    implements _$$ConnectionEvent_LoginSuccessImplCopyWith<$Res> {
  __$$ConnectionEvent_LoginSuccessImplCopyWithImpl(
    _$ConnectionEvent_LoginSuccessImpl _value,
    $Res Function(_$ConnectionEvent_LoginSuccessImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ConnectionEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? field0 = null}) {
    return _then(
      _$ConnectionEvent_LoginSuccessImpl(
        null == field0
            ? _value.field0
            : field0 // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc

class _$ConnectionEvent_LoginSuccessImpl extends ConnectionEvent_LoginSuccess {
  const _$ConnectionEvent_LoginSuccessImpl(this.field0) : super._();

  @override
  final String field0;

  @override
  String toString() {
    return 'ConnectionEvent.loginSuccess(field0: $field0)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ConnectionEvent_LoginSuccessImpl &&
            (identical(other.field0, field0) || other.field0 == field0));
  }

  @override
  int get hashCode => Object.hash(runtimeType, field0);

  /// Create a copy of ConnectionEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ConnectionEvent_LoginSuccessImplCopyWith<
    _$ConnectionEvent_LoginSuccessImpl
  >
  get copyWith =>
      __$$ConnectionEvent_LoginSuccessImplCopyWithImpl<
        _$ConnectionEvent_LoginSuccessImpl
      >(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() connecting,
    required TResult Function() connected,
    required TResult Function(String field0) disconnected,
    required TResult Function(String field0) connectFailed,
    required TResult Function(String field0) kickedOffline,
    required TResult Function() tokenExpired,
    required TResult Function(int attempt, int maxAttempts) reconnecting,
    required TResult Function(String field0) loginSuccess,
    required TResult Function() logout,
  }) {
    return loginSuccess(field0);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? connecting,
    TResult? Function()? connected,
    TResult? Function(String field0)? disconnected,
    TResult? Function(String field0)? connectFailed,
    TResult? Function(String field0)? kickedOffline,
    TResult? Function()? tokenExpired,
    TResult? Function(int attempt, int maxAttempts)? reconnecting,
    TResult? Function(String field0)? loginSuccess,
    TResult? Function()? logout,
  }) {
    return loginSuccess?.call(field0);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? connecting,
    TResult Function()? connected,
    TResult Function(String field0)? disconnected,
    TResult Function(String field0)? connectFailed,
    TResult Function(String field0)? kickedOffline,
    TResult Function()? tokenExpired,
    TResult Function(int attempt, int maxAttempts)? reconnecting,
    TResult Function(String field0)? loginSuccess,
    TResult Function()? logout,
    required TResult orElse(),
  }) {
    if (loginSuccess != null) {
      return loginSuccess(field0);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(ConnectionEvent_Connecting value) connecting,
    required TResult Function(ConnectionEvent_Connected value) connected,
    required TResult Function(ConnectionEvent_Disconnected value) disconnected,
    required TResult Function(ConnectionEvent_ConnectFailed value)
    connectFailed,
    required TResult Function(ConnectionEvent_KickedOffline value)
    kickedOffline,
    required TResult Function(ConnectionEvent_TokenExpired value) tokenExpired,
    required TResult Function(ConnectionEvent_Reconnecting value) reconnecting,
    required TResult Function(ConnectionEvent_LoginSuccess value) loginSuccess,
    required TResult Function(ConnectionEvent_Logout value) logout,
  }) {
    return loginSuccess(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(ConnectionEvent_Connecting value)? connecting,
    TResult? Function(ConnectionEvent_Connected value)? connected,
    TResult? Function(ConnectionEvent_Disconnected value)? disconnected,
    TResult? Function(ConnectionEvent_ConnectFailed value)? connectFailed,
    TResult? Function(ConnectionEvent_KickedOffline value)? kickedOffline,
    TResult? Function(ConnectionEvent_TokenExpired value)? tokenExpired,
    TResult? Function(ConnectionEvent_Reconnecting value)? reconnecting,
    TResult? Function(ConnectionEvent_LoginSuccess value)? loginSuccess,
    TResult? Function(ConnectionEvent_Logout value)? logout,
  }) {
    return loginSuccess?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(ConnectionEvent_Connecting value)? connecting,
    TResult Function(ConnectionEvent_Connected value)? connected,
    TResult Function(ConnectionEvent_Disconnected value)? disconnected,
    TResult Function(ConnectionEvent_ConnectFailed value)? connectFailed,
    TResult Function(ConnectionEvent_KickedOffline value)? kickedOffline,
    TResult Function(ConnectionEvent_TokenExpired value)? tokenExpired,
    TResult Function(ConnectionEvent_Reconnecting value)? reconnecting,
    TResult Function(ConnectionEvent_LoginSuccess value)? loginSuccess,
    TResult Function(ConnectionEvent_Logout value)? logout,
    required TResult orElse(),
  }) {
    if (loginSuccess != null) {
      return loginSuccess(this);
    }
    return orElse();
  }
}

abstract class ConnectionEvent_LoginSuccess extends ConnectionEvent {
  const factory ConnectionEvent_LoginSuccess(final String field0) =
      _$ConnectionEvent_LoginSuccessImpl;
  const ConnectionEvent_LoginSuccess._() : super._();

  String get field0;

  /// Create a copy of ConnectionEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ConnectionEvent_LoginSuccessImplCopyWith<
    _$ConnectionEvent_LoginSuccessImpl
  >
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$ConnectionEvent_LogoutImplCopyWith<$Res> {
  factory _$$ConnectionEvent_LogoutImplCopyWith(
    _$ConnectionEvent_LogoutImpl value,
    $Res Function(_$ConnectionEvent_LogoutImpl) then,
  ) = __$$ConnectionEvent_LogoutImplCopyWithImpl<$Res>;
}

/// @nodoc
class __$$ConnectionEvent_LogoutImplCopyWithImpl<$Res>
    extends _$ConnectionEventCopyWithImpl<$Res, _$ConnectionEvent_LogoutImpl>
    implements _$$ConnectionEvent_LogoutImplCopyWith<$Res> {
  __$$ConnectionEvent_LogoutImplCopyWithImpl(
    _$ConnectionEvent_LogoutImpl _value,
    $Res Function(_$ConnectionEvent_LogoutImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ConnectionEvent
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc

class _$ConnectionEvent_LogoutImpl extends ConnectionEvent_Logout {
  const _$ConnectionEvent_LogoutImpl() : super._();

  @override
  String toString() {
    return 'ConnectionEvent.logout()';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ConnectionEvent_LogoutImpl);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() connecting,
    required TResult Function() connected,
    required TResult Function(String field0) disconnected,
    required TResult Function(String field0) connectFailed,
    required TResult Function(String field0) kickedOffline,
    required TResult Function() tokenExpired,
    required TResult Function(int attempt, int maxAttempts) reconnecting,
    required TResult Function(String field0) loginSuccess,
    required TResult Function() logout,
  }) {
    return logout();
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? connecting,
    TResult? Function()? connected,
    TResult? Function(String field0)? disconnected,
    TResult? Function(String field0)? connectFailed,
    TResult? Function(String field0)? kickedOffline,
    TResult? Function()? tokenExpired,
    TResult? Function(int attempt, int maxAttempts)? reconnecting,
    TResult? Function(String field0)? loginSuccess,
    TResult? Function()? logout,
  }) {
    return logout?.call();
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? connecting,
    TResult Function()? connected,
    TResult Function(String field0)? disconnected,
    TResult Function(String field0)? connectFailed,
    TResult Function(String field0)? kickedOffline,
    TResult Function()? tokenExpired,
    TResult Function(int attempt, int maxAttempts)? reconnecting,
    TResult Function(String field0)? loginSuccess,
    TResult Function()? logout,
    required TResult orElse(),
  }) {
    if (logout != null) {
      return logout();
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(ConnectionEvent_Connecting value) connecting,
    required TResult Function(ConnectionEvent_Connected value) connected,
    required TResult Function(ConnectionEvent_Disconnected value) disconnected,
    required TResult Function(ConnectionEvent_ConnectFailed value)
    connectFailed,
    required TResult Function(ConnectionEvent_KickedOffline value)
    kickedOffline,
    required TResult Function(ConnectionEvent_TokenExpired value) tokenExpired,
    required TResult Function(ConnectionEvent_Reconnecting value) reconnecting,
    required TResult Function(ConnectionEvent_LoginSuccess value) loginSuccess,
    required TResult Function(ConnectionEvent_Logout value) logout,
  }) {
    return logout(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(ConnectionEvent_Connecting value)? connecting,
    TResult? Function(ConnectionEvent_Connected value)? connected,
    TResult? Function(ConnectionEvent_Disconnected value)? disconnected,
    TResult? Function(ConnectionEvent_ConnectFailed value)? connectFailed,
    TResult? Function(ConnectionEvent_KickedOffline value)? kickedOffline,
    TResult? Function(ConnectionEvent_TokenExpired value)? tokenExpired,
    TResult? Function(ConnectionEvent_Reconnecting value)? reconnecting,
    TResult? Function(ConnectionEvent_LoginSuccess value)? loginSuccess,
    TResult? Function(ConnectionEvent_Logout value)? logout,
  }) {
    return logout?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(ConnectionEvent_Connecting value)? connecting,
    TResult Function(ConnectionEvent_Connected value)? connected,
    TResult Function(ConnectionEvent_Disconnected value)? disconnected,
    TResult Function(ConnectionEvent_ConnectFailed value)? connectFailed,
    TResult Function(ConnectionEvent_KickedOffline value)? kickedOffline,
    TResult Function(ConnectionEvent_TokenExpired value)? tokenExpired,
    TResult Function(ConnectionEvent_Reconnecting value)? reconnecting,
    TResult Function(ConnectionEvent_LoginSuccess value)? loginSuccess,
    TResult Function(ConnectionEvent_Logout value)? logout,
    required TResult orElse(),
  }) {
    if (logout != null) {
      return logout(this);
    }
    return orElse();
  }
}

abstract class ConnectionEvent_Logout extends ConnectionEvent {
  const factory ConnectionEvent_Logout() = _$ConnectionEvent_LogoutImpl;
  const ConnectionEvent_Logout._() : super._();
}
