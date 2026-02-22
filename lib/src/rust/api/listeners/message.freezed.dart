// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'message.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$MessageEvent {
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(MsgStruct message) recvNewMessage,
    required TResult Function(String msgReceiptList) recvC2CReadReceipt,
    required TResult Function(MessageRevoked messageRevoked)
    newRecvMessageRevoked,
    required TResult Function(MsgStruct message) recvOfflineNewMessage,
    required TResult Function(MsgStruct message) msgDeleted,
    required TResult Function(MsgStruct message) recvOnlineOnlyMessage,
    required TResult Function() kickedOffline,
    required TResult Function(TypingStatus typingStatus) recvTypingStatus,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(MsgStruct message)? recvNewMessage,
    TResult? Function(String msgReceiptList)? recvC2CReadReceipt,
    TResult? Function(MessageRevoked messageRevoked)? newRecvMessageRevoked,
    TResult? Function(MsgStruct message)? recvOfflineNewMessage,
    TResult? Function(MsgStruct message)? msgDeleted,
    TResult? Function(MsgStruct message)? recvOnlineOnlyMessage,
    TResult? Function()? kickedOffline,
    TResult? Function(TypingStatus typingStatus)? recvTypingStatus,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(MsgStruct message)? recvNewMessage,
    TResult Function(String msgReceiptList)? recvC2CReadReceipt,
    TResult Function(MessageRevoked messageRevoked)? newRecvMessageRevoked,
    TResult Function(MsgStruct message)? recvOfflineNewMessage,
    TResult Function(MsgStruct message)? msgDeleted,
    TResult Function(MsgStruct message)? recvOnlineOnlyMessage,
    TResult Function()? kickedOffline,
    TResult Function(TypingStatus typingStatus)? recvTypingStatus,
    required TResult orElse(),
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(MessageEvent_RecvNewMessage value) recvNewMessage,
    required TResult Function(MessageEvent_RecvC2CReadReceipt value)
    recvC2CReadReceipt,
    required TResult Function(MessageEvent_NewRecvMessageRevoked value)
    newRecvMessageRevoked,
    required TResult Function(MessageEvent_RecvOfflineNewMessage value)
    recvOfflineNewMessage,
    required TResult Function(MessageEvent_MsgDeleted value) msgDeleted,
    required TResult Function(MessageEvent_RecvOnlineOnlyMessage value)
    recvOnlineOnlyMessage,
    required TResult Function(MessageEvent_KickedOffline value) kickedOffline,
    required TResult Function(MessageEvent_RecvTypingStatus value)
    recvTypingStatus,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(MessageEvent_RecvNewMessage value)? recvNewMessage,
    TResult? Function(MessageEvent_RecvC2CReadReceipt value)?
    recvC2CReadReceipt,
    TResult? Function(MessageEvent_NewRecvMessageRevoked value)?
    newRecvMessageRevoked,
    TResult? Function(MessageEvent_RecvOfflineNewMessage value)?
    recvOfflineNewMessage,
    TResult? Function(MessageEvent_MsgDeleted value)? msgDeleted,
    TResult? Function(MessageEvent_RecvOnlineOnlyMessage value)?
    recvOnlineOnlyMessage,
    TResult? Function(MessageEvent_KickedOffline value)? kickedOffline,
    TResult? Function(MessageEvent_RecvTypingStatus value)? recvTypingStatus,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(MessageEvent_RecvNewMessage value)? recvNewMessage,
    TResult Function(MessageEvent_RecvC2CReadReceipt value)? recvC2CReadReceipt,
    TResult Function(MessageEvent_NewRecvMessageRevoked value)?
    newRecvMessageRevoked,
    TResult Function(MessageEvent_RecvOfflineNewMessage value)?
    recvOfflineNewMessage,
    TResult Function(MessageEvent_MsgDeleted value)? msgDeleted,
    TResult Function(MessageEvent_RecvOnlineOnlyMessage value)?
    recvOnlineOnlyMessage,
    TResult Function(MessageEvent_KickedOffline value)? kickedOffline,
    TResult Function(MessageEvent_RecvTypingStatus value)? recvTypingStatus,
    required TResult orElse(),
  }) => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MessageEventCopyWith<$Res> {
  factory $MessageEventCopyWith(
    MessageEvent value,
    $Res Function(MessageEvent) then,
  ) = _$MessageEventCopyWithImpl<$Res, MessageEvent>;
}

