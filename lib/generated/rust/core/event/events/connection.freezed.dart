// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'connection.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ConnectionEvent {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ConnectionEvent);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'ConnectionEvent()';
}


}

/// @nodoc
class $ConnectionEventCopyWith<$Res>  {
$ConnectionEventCopyWith(ConnectionEvent _, $Res Function(ConnectionEvent) __);
}


/// Adds pattern-matching-related methods to [ConnectionEvent].
extension ConnectionEventPatterns on ConnectionEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( ConnectionEvent_Connecting value)?  connecting,TResult Function( ConnectionEvent_Connected value)?  connected,TResult Function( ConnectionEvent_Disconnected value)?  disconnected,TResult Function( ConnectionEvent_ConnectFailed value)?  connectFailed,TResult Function( ConnectionEvent_KickedOffline value)?  kickedOffline,TResult Function( ConnectionEvent_TokenExpired value)?  tokenExpired,TResult Function( ConnectionEvent_TokenInvalid value)?  tokenInvalid,TResult Function( ConnectionEvent_Reconnecting value)?  reconnecting,TResult Function( ConnectionEvent_LoginSuccess value)?  loginSuccess,TResult Function( ConnectionEvent_Logout value)?  logout,required TResult orElse(),}){
final _that = this;
switch (_that) {
case ConnectionEvent_Connecting() when connecting != null:
return connecting(_that);case ConnectionEvent_Connected() when connected != null:
return connected(_that);case ConnectionEvent_Disconnected() when disconnected != null:
return disconnected(_that);case ConnectionEvent_ConnectFailed() when connectFailed != null:
return connectFailed(_that);case ConnectionEvent_KickedOffline() when kickedOffline != null:
return kickedOffline(_that);case ConnectionEvent_TokenExpired() when tokenExpired != null:
return tokenExpired(_that);case ConnectionEvent_TokenInvalid() when tokenInvalid != null:
return tokenInvalid(_that);case ConnectionEvent_Reconnecting() when reconnecting != null:
return reconnecting(_that);case ConnectionEvent_LoginSuccess() when loginSuccess != null:
return loginSuccess(_that);case ConnectionEvent_Logout() when logout != null:
return logout(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( ConnectionEvent_Connecting value)  connecting,required TResult Function( ConnectionEvent_Connected value)  connected,required TResult Function( ConnectionEvent_Disconnected value)  disconnected,required TResult Function( ConnectionEvent_ConnectFailed value)  connectFailed,required TResult Function( ConnectionEvent_KickedOffline value)  kickedOffline,required TResult Function( ConnectionEvent_TokenExpired value)  tokenExpired,required TResult Function( ConnectionEvent_TokenInvalid value)  tokenInvalid,required TResult Function( ConnectionEvent_Reconnecting value)  reconnecting,required TResult Function( ConnectionEvent_LoginSuccess value)  loginSuccess,required TResult Function( ConnectionEvent_Logout value)  logout,}){
final _that = this;
switch (_that) {
case ConnectionEvent_Connecting():
return connecting(_that);case ConnectionEvent_Connected():
return connected(_that);case ConnectionEvent_Disconnected():
return disconnected(_that);case ConnectionEvent_ConnectFailed():
return connectFailed(_that);case ConnectionEvent_KickedOffline():
return kickedOffline(_that);case ConnectionEvent_TokenExpired():
return tokenExpired(_that);case ConnectionEvent_TokenInvalid():
return tokenInvalid(_that);case ConnectionEvent_Reconnecting():
return reconnecting(_that);case ConnectionEvent_LoginSuccess():
return loginSuccess(_that);case ConnectionEvent_Logout():
return logout(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( ConnectionEvent_Connecting value)?  connecting,TResult? Function( ConnectionEvent_Connected value)?  connected,TResult? Function( ConnectionEvent_Disconnected value)?  disconnected,TResult? Function( ConnectionEvent_ConnectFailed value)?  connectFailed,TResult? Function( ConnectionEvent_KickedOffline value)?  kickedOffline,TResult? Function( ConnectionEvent_TokenExpired value)?  tokenExpired,TResult? Function( ConnectionEvent_TokenInvalid value)?  tokenInvalid,TResult? Function( ConnectionEvent_Reconnecting value)?  reconnecting,TResult? Function( ConnectionEvent_LoginSuccess value)?  loginSuccess,TResult? Function( ConnectionEvent_Logout value)?  logout,}){
final _that = this;
switch (_that) {
case ConnectionEvent_Connecting() when connecting != null:
return connecting(_that);case ConnectionEvent_Connected() when connected != null:
return connected(_that);case ConnectionEvent_Disconnected() when disconnected != null:
return disconnected(_that);case ConnectionEvent_ConnectFailed() when connectFailed != null:
return connectFailed(_that);case ConnectionEvent_KickedOffline() when kickedOffline != null:
return kickedOffline(_that);case ConnectionEvent_TokenExpired() when tokenExpired != null:
return tokenExpired(_that);case ConnectionEvent_TokenInvalid() when tokenInvalid != null:
return tokenInvalid(_that);case ConnectionEvent_Reconnecting() when reconnecting != null:
return reconnecting(_that);case ConnectionEvent_LoginSuccess() when loginSuccess != null:
return loginSuccess(_that);case ConnectionEvent_Logout() when logout != null:
return logout(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  connecting,TResult Function()?  connected,TResult Function( String field0)?  disconnected,TResult Function( int errCode,  String error)?  connectFailed,TResult Function( String field0)?  kickedOffline,TResult Function()?  tokenExpired,TResult Function( String error)?  tokenInvalid,TResult Function( int attempt,  int maxAttempts)?  reconnecting,TResult Function( String field0)?  loginSuccess,TResult Function()?  logout,required TResult orElse(),}) {final _that = this;
switch (_that) {
case ConnectionEvent_Connecting() when connecting != null:
return connecting();case ConnectionEvent_Connected() when connected != null:
return connected();case ConnectionEvent_Disconnected() when disconnected != null:
return disconnected(_that.field0);case ConnectionEvent_ConnectFailed() when connectFailed != null:
return connectFailed(_that.errCode,_that.error);case ConnectionEvent_KickedOffline() when kickedOffline != null:
return kickedOffline(_that.field0);case ConnectionEvent_TokenExpired() when tokenExpired != null:
return tokenExpired();case ConnectionEvent_TokenInvalid() when tokenInvalid != null:
return tokenInvalid(_that.error);case ConnectionEvent_Reconnecting() when reconnecting != null:
return reconnecting(_that.attempt,_that.maxAttempts);case ConnectionEvent_LoginSuccess() when loginSuccess != null:
return loginSuccess(_that.field0);case ConnectionEvent_Logout() when logout != null:
return logout();case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  connecting,required TResult Function()  connected,required TResult Function( String field0)  disconnected,required TResult Function( int errCode,  String error)  connectFailed,required TResult Function( String field0)  kickedOffline,required TResult Function()  tokenExpired,required TResult Function( String error)  tokenInvalid,required TResult Function( int attempt,  int maxAttempts)  reconnecting,required TResult Function( String field0)  loginSuccess,required TResult Function()  logout,}) {final _that = this;
switch (_that) {
case ConnectionEvent_Connecting():
return connecting();case ConnectionEvent_Connected():
return connected();case ConnectionEvent_Disconnected():
return disconnected(_that.field0);case ConnectionEvent_ConnectFailed():
return connectFailed(_that.errCode,_that.error);case ConnectionEvent_KickedOffline():
return kickedOffline(_that.field0);case ConnectionEvent_TokenExpired():
return tokenExpired();case ConnectionEvent_TokenInvalid():
return tokenInvalid(_that.error);case ConnectionEvent_Reconnecting():
return reconnecting(_that.attempt,_that.maxAttempts);case ConnectionEvent_LoginSuccess():
return loginSuccess(_that.field0);case ConnectionEvent_Logout():
return logout();}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  connecting,TResult? Function()?  connected,TResult? Function( String field0)?  disconnected,TResult? Function( int errCode,  String error)?  connectFailed,TResult? Function( String field0)?  kickedOffline,TResult? Function()?  tokenExpired,TResult? Function( String error)?  tokenInvalid,TResult? Function( int attempt,  int maxAttempts)?  reconnecting,TResult? Function( String field0)?  loginSuccess,TResult? Function()?  logout,}) {final _that = this;
switch (_that) {
case ConnectionEvent_Connecting() when connecting != null:
return connecting();case ConnectionEvent_Connected() when connected != null:
return connected();case ConnectionEvent_Disconnected() when disconnected != null:
return disconnected(_that.field0);case ConnectionEvent_ConnectFailed() when connectFailed != null:
return connectFailed(_that.errCode,_that.error);case ConnectionEvent_KickedOffline() when kickedOffline != null:
return kickedOffline(_that.field0);case ConnectionEvent_TokenExpired() when tokenExpired != null:
return tokenExpired();case ConnectionEvent_TokenInvalid() when tokenInvalid != null:
return tokenInvalid(_that.error);case ConnectionEvent_Reconnecting() when reconnecting != null:
return reconnecting(_that.attempt,_that.maxAttempts);case ConnectionEvent_LoginSuccess() when loginSuccess != null:
return loginSuccess(_that.field0);case ConnectionEvent_Logout() when logout != null:
return logout();case _:
  return null;

}
}

}

/// @nodoc


class ConnectionEvent_Connecting extends ConnectionEvent {
  const ConnectionEvent_Connecting(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ConnectionEvent_Connecting);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'ConnectionEvent.connecting()';
}


}