/// @nodoc
class _$MessageEventCopyWithImpl<$Res, $Val extends MessageEvent>
    implements $MessageEventCopyWith<$Res> {
  _$MessageEventCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of MessageEvent
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc
abstract class _$$MessageEvent_RecvNewMessageImplCopyWith<$Res> {
  factory _$$MessageEvent_RecvNewMessageImplCopyWith(
    _$MessageEvent_RecvNewMessageImpl value,
    $Res Function(_$MessageEvent_RecvNewMessageImpl) then,
  ) = __$$MessageEvent_RecvNewMessageImplCopyWithImpl<$Res>;
  @useResult
  $Res call({MsgStruct message});
}

/// @nodoc
class __$$MessageEvent_RecvNewMessageImplCopyWithImpl<$Res>
    extends _$MessageEventCopyWithImpl<$Res, _$MessageEvent_RecvNewMessageImpl>
    implements _$$MessageEvent_RecvNewMessageImplCopyWith<$Res> {
  __$$MessageEvent_RecvNewMessageImplCopyWithImpl(
    _$MessageEvent_RecvNewMessageImpl _value,
    $Res Function(_$MessageEvent_RecvNewMessageImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of MessageEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? message = null}) {
    return _then(
      _$MessageEvent_RecvNewMessageImpl(
        message: null == message
            ? _value.message
            : message // ignore: cast_nullable_to_non_nullable
                  as MsgStruct,
      ),
    );
  }
}

/// @nodoc

class _$MessageEvent_RecvNewMessageImpl extends MessageEvent_RecvNewMessage {
  const _$MessageEvent_RecvNewMessageImpl({required this.message}) : super._();

  @override
  final MsgStruct message;

  @override
  String toString() {
    return 'MessageEvent.recvNewMessage(message: $message)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MessageEvent_RecvNewMessageImpl &&
            (identical(other.message, message) || other.message == message));
  }

  @override
  int get hashCode => Object.hash(runtimeType, message);

  /// Create a copy of MessageEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MessageEvent_RecvNewMessageImplCopyWith<_$MessageEvent_RecvNewMessageImpl>
  get copyWith =>
      __$$MessageEvent_RecvNewMessageImplCopyWithImpl<
        _$MessageEvent_RecvNewMessageImpl
      >(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(MsgStruct message) recvNewMessage,
    required TResult Function(String msgReceiptList) recvC2CReadReceipt,
    required TResult Function(MessageRevoked messageRevoked)
    newRecvMessageRevoked,
    required TResult Function(MsgStruct message) recvOfflineNewMessage,
    required TResult Function(MsgStruct message) msgDeleted,
    required TResult Function(MsgStruct message) recvOnlineOnlyMessage,
    required TResult Function() kickedOffline,
    required TResult Function(TypingStatus typingStatus) recvTypingStatus,
  }) {
    return recvNewMessage(message);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(MsgStruct message)? recvNewMessage,
    TResult? Function(String msgReceiptList)? recvC2CReadReceipt,
    TResult? Function(MessageRevoked messageRevoked)? newRecvMessageRevoked,
    TResult? Function(MsgStruct message)? recvOfflineNewMessage,
    TResult? Function(MsgStruct message)? msgDeleted,
    TResult? Function(MsgStruct message)? recvOnlineOnlyMessage,
    TResult? Function()? kickedOffline,
    TResult? Function(TypingStatus typingStatus)? recvTypingStatus,
  }) {
    return recvNewMessage?.call(message);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(MsgStruct message)? recvNewMessage,
    TResult Function(String msgReceiptList)? recvC2CReadReceipt,
    TResult Function(MessageRevoked messageRevoked)? newRecvMessageRevoked,
    TResult Function(MsgStruct message)? recvOfflineNewMessage,
    TResult Function(MsgStruct message)? msgDeleted,
    TResult Function(MsgStruct message)? recvOnlineOnlyMessage,
    TResult Function()? kickedOffline,
    TResult Function(TypingStatus typingStatus)? recvTypingStatus,
    required TResult orElse(),
  }) {
    if (recvNewMessage != null) {
      return recvNewMessage(message);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(MessageEvent_RecvNewMessage value) recvNewMessage,
    required TResult Function(MessageEvent_RecvC2CReadReceipt value)
    recvC2CReadReceipt,
    required TResult Function(MessageEvent_NewRecvMessageRevoked value)
    newRecvMessageRevoked,
    required TResult Function(MessageEvent_RecvOfflineNewMessage value)
    recvOfflineNewMessage,
    required TResult Function(MessageEvent_MsgDeleted value) msgDeleted,
    required TResult Function(MessageEvent_RecvOnlineOnlyMessage value)
    recvOnlineOnlyMessage,
    required TResult Function(MessageEvent_KickedOffline value) kickedOffline,
    required TResult Function(MessageEvent_RecvTypingStatus value)
    recvTypingStatus,
  }) {
    return recvNewMessage(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(MessageEvent_RecvNewMessage value)? recvNewMessage,
    TResult? Function(MessageEvent_RecvC2CReadReceipt value)?
    recvC2CReadReceipt,
    TResult? Function(MessageEvent_NewRecvMessageRevoked value)?
    newRecvMessageRevoked,
    TResult? Function(MessageEvent_RecvOfflineNewMessage value)?
    recvOfflineNewMessage,
    TResult? Function(MessageEvent_MsgDeleted value)? msgDeleted,
    TResult? Function(MessageEvent_RecvOnlineOnlyMessage value)?
    recvOnlineOnlyMessage,
    TResult? Function(MessageEvent_KickedOffline value)? kickedOffline,
    TResult? Function(MessageEvent_RecvTypingStatus value)? recvTypingStatus,
  }) {
    return recvNewMessage?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(MessageEvent_RecvNewMessage value)? recvNewMessage,
    TResult Function(MessageEvent_RecvC2CReadReceipt value)? recvC2CReadReceipt,
    TResult Function(MessageEvent_NewRecvMessageRevoked value)?
    newRecvMessageRevoked,
    TResult Function(MessageEvent_RecvOfflineNewMessage value)?
    recvOfflineNewMessage,
    TResult Function(MessageEvent_MsgDeleted value)? msgDeleted,
    TResult Function(MessageEvent_RecvOnlineOnlyMessage value)?
    recvOnlineOnlyMessage,
    TResult Function(MessageEvent_KickedOffline value)? kickedOffline,
    TResult Function(MessageEvent_RecvTypingStatus value)? recvTypingStatus,
    required TResult orElse(),
  }) {
    if (recvNewMessage != null) {
      return recvNewMessage(this);
    }
    return orElse();
  }
}

abstract class MessageEvent_RecvNewMessage extends MessageEvent {
  const factory MessageEvent_RecvNewMessage({
    required final MsgStruct message,
  }) = _$MessageEvent_RecvNewMessageImpl;
  const MessageEvent_RecvNewMessage._() : super._();

  MsgStruct get message;

  /// Create a copy of MessageEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MessageEvent_RecvNewMessageImplCopyWith<_$MessageEvent_RecvNewMessageImpl>
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$MessageEvent_RecvC2CReadReceiptImplCopyWith<$Res> {
  factory _$$MessageEvent_RecvC2CReadReceiptImplCopyWith(
    _$MessageEvent_RecvC2CReadReceiptImpl value,
    $Res Function(_$MessageEvent_RecvC2CReadReceiptImpl) then,
  ) = __$$MessageEvent_RecvC2CReadReceiptImplCopyWithImpl<$Res>;
  @useResult
  $Res call({String msgReceiptList});
}

/// @nodoc
class __$$MessageEvent_RecvC2CReadReceiptImplCopyWithImpl<$Res>
    extends
        _$MessageEventCopyWithImpl<$Res, _$MessageEvent_RecvC2CReadReceiptImpl>
    implements _$$MessageEvent_RecvC2CReadReceiptImplCopyWith<$Res> {
  __$$MessageEvent_RecvC2CReadReceiptImplCopyWithImpl(
    _$MessageEvent_RecvC2CReadReceiptImpl _value,
    $Res Function(_$MessageEvent_RecvC2CReadReceiptImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of MessageEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? msgReceiptList = null}) {
    return _then(
      _$MessageEvent_RecvC2CReadReceiptImpl(
        msgReceiptList: null == msgReceiptList
            ? _value.msgReceiptList
            : msgReceiptList // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc

class _$MessageEvent_RecvC2CReadReceiptImpl
    extends MessageEvent_RecvC2CReadReceipt {
  const _$MessageEvent_RecvC2CReadReceiptImpl({required this.msgReceiptList})
    : super._();

  @override
  final String msgReceiptList;

  @override
  String toString() {
    return 'MessageEvent.recvC2CReadReceipt(msgReceiptList: $msgReceiptList)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MessageEvent_RecvC2CReadReceiptImpl &&
            (identical(other.msgReceiptList, msgReceiptList) ||
                other.msgReceiptList == msgReceiptList));
  }

  @override
  int get hashCode => Object.hash(runtimeType, msgReceiptList);

  /// Create a copy of MessageEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MessageEvent_RecvC2CReadReceiptImplCopyWith<
    _$MessageEvent_RecvC2CReadReceiptImpl
  >
  get copyWith =>
      __$$MessageEvent_RecvC2CReadReceiptImplCopyWithImpl<
        _$MessageEvent_RecvC2CReadReceiptImpl
      >(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(MsgStruct message) recvNewMessage,
    required TResult Function(String msgReceiptList) recvC2CReadReceipt,
    required TResult Function(MessageRevoked messageRevoked)
    newRecvMessageRevoked,
    required TResult Function(MsgStruct message) recvOfflineNewMessage,
    required TResult Function(MsgStruct message) msgDeleted,
    required TResult Function(MsgStruct message) recvOnlineOnlyMessage,
    required TResult Function() kickedOffline,
    required TResult Function(TypingStatus typingStatus) recvTypingStatus,
  }) {
    return recvC2CReadReceipt(msgReceiptList);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(MsgStruct message)? recvNewMessage,
    TResult? Function(String msgReceiptList)? recvC2CReadReceipt,
    TResult? Function(MessageRevoked messageRevoked)? newRecvMessageRevoked,
    TResult? Function(MsgStruct message)? recvOfflineNewMessage,
    TResult? Function(MsgStruct message)? msgDeleted,
    TResult? Function(MsgStruct message)? recvOnlineOnlyMessage,
    TResult? Function()? kickedOffline,
    TResult? Function(TypingStatus typingStatus)? recvTypingStatus,
  }) {
    return recvC2CReadReceipt?.call(msgReceiptList);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(MsgStruct message)? recvNewMessage,
    TResult Function(String msgReceiptList)? recvC2CReadReceipt,
    TResult Function(MessageRevoked messageRevoked)? newRecvMessageRevoked,
    TResult Function(MsgStruct message)? recvOfflineNewMessage,
    TResult Function(MsgStruct message)? msgDeleted,
    TResult Function(MsgStruct message)? recvOnlineOnlyMessage,
    TResult Function()? kickedOffline,
    TResult Function(TypingStatus typingStatus)? recvTypingStatus,
    required TResult orElse(),
  }) {
    if (recvC2CReadReceipt != null) {
      return recvC2CReadReceipt(msgReceiptList);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(MessageEvent_RecvNewMessage value) recvNewMessage,
    required TResult Function(MessageEvent_RecvC2CReadReceipt value)
    recvC2CReadReceipt,
    required TResult Function(MessageEvent_NewRecvMessageRevoked value)
    newRecvMessageRevoked,
    required TResult Function(MessageEvent_RecvOfflineNewMessage value)
    recvOfflineNewMessage,
    required TResult Function(MessageEvent_MsgDeleted value) msgDeleted,
    required TResult Function(MessageEvent_RecvOnlineOnlyMessage value)
    recvOnlineOnlyMessage,
    required TResult Function(MessageEvent_KickedOffline value) kickedOffline,
    required TResult Function(MessageEvent_RecvTypingStatus value)
    recvTypingStatus,
  }) {
    return recvC2CReadReceipt(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(MessageEvent_RecvNewMessage value)? recvNewMessage,
    TResult? Function(MessageEvent_RecvC2CReadReceipt value)?
    recvC2CReadReceipt,
    TResult? Function(MessageEvent_NewRecvMessageRevoked value)?
    newRecvMessageRevoked,
    TResult? Function(MessageEvent_RecvOfflineNewMessage value)?
    recvOfflineNewMessage,
    TResult? Function(MessageEvent_MsgDeleted value)? msgDeleted,
    TResult? Function(MessageEvent_RecvOnlineOnlyMessage value)?
    recvOnlineOnlyMessage,
    TResult? Function(MessageEvent_KickedOffline value)? kickedOffline,
    TResult? Function(MessageEvent_RecvTypingStatus value)? recvTypingStatus,
  }) {
    return recvC2CReadReceipt?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(MessageEvent_RecvNewMessage value)? recvNewMessage,
    TResult Function(MessageEvent_RecvC2CReadReceipt value)? recvC2CReadReceipt,
    TResult Function(MessageEvent_NewRecvMessageRevoked value)?
    newRecvMessageRevoked,
    TResult Function(MessageEvent_RecvOfflineNewMessage value)?
    recvOfflineNewMessage,
    TResult Function(MessageEvent_MsgDeleted value)? msgDeleted,
    TResult Function(MessageEvent_RecvOnlineOnlyMessage value)?
    recvOnlineOnlyMessage,
    TResult Function(MessageEvent_KickedOffline value)? kickedOffline,
    TResult Function(MessageEvent_RecvTypingStatus value)? recvTypingStatus,
    required TResult orElse(),
  }) {
    if (recvC2CReadReceipt != null) {
      return recvC2CReadReceipt(this);
    }
    return orElse();
  }
}