/// @nodoc


class ConnectionEvent_Connected extends ConnectionEvent {
  const ConnectionEvent_Connected(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ConnectionEvent_Connected);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'ConnectionEvent.connected()';
}


}




/// @nodoc


class ConnectionEvent_Disconnected extends ConnectionEvent {
  const ConnectionEvent_Disconnected(this.field0): super._();
  

 final  String field0;

/// Create a copy of ConnectionEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ConnectionEvent_DisconnectedCopyWith<ConnectionEvent_Disconnected> get copyWith => _$ConnectionEvent_DisconnectedCopyWithImpl<ConnectionEvent_Disconnected>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ConnectionEvent_Disconnected&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'ConnectionEvent.disconnected(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $ConnectionEvent_DisconnectedCopyWith<$Res> implements $ConnectionEventCopyWith<$Res> {
  factory $ConnectionEvent_DisconnectedCopyWith(ConnectionEvent_Disconnected value, $Res Function(ConnectionEvent_Disconnected) _then) = _$ConnectionEvent_DisconnectedCopyWithImpl;
@useResult
$Res call({
 String field0
});




}
/// @nodoc
class _$ConnectionEvent_DisconnectedCopyWithImpl<$Res>
    implements $ConnectionEvent_DisconnectedCopyWith<$Res> {
  _$ConnectionEvent_DisconnectedCopyWithImpl(this._self, this._then);

  final ConnectionEvent_Disconnected _self;
  final $Res Function(ConnectionEvent_Disconnected) _then;

/// Create a copy of ConnectionEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(ConnectionEvent_Disconnected(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class ConnectionEvent_ConnectFailed extends ConnectionEvent {
  const ConnectionEvent_ConnectFailed({required this.errCode, required this.error}): super._();
  

 final  int errCode;
 final  String error;

/// Create a copy of ConnectionEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ConnectionEvent_ConnectFailedCopyWith<ConnectionEvent_ConnectFailed> get copyWith => _$ConnectionEvent_ConnectFailedCopyWithImpl<ConnectionEvent_ConnectFailed>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ConnectionEvent_ConnectFailed&&(identical(other.errCode, errCode) || other.errCode == errCode)&&(identical(other.error, error) || other.error == error));
}


@override
int get hashCode => Object.hash(runtimeType,errCode,error);

@override
String toString() {
  return 'ConnectionEvent.connectFailed(errCode: $errCode, error: $error)';
}


}

/// @nodoc
abstract mixin class $ConnectionEvent_ConnectFailedCopyWith<$Res> implements $ConnectionEventCopyWith<$Res> {
  factory $ConnectionEvent_ConnectFailedCopyWith(ConnectionEvent_ConnectFailed value, $Res Function(ConnectionEvent_ConnectFailed) _then) = _$ConnectionEvent_ConnectFailedCopyWithImpl;
@useResult
$Res call({
 int errCode, String error
});




}
/// @nodoc
class _$ConnectionEvent_ConnectFailedCopyWithImpl<$Res>
    implements $ConnectionEvent_ConnectFailedCopyWith<$Res> {
  _$ConnectionEvent_ConnectFailedCopyWithImpl(this._self, this._then);

  final ConnectionEvent_ConnectFailed _self;
  final $Res Function(ConnectionEvent_ConnectFailed) _then;

/// Create a copy of ConnectionEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? errCode = null,Object? error = null,}) {
  return _then(ConnectionEvent_ConnectFailed(
errCode: null == errCode ? _self.errCode : errCode // ignore: cast_nullable_to_non_nullable
as int,error: null == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class ConnectionEvent_KickedOffline extends ConnectionEvent {
  const ConnectionEvent_KickedOffline(this.field0): super._();
  

 final  String field0;

/// Create a copy of ConnectionEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ConnectionEvent_KickedOfflineCopyWith<ConnectionEvent_KickedOffline> get copyWith => _$ConnectionEvent_KickedOfflineCopyWithImpl<ConnectionEvent_KickedOffline>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ConnectionEvent_KickedOffline&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'ConnectionEvent.kickedOffline(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $ConnectionEvent_KickedOfflineCopyWith<$Res> implements $ConnectionEventCopyWith<$Res> {
  factory $ConnectionEvent_KickedOfflineCopyWith(ConnectionEvent_KickedOffline value, $Res Function(ConnectionEvent_KickedOffline) _then) = _$ConnectionEvent_KickedOfflineCopyWithImpl;
@useResult
$Res call({
 String field0
});




}
/// @nodoc
class _$ConnectionEvent_KickedOfflineCopyWithImpl<$Res>
    implements $ConnectionEvent_KickedOfflineCopyWith<$Res> {
  _$ConnectionEvent_KickedOfflineCopyWithImpl(this._self, this._then);

  final ConnectionEvent_KickedOffline _self;
  final $Res Function(ConnectionEvent_KickedOffline) _then;

/// Create a copy of ConnectionEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(ConnectionEvent_KickedOffline(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class ConnectionEvent_TokenExpired extends ConnectionEvent {
  const ConnectionEvent_TokenExpired(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ConnectionEvent_TokenExpired);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'ConnectionEvent.tokenExpired()';
}


}




/// @nodoc


class ConnectionEvent_TokenInvalid extends ConnectionEvent {
  const ConnectionEvent_TokenInvalid({required this.error}): super._();
  

 final  String error;

/// Create a copy of ConnectionEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ConnectionEvent_TokenInvalidCopyWith<ConnectionEvent_TokenInvalid> get copyWith => _$ConnectionEvent_TokenInvalidCopyWithImpl<ConnectionEvent_TokenInvalid>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ConnectionEvent_TokenInvalid&&(identical(other.error, error) || other.error == error));
}


@override
int get hashCode => Object.hash(runtimeType,error);

@override
String toString() {
  return 'ConnectionEvent.tokenInvalid(error: $error)';
}


}

/// @nodoc
abstract mixin class $ConnectionEvent_TokenInvalidCopyWith<$Res> implements $ConnectionEventCopyWith<$Res> {
  factory $ConnectionEvent_TokenInvalidCopyWith(ConnectionEvent_TokenInvalid value, $Res Function(ConnectionEvent_TokenInvalid) _then) = _$ConnectionEvent_TokenInvalidCopyWithImpl;
@useResult
$Res call({
 String error
});




}
/// @nodoc
class _$ConnectionEvent_TokenInvalidCopyWithImpl<$Res>
    implements $ConnectionEvent_TokenInvalidCopyWith<$Res> {
  _$ConnectionEvent_TokenInvalidCopyWithImpl(this._self, this._then);

  final ConnectionEvent_TokenInvalid _self;
  final $Res Function(ConnectionEvent_TokenInvalid) _then;

/// Create a copy of ConnectionEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? error = null,}) {
  return _then(ConnectionEvent_TokenInvalid(
error: null == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class ConnectionEvent_Reconnecting extends ConnectionEvent {
  const ConnectionEvent_Reconnecting({required this.attempt, required this.maxAttempts}): super._();
  

 final  int attempt;
 final  int maxAttempts;

/// Create a copy of ConnectionEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ConnectionEvent_ReconnectingCopyWith<ConnectionEvent_Reconnecting> get copyWith => _$ConnectionEvent_ReconnectingCopyWithImpl<ConnectionEvent_Reconnecting>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ConnectionEvent_Reconnecting&&(identical(other.attempt, attempt) || other.attempt == attempt)&&(identical(other.maxAttempts, maxAttempts) || other.maxAttempts == maxAttempts));
}


@override
int get hashCode => Object.hash(runtimeType,attempt,maxAttempts);

@override
String toString() {
  return 'ConnectionEvent.reconnecting(attempt: $attempt, maxAttempts: $maxAttempts)';
}


}

/// @nodoc
abstract mixin class $ConnectionEvent_ReconnectingCopyWith<$Res> implements $ConnectionEventCopyWith<$Res> {
  factory $ConnectionEvent_ReconnectingCopyWith(ConnectionEvent_Reconnecting value, $Res Function(ConnectionEvent_Reconnecting) _then) = _$ConnectionEvent_ReconnectingCopyWithImpl;
@useResult
$Res call({
 int attempt, int maxAttempts
});




}
/// @nodoc
class _$ConnectionEvent_ReconnectingCopyWithImpl<$Res>
    implements $ConnectionEvent_ReconnectingCopyWith<$Res> {
  _$ConnectionEvent_ReconnectingCopyWithImpl(this._self, this._then);

  final ConnectionEvent_Reconnecting _self;
  final $Res Function(ConnectionEvent_Reconnecting) _then;

/// Create a copy of ConnectionEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? attempt = null,Object? maxAttempts = null,}) {
  return _then(ConnectionEvent_Reconnecting(
attempt: null == attempt ? _self.attempt : attempt // ignore: cast_nullable_to_non_nullable
as int,maxAttempts: null == maxAttempts ? _self.maxAttempts : maxAttempts // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class ConnectionEvent_LoginSuccess extends ConnectionEvent {
  const ConnectionEvent_LoginSuccess(this.field0): super._();
  

 final  String field0;

/// Create a copy of ConnectionEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ConnectionEvent_LoginSuccessCopyWith<ConnectionEvent_LoginSuccess> get copyWith => _$ConnectionEvent_LoginSuccessCopyWithImpl<ConnectionEvent_LoginSuccess>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ConnectionEvent_LoginSuccess&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'ConnectionEvent.loginSuccess(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $ConnectionEvent_LoginSuccessCopyWith<$Res> implements $ConnectionEventCopyWith<$Res> {
  factory $ConnectionEvent_LoginSuccessCopyWith(ConnectionEvent_LoginSuccess value, $Res Function(ConnectionEvent_LoginSuccess) _then) = _$ConnectionEvent_LoginSuccessCopyWithImpl;
@useResult
$Res call({
 String field0
});




}
/// @nodoc
class _$ConnectionEvent_LoginSuccessCopyWithImpl<$Res>
    implements $ConnectionEvent_LoginSuccessCopyWith<$Res> {
  _$ConnectionEvent_LoginSuccessCopyWithImpl(this._self, this._then);

  final ConnectionEvent_LoginSuccess _self;
  final $Res Function(ConnectionEvent_LoginSuccess) _then;

/// Create a copy of ConnectionEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(ConnectionEvent_LoginSuccess(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class ConnectionEvent_Logout extends ConnectionEvent {
  const ConnectionEvent_Logout(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ConnectionEvent_Logout);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'ConnectionEvent.logout()';
}


}




// dart format on