abstract class MessageEvent_RecvC2CReadReceipt extends MessageEvent {
  const factory MessageEvent_RecvC2CReadReceipt({
    required final String msgReceiptList,
  }) = _$MessageEvent_RecvC2CReadReceiptImpl;
  const MessageEvent_RecvC2CReadReceipt._() : super._();

  String get msgReceiptList;

  /// Create a copy of MessageEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MessageEvent_RecvC2CReadReceiptImplCopyWith<
    _$MessageEvent_RecvC2CReadReceiptImpl
  >
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$MessageEvent_NewRecvMessageRevokedImplCopyWith<$Res> {
  factory _$$MessageEvent_NewRecvMessageRevokedImplCopyWith(
    _$MessageEvent_NewRecvMessageRevokedImpl value,
    $Res Function(_$MessageEvent_NewRecvMessageRevokedImpl) then,
  ) = __$$MessageEvent_NewRecvMessageRevokedImplCopyWithImpl<$Res>;
  @useResult
  $Res call({MessageRevoked messageRevoked});
}

/// @nodoc
class __$$MessageEvent_NewRecvMessageRevokedImplCopyWithImpl<$Res>
    extends
        _$MessageEventCopyWithImpl<
          $Res,
          _$MessageEvent_NewRecvMessageRevokedImpl
        >
    implements _$$MessageEvent_NewRecvMessageRevokedImplCopyWith<$Res> {
  __$$MessageEvent_NewRecvMessageRevokedImplCopyWithImpl(
    _$MessageEvent_NewRecvMessageRevokedImpl _value,
    $Res Function(_$MessageEvent_NewRecvMessageRevokedImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of MessageEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? messageRevoked = freezed}) {
    return _then(
      _$MessageEvent_NewRecvMessageRevokedImpl(
        messageRevoked: freezed == messageRevoked
            ? _value.messageRevoked
            : messageRevoked // ignore: cast_nullable_to_non_nullable
                  as MessageRevoked,
      ),
    );
  }
}

/// @nodoc

class _$MessageEvent_NewRecvMessageRevokedImpl
    extends MessageEvent_NewRecvMessageRevoked {
  const _$MessageEvent_NewRecvMessageRevokedImpl({required this.messageRevoked})
    : super._();

  @override
  final MessageRevoked messageRevoked;

  @override
  String toString() {
    return 'MessageEvent.newRecvMessageRevoked(messageRevoked: $messageRevoked)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MessageEvent_NewRecvMessageRevokedImpl &&
            const DeepCollectionEquality().equals(
              other.messageRevoked,
              messageRevoked,
            ));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    const DeepCollectionEquality().hash(messageRevoked),
  );

  /// Create a copy of MessageEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MessageEvent_NewRecvMessageRevokedImplCopyWith<
    _$MessageEvent_NewRecvMessageRevokedImpl
  >
  get copyWith =>
      __$$MessageEvent_NewRecvMessageRevokedImplCopyWithImpl<
        _$MessageEvent_NewRecvMessageRevokedImpl
      >(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(MsgStruct message) recvNewMessage,
    required TResult Function(String msgReceiptList) recvC2CReadReceipt,
    required TResult Function(MessageRevoked messageRevoked)
    newRecvMessageRevoked,
    required TResult Function(MsgStruct message) recvOfflineNewMessage,
    required TResult Function(MsgStruct message) msgDeleted,
    required TResult Function(MsgStruct message) recvOnlineOnlyMessage,
    required TResult Function() kickedOffline,
    required TResult Function(TypingStatus typingStatus) recvTypingStatus,
  }) {
    return newRecvMessageRevoked(messageRevoked);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(MsgStruct message)? recvNewMessage,
    TResult? Function(String msgReceiptList)? recvC2CReadReceipt,
    TResult? Function(MessageRevoked messageRevoked)? newRecvMessageRevoked,
    TResult? Function(MsgStruct message)? recvOfflineNewMessage,
    TResult? Function(MsgStruct message)? msgDeleted,
    TResult? Function(MsgStruct message)? recvOnlineOnlyMessage,
    TResult? Function()? kickedOffline,
    TResult? Function(TypingStatus typingStatus)? recvTypingStatus,
  }) {
    return newRecvMessageRevoked?.call(messageRevoked);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(MsgStruct message)? recvNewMessage,
    TResult Function(String msgReceiptList)? recvC2CReadReceipt,
    TResult Function(MessageRevoked messageRevoked)? newRecvMessageRevoked,
    TResult Function(MsgStruct message)? recvOfflineNewMessage,
    TResult Function(MsgStruct message)? msgDeleted,
    TResult Function(MsgStruct message)? recvOnlineOnlyMessage,
    TResult Function()? kickedOffline,
    TResult Function(TypingStatus typingStatus)? recvTypingStatus,
    required TResult orElse(),
  }) {
    if (newRecvMessageRevoked != null) {
      return newRecvMessageRevoked(messageRevoked);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(MessageEvent_RecvNewMessage value) recvNewMessage,
    required TResult Function(MessageEvent_RecvC2CReadReceipt value)
    recvC2CReadReceipt,
    required TResult Function(MessageEvent_NewRecvMessageRevoked value)
    newRecvMessageRevoked,
    required TResult Function(MessageEvent_RecvOfflineNewMessage value)
    recvOfflineNewMessage,
    required TResult Function(MessageEvent_MsgDeleted value) msgDeleted,
    required TResult Function(MessageEvent_RecvOnlineOnlyMessage value)
    recvOnlineOnlyMessage,
    required TResult Function(MessageEvent_KickedOffline value) kickedOffline,
    required TResult Function(MessageEvent_RecvTypingStatus value)
    recvTypingStatus,
  }) {
    return newRecvMessageRevoked(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(MessageEvent_RecvNewMessage value)? recvNewMessage,
    TResult? Function(MessageEvent_RecvC2CReadReceipt value)?
    recvC2CReadReceipt,
    TResult? Function(MessageEvent_NewRecvMessageRevoked value)?
    newRecvMessageRevoked,
    TResult? Function(MessageEvent_RecvOfflineNewMessage value)?
    recvOfflineNewMessage,
    TResult? Function(MessageEvent_MsgDeleted value)? msgDeleted,
    TResult? Function(MessageEvent_RecvOnlineOnlyMessage value)?
    recvOnlineOnlyMessage,
    TResult? Function(MessageEvent_KickedOffline value)? kickedOffline,
    TResult? Function(MessageEvent_RecvTypingStatus value)? recvTypingStatus,
  }) {
    return newRecvMessageRevoked?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(MessageEvent_RecvNewMessage value)? recvNewMessage,
    TResult Function(MessageEvent_RecvC2CReadReceipt value)? recvC2CReadReceipt,
    TResult Function(MessageEvent_NewRecvMessageRevoked value)?
    newRecvMessageRevoked,
    TResult Function(MessageEvent_RecvOfflineNewMessage value)?
    recvOfflineNewMessage,
    TResult Function(MessageEvent_MsgDeleted value)? msgDeleted,
    TResult Function(MessageEvent_RecvOnlineOnlyMessage value)?
    recvOnlineOnlyMessage,
    TResult Function(MessageEvent_KickedOffline value)? kickedOffline,
    TResult Function(MessageEvent_RecvTypingStatus value)? recvTypingStatus,
    required TResult orElse(),
  }) {
    if (newRecvMessageRevoked != null) {
      return newRecvMessageRevoked(this);
    }
    return orElse();
  }
}

abstract class MessageEvent_NewRecvMessageRevoked extends MessageEvent {
  const factory MessageEvent_NewRecvMessageRevoked({
    required final MessageRevoked messageRevoked,
  }) = _$MessageEvent_NewRecvMessageRevokedImpl;
  const MessageEvent_NewRecvMessageRevoked._() : super._();

  MessageRevoked get messageRevoked;

  /// Create a copy of MessageEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MessageEvent_NewRecvMessageRevokedImplCopyWith<
    _$MessageEvent_NewRecvMessageRevokedImpl
  >
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$MessageEvent_RecvOfflineNewMessageImplCopyWith<$Res> {
  factory _$$MessageEvent_RecvOfflineNewMessageImplCopyWith(
    _$MessageEvent_RecvOfflineNewMessageImpl value,
    $Res Function(_$MessageEvent_RecvOfflineNewMessageImpl) then,
  ) = __$$MessageEvent_RecvOfflineNewMessageImplCopyWithImpl<$Res>;
  @useResult
  $Res call({MsgStruct message});
}

/// @nodoc
class __$$MessageEvent_RecvOfflineNewMessageImplCopyWithImpl<$Res>
    extends
        _$MessageEventCopyWithImpl<
          $Res,
          _$MessageEvent_RecvOfflineNewMessageImpl
        >
    implements _$$MessageEvent_RecvOfflineNewMessageImplCopyWith<$Res> {
  __$$MessageEvent_RecvOfflineNewMessageImplCopyWithImpl(
    _$MessageEvent_RecvOfflineNewMessageImpl _value,
    $Res Function(_$MessageEvent_RecvOfflineNewMessageImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of MessageEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? message = null}) {
    return _then(
      _$MessageEvent_RecvOfflineNewMessageImpl(
        message: null == message
            ? _value.message
            : message // ignore: cast_nullable_to_non_nullable
                  as MsgStruct,
      ),
    );
  }
}

/// @nodoc

class _$MessageEvent_RecvOfflineNewMessageImpl
    extends MessageEvent_RecvOfflineNewMessage {
  const _$MessageEvent_RecvOfflineNewMessageImpl({required this.message})
    : super._();

  @override
  final MsgStruct message;

  @override
  String toString() {
    return 'MessageEvent.recvOfflineNewMessage(message: $message)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MessageEvent_RecvOfflineNewMessageImpl &&
            (identical(other.message, message) || other.message == message));
  }

  @override
  int get hashCode => Object.hash(runtimeType, message);

  /// Create a copy of MessageEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MessageEvent_RecvOfflineNewMessageImplCopyWith<
    _$MessageEvent_RecvOfflineNewMessageImpl
  >
  get copyWith =>
      __$$MessageEvent_RecvOfflineNewMessageImplCopyWithImpl<
        _$MessageEvent_RecvOfflineNewMessageImpl
      >(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(MsgStruct message) recvNewMessage,
    required TResult Function(String msgReceiptList) recvC2CReadReceipt,
    required TResult Function(MessageRevoked messageRevoked)
    newRecvMessageRevoked,
    required TResult Function(MsgStruct message) recvOfflineNewMessage,
    required TResult Function(MsgStruct message) msgDeleted,
    required TResult Function(MsgStruct message) recvOnlineOnlyMessage,
    required TResult Function() kickedOffline,
    required TResult Function(TypingStatus typingStatus) recvTypingStatus,
  }) {
    return recvOfflineNewMessage(message);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(MsgStruct message)? recvNewMessage,
    TResult? Function(String msgReceiptList)? recvC2CReadReceipt,
    TResult? Function(MessageRevoked messageRevoked)? newRecvMessageRevoked,
    TResult? Function(MsgStruct message)? recvOfflineNewMessage,
    TResult? Function(MsgStruct message)? msgDeleted,
    TResult? Function(MsgStruct message)? recvOnlineOnlyMessage,
    TResult? Function()? kickedOffline,
    TResult? Function(TypingStatus typingStatus)? recvTypingStatus,
  }) {
    return recvOfflineNewMessage?.call(message);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(MsgStruct message)? recvNewMessage,
    TResult Function(String msgReceiptList)? recvC2CReadReceipt,
    TResult Function(MessageRevoked messageRevoked)? newRecvMessageRevoked,
    TResult Function(MsgStruct message)? recvOfflineNewMessage,
    TResult Function(MsgStruct message)? msgDeleted,
    TResult Function(MsgStruct message)? recvOnlineOnlyMessage,
    TResult Function()? kickedOffline,
    TResult Function(TypingStatus typingStatus)? recvTypingStatus,
    required TResult orElse(),
  }) {
    if (recvOfflineNewMessage != null) {
      return recvOfflineNewMessage(message);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(MessageEvent_RecvNewMessage value) recvNewMessage,
    required TResult Function(MessageEvent_RecvC2CReadReceipt value)
    recvC2CReadReceipt,
    required TResult Function(MessageEvent_NewRecvMessageRevoked value)
    newRecvMessageRevoked,
    required TResult Function(MessageEvent_RecvOfflineNewMessage value)
    recvOfflineNewMessage,
    required TResult Function(MessageEvent_MsgDeleted value) msgDeleted,
    required TResult Function(MessageEvent_RecvOnlineOnlyMessage value)
    recvOnlineOnlyMessage,
    required TResult Function(MessageEvent_KickedOffline value) kickedOffline,
    required TResult Function(MessageEvent_RecvTypingStatus value)
    recvTypingStatus,
  }) {
    return recvOfflineNewMessage(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(MessageEvent_RecvNewMessage value)? recvNewMessage,
    TResult? Function(MessageEvent_RecvC2CReadReceipt value)?
    recvC2CReadReceipt,
    TResult? Function(MessageEvent_NewRecvMessageRevoked value)?
    newRecvMessageRevoked,
    TResult? Function(MessageEvent_RecvOfflineNewMessage value)?
    recvOfflineNewMessage,
    TResult? Function(MessageEvent_MsgDeleted value)? msgDeleted,
    TResult? Function(MessageEvent_RecvOnlineOnlyMessage value)?
    recvOnlineOnlyMessage,
    TResult? Function(MessageEvent_KickedOffline value)? kickedOffline,
    TResult? Function(MessageEvent_RecvTypingStatus value)? recvTypingStatus,
  }) {
    return recvOfflineNewMessage?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(MessageEvent_RecvNewMessage value)? recvNewMessage,
    TResult Function(MessageEvent_RecvC2CReadReceipt value)? recvC2CReadReceipt,
    TResult Function(MessageEvent_NewRecvMessageRevoked value)?
    newRecvMessageRevoked,
    TResult Function(MessageEvent_RecvOfflineNewMessage value)?
    recvOfflineNewMessage,
    TResult Function(MessageEvent_MsgDeleted value)? msgDeleted,
    TResult Function(MessageEvent_RecvOnlineOnlyMessage value)?
    recvOnlineOnlyMessage,
    TResult Function(MessageEvent_KickedOffline value)? kickedOffline,
    TResult Function(MessageEvent_RecvTypingStatus value)? recvTypingStatus,
    required TResult orElse(),
  }) {
    if (recvOfflineNewMessage != null) {
      return recvOfflineNewMessage(this);
    }
    return orElse();
  }
}

abstract class MessageEvent_RecvOfflineNewMessage extends MessageEvent {
  const factory MessageEvent_RecvOfflineNewMessage({
    required final MsgStruct message,
  }) = _$MessageEvent_RecvOfflineNewMessageImpl;
  const MessageEvent_RecvOfflineNewMessage._() : super._();

  MsgStruct get message;

  /// Create a copy of MessageEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MessageEvent_RecvOfflineNewMessageImplCopyWith<
    _$MessageEvent_RecvOfflineNewMessageImpl
  >
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$MessageEvent_MsgDeletedImplCopyWith<$Res> {
  factory _$$MessageEvent_MsgDeletedImplCopyWith(
    _$MessageEvent_MsgDeletedImpl value,
    $Res Function(_$MessageEvent_MsgDeletedImpl) then,
  ) = __$$MessageEvent_MsgDeletedImplCopyWithImpl<$Res>;
  @useResult
  $Res call({MsgStruct message});
}

/// @nodoc
class __$$MessageEvent_MsgDeletedImplCopyWithImpl<$Res>
    extends _$MessageEventCopyWithImpl<$Res, _$MessageEvent_MsgDeletedImpl>
    implements _$$MessageEvent_MsgDeletedImplCopyWith<$Res> {
  __$$MessageEvent_MsgDeletedImplCopyWithImpl(
    _$MessageEvent_MsgDeletedImpl _value,
    $Res Function(_$MessageEvent_MsgDeletedImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of MessageEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? message = null}) {
    return _then(
      _$MessageEvent_MsgDeletedImpl(
        message: null == message
            ? _value.message
            : message // ignore: cast_nullable_to_non_nullable
                  as MsgStruct,
      ),
    );
  }
}

/// @nodoc

class _$MessageEvent_MsgDeletedImpl extends MessageEvent_MsgDeleted {
  const _$MessageEvent_MsgDeletedImpl({required this.message}) : super._();

  @override
  final MsgStruct message;

  @override
  String toString() {
    return 'MessageEvent.msgDeleted(message: $message)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MessageEvent_MsgDeletedImpl &&
            (identical(other.message, message) || other.message == message));
  }

  @override
  int get hashCode => Object.hash(runtimeType, message);

  /// Create a copy of MessageEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MessageEvent_MsgDeletedImplCopyWith<_$MessageEvent_MsgDeletedImpl>
  get copyWith =>
      __$$MessageEvent_MsgDeletedImplCopyWithImpl<
        _$MessageEvent_MsgDeletedImpl
      >(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(MsgStruct message) recvNewMessage,
    required TResult Function(String msgReceiptList) recvC2CReadReceipt,
    required TResult Function(MessageRevoked messageRevoked)
    newRecvMessageRevoked,
    required TResult Function(MsgStruct message) recvOfflineNewMessage,
    required TResult Function(MsgStruct message) msgDeleted,
    required TResult Function(MsgStruct message) recvOnlineOnlyMessage,
    required TResult Function() kickedOffline,
    required TResult Function(TypingStatus typingStatus) recvTypingStatus,
  }) {
    return msgDeleted(message);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(MsgStruct message)? recvNewMessage,
    TResult? Function(String msgReceiptList)? recvC2CReadReceipt,
    TResult? Function(MessageRevoked messageRevoked)? newRecvMessageRevoked,
    TResult? Function(MsgStruct message)? recvOfflineNewMessage,
    TResult? Function(MsgStruct message)? msgDeleted,
    TResult? Function(MsgStruct message)? recvOnlineOnlyMessage,
    TResult? Function()? kickedOffline,
    TResult? Function(TypingStatus typingStatus)? recvTypingStatus,
  }) {
    return msgDeleted?.call(message);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(MsgStruct message)? recvNewMessage,
    TResult Function(String msgReceiptList)? recvC2CReadReceipt,
    TResult Function(MessageRevoked messageRevoked)? newRecvMessageRevoked,
    TResult Function(MsgStruct message)? recvOfflineNewMessage,
    TResult Function(MsgStruct message)? msgDeleted,
    TResult Function(MsgStruct message)? recvOnlineOnlyMessage,
    TResult Function()? kickedOffline,
    TResult Function(TypingStatus typingStatus)? recvTypingStatus,
    required TResult orElse(),
  }) {
    if (msgDeleted != null) {
      return msgDeleted(message);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(MessageEvent_RecvNewMessage value) recvNewMessage,
    required TResult Function(MessageEvent_RecvC2CReadReceipt value)
    recvC2CReadReceipt,
    required TResult Function(MessageEvent_NewRecvMessageRevoked value)
    newRecvMessageRevoked,
    required TResult Function(MessageEvent_RecvOfflineNewMessage value)
    recvOfflineNewMessage,
    required TResult Function(MessageEvent_MsgDeleted value) msgDeleted,
    required TResult Function(MessageEvent_RecvOnlineOnlyMessage value)
    recvOnlineOnlyMessage,
    required TResult Function(MessageEvent_KickedOffline value) kickedOffline,
    required TResult Function(MessageEvent_RecvTypingStatus value)
    recvTypingStatus,
  }) {
    return msgDeleted(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(MessageEvent_RecvNewMessage value)? recvNewMessage,
    TResult? Function(MessageEvent_RecvC2CReadReceipt value)?
    recvC2CReadReceipt,
    TResult? Function(MessageEvent_NewRecvMessageRevoked value)?
    newRecvMessageRevoked,
    TResult? Function(MessageEvent_RecvOfflineNewMessage value)?
    recvOfflineNewMessage,
    TResult? Function(MessageEvent_MsgDeleted value)? msgDeleted,
    TResult? Function(MessageEvent_RecvOnlineOnlyMessage value)?
    recvOnlineOnlyMessage,
    TResult? Function(MessageEvent_KickedOffline value)? kickedOffline,
    TResult? Function(MessageEvent_RecvTypingStatus value)? recvTypingStatus,
  }) {
    return msgDeleted?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(MessageEvent_RecvNewMessage value)? recvNewMessage,
    TResult Function(MessageEvent_RecvC2CReadReceipt value)? recvC2CReadReceipt,
    TResult Function(MessageEvent_NewRecvMessageRevoked value)?
    newRecvMessageRevoked,
    TResult Function(MessageEvent_RecvOfflineNewMessage value)?
    recvOfflineNewMessage,
    TResult Function(MessageEvent_MsgDeleted value)? msgDeleted,
    TResult Function(MessageEvent_RecvOnlineOnlyMessage value)?
    recvOnlineOnlyMessage,
    TResult Function(MessageEvent_KickedOffline value)? kickedOffline,
    TResult Function(MessageEvent_RecvTypingStatus value)? recvTypingStatus,
    required TResult orElse(),
  }) {
    if (msgDeleted != null) {
      return msgDeleted(this);
    }
    return orElse();
  }
}

abstract class MessageEvent_MsgDeleted extends MessageEvent {
  const factory MessageEvent_MsgDeleted({required final MsgStruct message}) =
      _$MessageEvent_MsgDeletedImpl;
  const MessageEvent_MsgDeleted._() : super._();

  MsgStruct get message;

  /// Create a copy of MessageEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MessageEvent_MsgDeletedImplCopyWith<_$MessageEvent_MsgDeletedImpl>
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$MessageEvent_RecvOnlineOnlyMessageImplCopyWith<$Res> {
  factory _$$MessageEvent_RecvOnlineOnlyMessageImplCopyWith(
    _$MessageEvent_RecvOnlineOnlyMessageImpl value,
    $Res Function(_$MessageEvent_RecvOnlineOnlyMessageImpl) then,
  ) = __$$MessageEvent_RecvOnlineOnlyMessageImplCopyWithImpl<$Res>;
  @useResult
  $Res call({MsgStruct message});
}

/// @nodoc
class __$$MessageEvent_RecvOnlineOnlyMessageImplCopyWithImpl<$Res>
    extends
        _$MessageEventCopyWithImpl<
          $Res,
          _$MessageEvent_RecvOnlineOnlyMessageImpl
        >
    implements _$$MessageEvent_RecvOnlineOnlyMessageImplCopyWith<$Res> {
  __$$MessageEvent_RecvOnlineOnlyMessageImplCopyWithImpl(
    _$MessageEvent_RecvOnlineOnlyMessageImpl _value,
    $Res Function(_$MessageEvent_RecvOnlineOnlyMessageImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of MessageEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? message = null}) {
    return _then(
      _$MessageEvent_RecvOnlineOnlyMessageImpl(
        message: null == message
            ? _value.message
            : message // ignore: cast_nullable_to_non_nullable
                  as MsgStruct,
      ),
    );
  }
}

/// @nodoc

class _$MessageEvent_RecvOnlineOnlyMessageImpl
    extends MessageEvent_RecvOnlineOnlyMessage {
  const _$MessageEvent_RecvOnlineOnlyMessageImpl({required this.message})
    : super._();

  @override
  final MsgStruct message;

  @override
  String toString() {
    return 'MessageEvent.recvOnlineOnlyMessage(message: $message)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MessageEvent_RecvOnlineOnlyMessageImpl &&
            (identical(other.message, message) || other.message == message));
  }

  @override
  int get hashCode => Object.hash(runtimeType, message);

  /// Create a copy of MessageEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MessageEvent_RecvOnlineOnlyMessageImplCopyWith<
    _$MessageEvent_RecvOnlineOnlyMessageImpl
  >
  get copyWith =>
      __$$MessageEvent_RecvOnlineOnlyMessageImplCopyWithImpl<
        _$MessageEvent_RecvOnlineOnlyMessageImpl
      >(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(MsgStruct message) recvNewMessage,
    required TResult Function(String msgReceiptList) recvC2CReadReceipt,
    required TResult Function(MessageRevoked messageRevoked)
    newRecvMessageRevoked,
    required TResult Function(MsgStruct message) recvOfflineNewMessage,
    required TResult Function(MsgStruct message) msgDeleted,
    required TResult Function(MsgStruct message) recvOnlineOnlyMessage,
    required TResult Function() kickedOffline,
    required TResult Function(TypingStatus typingStatus) recvTypingStatus,
  }) {
    return recvOnlineOnlyMessage(message);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(MsgStruct message)? recvNewMessage,
    TResult? Function(String msgReceiptList)? recvC2CReadReceipt,
    TResult? Function(MessageRevoked messageRevoked)? newRecvMessageRevoked,
    TResult? Function(MsgStruct message)? recvOfflineNewMessage,
    TResult? Function(MsgStruct message)? msgDeleted,
    TResult? Function(MsgStruct message)? recvOnlineOnlyMessage,
    TResult? Function()? kickedOffline,
    TResult? Function(TypingStatus typingStatus)? recvTypingStatus,
  }) {
    return recvOnlineOnlyMessage?.call(message);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(MsgStruct message)? recvNewMessage,
    TResult Function(String msgReceiptList)? recvC2CReadReceipt,
    TResult Function(MessageRevoked messageRevoked)? newRecvMessageRevoked,
    TResult Function(MsgStruct message)? recvOfflineNewMessage,
    TResult Function(MsgStruct message)? msgDeleted,
    TResult Function(MsgStruct message)? recvOnlineOnlyMessage,
    TResult Function()? kickedOffline,
    TResult Function(TypingStatus typingStatus)? recvTypingStatus,
    required TResult orElse(),
  }) {
    if (recvOnlineOnlyMessage != null) {
      return recvOnlineOnlyMessage(message);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(MessageEvent_RecvNewMessage value) recvNewMessage,
    required TResult Function(MessageEvent_RecvC2CReadReceipt value)
    recvC2CReadReceipt,
    required TResult Function(MessageEvent_NewRecvMessageRevoked value)
    newRecvMessageRevoked,
    required TResult Function(MessageEvent_RecvOfflineNewMessage value)
    recvOfflineNewMessage,
    required TResult Function(MessageEvent_MsgDeleted value) msgDeleted,
    required TResult Function(MessageEvent_RecvOnlineOnlyMessage value)
    recvOnlineOnlyMessage,
    required TResult Function(MessageEvent_KickedOffline value) kickedOffline,
    required TResult Function(MessageEvent_RecvTypingStatus value)
    recvTypingStatus,
  }) {
    return recvOnlineOnlyMessage(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(MessageEvent_RecvNewMessage value)? recvNewMessage,
    TResult? Function(MessageEvent_RecvC2CReadReceipt value)?
    recvC2CReadReceipt,
    TResult? Function(MessageEvent_NewRecvMessageRevoked value)?
    newRecvMessageRevoked,
    TResult? Function(MessageEvent_RecvOfflineNewMessage value)?
    recvOfflineNewMessage,
    TResult? Function(MessageEvent_MsgDeleted value)? msgDeleted,
    TResult? Function(MessageEvent_RecvOnlineOnlyMessage value)?
    recvOnlineOnlyMessage,
    TResult? Function(MessageEvent_KickedOffline value)? kickedOffline,
    TResult? Function(MessageEvent_RecvTypingStatus value)? recvTypingStatus,
  }) {
    return recvOnlineOnlyMessage?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(MessageEvent_RecvNewMessage value)? recvNewMessage,
    TResult Function(MessageEvent_RecvC2CReadReceipt value)? recvC2CReadReceipt,
    TResult Function(MessageEvent_NewRecvMessageRevoked value)?
    newRecvMessageRevoked,
    TResult Function(MessageEvent_RecvOfflineNewMessage value)?
    recvOfflineNewMessage,
    TResult Function(MessageEvent_MsgDeleted value)? msgDeleted,
    TResult Function(MessageEvent_RecvOnlineOnlyMessage value)?
    recvOnlineOnlyMessage,
    TResult Function(MessageEvent_KickedOffline value)? kickedOffline,
    TResult Function(MessageEvent_RecvTypingStatus value)? recvTypingStatus,
    required TResult orElse(),
  }) {
    if (recvOnlineOnlyMessage != null) {
      return recvOnlineOnlyMessage(this);
    }
    return orElse();
  }
}

abstract class MessageEvent_RecvOnlineOnlyMessage extends MessageEvent {
  const factory MessageEvent_RecvOnlineOnlyMessage({
    required final MsgStruct message,
  }) = _$MessageEvent_RecvOnlineOnlyMessageImpl;
  const MessageEvent_RecvOnlineOnlyMessage._() : super._();

  MsgStruct get message;

  /// Create a copy of MessageEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MessageEvent_RecvOnlineOnlyMessageImplCopyWith<
    _$MessageEvent_RecvOnlineOnlyMessageImpl
  >
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$MessageEvent_KickedOfflineImplCopyWith<$Res> {
  factory _$$MessageEvent_KickedOfflineImplCopyWith(
    _$MessageEvent_KickedOfflineImpl value,
    $Res Function(_$MessageEvent_KickedOfflineImpl) then,
  ) = __$$MessageEvent_KickedOfflineImplCopyWithImpl<$Res>;
}

/// @nodoc
class __$$MessageEvent_KickedOfflineImplCopyWithImpl<$Res>
    extends _$MessageEventCopyWithImpl<$Res, _$MessageEvent_KickedOfflineImpl>
    implements _$$MessageEvent_KickedOfflineImplCopyWith<$Res> {
  __$$MessageEvent_KickedOfflineImplCopyWithImpl(
    _$MessageEvent_KickedOfflineImpl _value,
    $Res Function(_$MessageEvent_KickedOfflineImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of MessageEvent
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc

class _$MessageEvent_KickedOfflineImpl extends MessageEvent_KickedOffline {
  const _$MessageEvent_KickedOfflineImpl() : super._();

  @override
  String toString() {
    return 'MessageEvent.kickedOffline()';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MessageEvent_KickedOfflineImpl);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(MsgStruct message) recvNewMessage,
    required TResult Function(String msgReceiptList) recvC2CReadReceipt,
    required TResult Function(MessageRevoked messageRevoked)
    newRecvMessageRevoked,
    required TResult Function(MsgStruct message) recvOfflineNewMessage,
    required TResult Function(MsgStruct message) msgDeleted,
    required TResult Function(MsgStruct message) recvOnlineOnlyMessage,
    required TResult Function() kickedOffline,
    required TResult Function(TypingStatus typingStatus) recvTypingStatus,
  }) {
    return kickedOffline();
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(MsgStruct message)? recvNewMessage,
    TResult? Function(String msgReceiptList)? recvC2CReadReceipt,
    TResult? Function(MessageRevoked messageRevoked)? newRecvMessageRevoked,
    TResult? Function(MsgStruct message)? recvOfflineNewMessage,
    TResult? Function(MsgStruct message)? msgDeleted,
    TResult? Function(MsgStruct message)? recvOnlineOnlyMessage,
    TResult? Function()? kickedOffline,
    TResult? Function(TypingStatus typingStatus)? recvTypingStatus,
  }) {
    return kickedOffline?.call();
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(MsgStruct message)? recvNewMessage,
    TResult Function(String msgReceiptList)? recvC2CReadReceipt,
    TResult Function(MessageRevoked messageRevoked)? newRecvMessageRevoked,
    TResult Function(MsgStruct message)? recvOfflineNewMessage,
    TResult Function(MsgStruct message)? msgDeleted,
    TResult Function(MsgStruct message)? recvOnlineOnlyMessage,
    TResult Function()? kickedOffline,
    TResult Function(TypingStatus typingStatus)? recvTypingStatus,
    required TResult orElse(),
  }) {
    if (kickedOffline != null) {
      return kickedOffline();
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(MessageEvent_RecvNewMessage value) recvNewMessage,
    required TResult Function(MessageEvent_RecvC2CReadReceipt value)
    recvC2CReadReceipt,
    required TResult Function(MessageEvent_NewRecvMessageRevoked value)
    newRecvMessageRevoked,
    required TResult Function(MessageEvent_RecvOfflineNewMessage value)
    recvOfflineNewMessage,
    required TResult Function(MessageEvent_MsgDeleted value) msgDeleted,
    required TResult Function(MessageEvent_RecvOnlineOnlyMessage value)
    recvOnlineOnlyMessage,
    required TResult Function(MessageEvent_KickedOffline value) kickedOffline,
    required TResult Function(MessageEvent_RecvTypingStatus value)
    recvTypingStatus,
  }) {
    return kickedOffline(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(MessageEvent_RecvNewMessage value)? recvNewMessage,
    TResult? Function(MessageEvent_RecvC2CReadReceipt value)?
    recvC2CReadReceipt,
    TResult? Function(MessageEvent_NewRecvMessageRevoked value)?
    newRecvMessageRevoked,
    TResult? Function(MessageEvent_RecvOfflineNewMessage value)?
    recvOfflineNewMessage,
    TResult? Function(MessageEvent_MsgDeleted value)? msgDeleted,
    TResult? Function(MessageEvent_RecvOnlineOnlyMessage value)?
    recvOnlineOnlyMessage,
    TResult? Function(MessageEvent_KickedOffline value)? kickedOffline,
    TResult? Function(MessageEvent_RecvTypingStatus value)? recvTypingStatus,
  }) {
    return kickedOffline?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(MessageEvent_RecvNewMessage value)? recvNewMessage,
    TResult Function(MessageEvent_RecvC2CReadReceipt value)? recvC2CReadReceipt,
    TResult Function(MessageEvent_NewRecvMessageRevoked value)?
    newRecvMessageRevoked,
    TResult Function(MessageEvent_RecvOfflineNewMessage value)?
    recvOfflineNewMessage,
    TResult Function(MessageEvent_MsgDeleted value)? msgDeleted,
    TResult Function(MessageEvent_RecvOnlineOnlyMessage value)?
    recvOnlineOnlyMessage,
    TResult Function(MessageEvent_KickedOffline value)? kickedOffline,
    TResult Function(MessageEvent_RecvTypingStatus value)? recvTypingStatus,
    required TResult orElse(),
  }) {
    if (kickedOffline != null) {
      return kickedOffline(this);
    }
    return orElse();
  }
}

abstract class MessageEvent_KickedOffline extends MessageEvent {
  const factory MessageEvent_KickedOffline() = _$MessageEvent_KickedOfflineImpl;
  const MessageEvent_KickedOffline._() : super._();
}

/// @nodoc
abstract class _$$MessageEvent_RecvTypingStatusImplCopyWith<$Res> {
  factory _$$MessageEvent_RecvTypingStatusImplCopyWith(
    _$MessageEvent_RecvTypingStatusImpl value,
    $Res Function(_$MessageEvent_RecvTypingStatusImpl) then,
  ) = __$$MessageEvent_RecvTypingStatusImplCopyWithImpl<$Res>;
  @useResult
  $Res call({TypingStatus typingStatus});
}

/// @nodoc
class __$$MessageEvent_RecvTypingStatusImplCopyWithImpl<$Res>
    extends
        _$MessageEventCopyWithImpl<$Res, _$MessageEvent_RecvTypingStatusImpl>
    implements _$$MessageEvent_RecvTypingStatusImplCopyWith<$Res> {
  __$$MessageEvent_RecvTypingStatusImplCopyWithImpl(
    _$MessageEvent_RecvTypingStatusImpl _value,
    $Res Function(_$MessageEvent_RecvTypingStatusImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of MessageEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? typingStatus = null}) {
    return _then(
      _$MessageEvent_RecvTypingStatusImpl(
        typingStatus: null == typingStatus
            ? _value.typingStatus
            : typingStatus // ignore: cast_nullable_to_non_nullable
                  as TypingStatus,
      ),
    );
  }
}

/// @nodoc

class _$MessageEvent_RecvTypingStatusImpl
    extends MessageEvent_RecvTypingStatus {
  const _$MessageEvent_RecvTypingStatusImpl({required this.typingStatus})
    : super._();

  @override
  final TypingStatus typingStatus;

  @override
  String toString() {
    return 'MessageEvent.recvTypingStatus(typingStatus: $typingStatus)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MessageEvent_RecvTypingStatusImpl &&
            (identical(other.typingStatus, typingStatus) ||
                other.typingStatus == typingStatus));
  }

  @override
  int get hashCode => Object.hash(runtimeType, typingStatus);

  /// Create a copy of MessageEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MessageEvent_RecvTypingStatusImplCopyWith<
    _$MessageEvent_RecvTypingStatusImpl
  >
  get copyWith =>
      __$$MessageEvent_RecvTypingStatusImplCopyWithImpl<
        _$MessageEvent_RecvTypingStatusImpl
      >(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(MsgStruct message) recvNewMessage,
    required TResult Function(String msgReceiptList) recvC2CReadReceipt,
    required TResult Function(MessageRevoked messageRevoked)
    newRecvMessageRevoked,
    required TResult Function(MsgStruct message) recvOfflineNewMessage,
    required TResult Function(MsgStruct message) msgDeleted,
    required TResult Function(MsgStruct message) recvOnlineOnlyMessage,
    required TResult Function() kickedOffline,
    required TResult Function(TypingStatus typingStatus) recvTypingStatus,
  }) {
    return recvTypingStatus(typingStatus);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(MsgStruct message)? recvNewMessage,
    TResult? Function(String msgReceiptList)? recvC2CReadReceipt,
    TResult? Function(MessageRevoked messageRevoked)? newRecvMessageRevoked,
    TResult? Function(MsgStruct message)? recvOfflineNewMessage,
    TResult? Function(MsgStruct message)? msgDeleted,
    TResult? Function(MsgStruct message)? recvOnlineOnlyMessage,
    TResult? Function()? kickedOffline,
    TResult? Function(TypingStatus typingStatus)? recvTypingStatus,
  }) {
    return recvTypingStatus?.call(typingStatus);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(MsgStruct message)? recvNewMessage,
    TResult Function(String msgReceiptList)? recvC2CReadReceipt,
    TResult Function(MessageRevoked messageRevoked)? newRecvMessageRevoked,
    TResult Function(MsgStruct message)? recvOfflineNewMessage,
    TResult Function(MsgStruct message)? msgDeleted,
    TResult Function(MsgStruct message)? recvOnlineOnlyMessage,
    TResult Function()? kickedOffline,
    TResult Function(TypingStatus typingStatus)? recvTypingStatus,
    required TResult orElse(),
  }) {
    if (recvTypingStatus != null) {
      return recvTypingStatus(typingStatus);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(MessageEvent_RecvNewMessage value) recvNewMessage,
    required TResult Function(MessageEvent_RecvC2CReadReceipt value)
    recvC2CReadReceipt,
    required TResult Function(MessageEvent_NewRecvMessageRevoked value)
    newRecvMessageRevoked,
    required TResult Function(MessageEvent_RecvOfflineNewMessage value)
    recvOfflineNewMessage,
    required TResult Function(MessageEvent_MsgDeleted value) msgDeleted,
    required TResult Function(MessageEvent_RecvOnlineOnlyMessage value)
    recvOnlineOnlyMessage,
    required TResult Function(MessageEvent_KickedOffline value) kickedOffline,
    required TResult Function(MessageEvent_RecvTypingStatus value)
    recvTypingStatus,
  }) {
    return recvTypingStatus(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(MessageEvent_RecvNewMessage value)? recvNewMessage,
    TResult? Function(MessageEvent_RecvC2CReadReceipt value)?
    recvC2CReadReceipt,
    TResult? Function(MessageEvent_NewRecvMessageRevoked value)?
    newRecvMessageRevoked,
    TResult? Function(MessageEvent_RecvOfflineNewMessage value)?
    recvOfflineNewMessage,
    TResult? Function(MessageEvent_MsgDeleted value)? msgDeleted,
    TResult? Function(MessageEvent_RecvOnlineOnlyMessage value)?
    recvOnlineOnlyMessage,
    TResult? Function(MessageEvent_KickedOffline value)? kickedOffline,
    TResult? Function(MessageEvent_RecvTypingStatus value)? recvTypingStatus,
  }) {
    return recvTypingStatus?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(MessageEvent_RecvNewMessage value)? recvNewMessage,
    TResult Function(MessageEvent_RecvC2CReadReceipt value)? recvC2CReadReceipt,
    TResult Function(MessageEvent_NewRecvMessageRevoked value)?
    newRecvMessageRevoked,
    TResult Function(MessageEvent_RecvOfflineNewMessage value)?
    recvOfflineNewMessage,
    TResult Function(MessageEvent_MsgDeleted value)? msgDeleted,
    TResult Function(MessageEvent_RecvOnlineOnlyMessage value)?
    recvOnlineOnlyMessage,
    TResult Function(MessageEvent_KickedOffline value)? kickedOffline,
    TResult Function(MessageEvent_RecvTypingStatus value)? recvTypingStatus,
    required TResult orElse(),
  }) {
    if (recvTypingStatus != null) {
      return recvTypingStatus(this);
    }
    return orElse();
  }
}

abstract class MessageEvent_RecvTypingStatus extends MessageEvent {
  const factory MessageEvent_RecvTypingStatus({
    required final TypingStatus typingStatus,
  }) = _$MessageEvent_RecvTypingStatusImpl;
  const MessageEvent_RecvTypingStatus._() : super._();

  TypingStatus get typingStatus;

  /// Create a copy of MessageEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MessageEvent_RecvTypingStatusImplCopyWith<
    _$MessageEvent_RecvTypingStatusImpl
  >
  get copyWith => throw _privateConstructorUsedError;
}
