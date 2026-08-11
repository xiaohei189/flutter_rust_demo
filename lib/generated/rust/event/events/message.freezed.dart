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
    required TResult Function(String conversationId, MessageInfo message)
    newMessage,
    required TResult Function(String conversationId, MessageInfo message)
    offlineNewMessage,
    required TResult Function(String conversationId, MessageInfo message)
    onlineOnlyMessage,
    required TResult Function(
      String conversationId,
      int seq,
      String clientMsgId,
      String revokerId,
      int revokerRole,
      String revokerNickname,
      int revokeTime,
      int sourceMessageSendTime,
      String sourceMessageSendId,
      String sourceMessageSenderNickname,
      int sessionType,
      bool isAdminRevoke,
    )
    revoked,
    required TResult Function(List<MessageReceipt> receipts) c2CReadReceipt,
    required TResult Function(String conversationId, List<String> clientMsgIds)
    deleted,
    required TResult Function(String clientMsgId, String error) sendFailed,
    required TResult Function(
      String clientMsgId,
      int progress,
      BigInt totalSize,
      BigInt uploadedSize,
    )
    uploadProgress,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String conversationId, MessageInfo message)? newMessage,
    TResult? Function(String conversationId, MessageInfo message)?
    offlineNewMessage,
    TResult? Function(String conversationId, MessageInfo message)?
    onlineOnlyMessage,
    TResult? Function(
      String conversationId,
      int seq,
      String clientMsgId,
      String revokerId,
      int revokerRole,
      String revokerNickname,
      int revokeTime,
      int sourceMessageSendTime,
      String sourceMessageSendId,
      String sourceMessageSenderNickname,
      int sessionType,
      bool isAdminRevoke,
    )?
    revoked,
    TResult? Function(List<MessageReceipt> receipts)? c2CReadReceipt,
    TResult? Function(String conversationId, List<String> clientMsgIds)?
    deleted,
    TResult? Function(String clientMsgId, String error)? sendFailed,
    TResult? Function(
      String clientMsgId,
      int progress,
      BigInt totalSize,
      BigInt uploadedSize,
    )?
    uploadProgress,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String conversationId, MessageInfo message)? newMessage,
    TResult Function(String conversationId, MessageInfo message)?
    offlineNewMessage,
    TResult Function(String conversationId, MessageInfo message)?
    onlineOnlyMessage,
    TResult Function(
      String conversationId,
      int seq,
      String clientMsgId,
      String revokerId,
      int revokerRole,
      String revokerNickname,
      int revokeTime,
      int sourceMessageSendTime,
      String sourceMessageSendId,
      String sourceMessageSenderNickname,
      int sessionType,
      bool isAdminRevoke,
    )?
    revoked,
    TResult Function(List<MessageReceipt> receipts)? c2CReadReceipt,
    TResult Function(String conversationId, List<String> clientMsgIds)? deleted,
    TResult Function(String clientMsgId, String error)? sendFailed,
    TResult Function(
      String clientMsgId,
      int progress,
      BigInt totalSize,
      BigInt uploadedSize,
    )?
    uploadProgress,
    required TResult orElse(),
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(MessageEvent_NewMessage value) newMessage,
    required TResult Function(MessageEvent_OfflineNewMessage value)
    offlineNewMessage,
    required TResult Function(MessageEvent_OnlineOnlyMessage value)
    onlineOnlyMessage,
    required TResult Function(MessageEvent_Revoked value) revoked,
    required TResult Function(MessageEvent_C2CReadReceipt value) c2CReadReceipt,
    required TResult Function(MessageEvent_Deleted value) deleted,
    required TResult Function(MessageEvent_SendFailed value) sendFailed,
    required TResult Function(MessageEvent_UploadProgress value) uploadProgress,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(MessageEvent_NewMessage value)? newMessage,
    TResult? Function(MessageEvent_OfflineNewMessage value)? offlineNewMessage,
    TResult? Function(MessageEvent_OnlineOnlyMessage value)? onlineOnlyMessage,
    TResult? Function(MessageEvent_Revoked value)? revoked,
    TResult? Function(MessageEvent_C2CReadReceipt value)? c2CReadReceipt,
    TResult? Function(MessageEvent_Deleted value)? deleted,
    TResult? Function(MessageEvent_SendFailed value)? sendFailed,
    TResult? Function(MessageEvent_UploadProgress value)? uploadProgress,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(MessageEvent_NewMessage value)? newMessage,
    TResult Function(MessageEvent_OfflineNewMessage value)? offlineNewMessage,
    TResult Function(MessageEvent_OnlineOnlyMessage value)? onlineOnlyMessage,
    TResult Function(MessageEvent_Revoked value)? revoked,
    TResult Function(MessageEvent_C2CReadReceipt value)? c2CReadReceipt,
    TResult Function(MessageEvent_Deleted value)? deleted,
    TResult Function(MessageEvent_SendFailed value)? sendFailed,
    TResult Function(MessageEvent_UploadProgress value)? uploadProgress,
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
abstract class _$$MessageEvent_NewMessageImplCopyWith<$Res> {
  factory _$$MessageEvent_NewMessageImplCopyWith(
    _$MessageEvent_NewMessageImpl value,
    $Res Function(_$MessageEvent_NewMessageImpl) then,
  ) = __$$MessageEvent_NewMessageImplCopyWithImpl<$Res>;
  @useResult
  $Res call({String conversationId, MessageInfo message});
}

/// @nodoc
class __$$MessageEvent_NewMessageImplCopyWithImpl<$Res>
    extends _$MessageEventCopyWithImpl<$Res, _$MessageEvent_NewMessageImpl>
    implements _$$MessageEvent_NewMessageImplCopyWith<$Res> {
  __$$MessageEvent_NewMessageImplCopyWithImpl(
    _$MessageEvent_NewMessageImpl _value,
    $Res Function(_$MessageEvent_NewMessageImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of MessageEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? conversationId = null, Object? message = null}) {
    return _then(
      _$MessageEvent_NewMessageImpl(
        conversationId: null == conversationId
            ? _value.conversationId
            : conversationId // ignore: cast_nullable_to_non_nullable
                  as String,
        message: null == message
            ? _value.message
            : message // ignore: cast_nullable_to_non_nullable
                  as MessageInfo,
      ),
    );
  }
}

/// @nodoc

class _$MessageEvent_NewMessageImpl extends MessageEvent_NewMessage {
  const _$MessageEvent_NewMessageImpl({
    required this.conversationId,
    required this.message,
  }) : super._();

  @override
  final String conversationId;
  @override
  final MessageInfo message;

  @override
  String toString() {
    return 'MessageEvent.newMessage(conversationId: $conversationId, message: $message)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MessageEvent_NewMessageImpl &&
            (identical(other.conversationId, conversationId) ||
                other.conversationId == conversationId) &&
            (identical(other.message, message) || other.message == message));
  }

  @override
  int get hashCode => Object.hash(runtimeType, conversationId, message);

  /// Create a copy of MessageEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MessageEvent_NewMessageImplCopyWith<_$MessageEvent_NewMessageImpl>
  get copyWith =>
      __$$MessageEvent_NewMessageImplCopyWithImpl<
        _$MessageEvent_NewMessageImpl
      >(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String conversationId, MessageInfo message)
    newMessage,
    required TResult Function(String conversationId, MessageInfo message)
    offlineNewMessage,
    required TResult Function(String conversationId, MessageInfo message)
    onlineOnlyMessage,
    required TResult Function(
      String conversationId,
      int seq,
      String clientMsgId,
      String revokerId,
      int revokerRole,
      String revokerNickname,
      int revokeTime,
      int sourceMessageSendTime,
      String sourceMessageSendId,
      String sourceMessageSenderNickname,
      int sessionType,
      bool isAdminRevoke,
    )
    revoked,
    required TResult Function(List<MessageReceipt> receipts) c2CReadReceipt,
    required TResult Function(String conversationId, List<String> clientMsgIds)
    deleted,
    required TResult Function(String clientMsgId, String error) sendFailed,
    required TResult Function(
      String clientMsgId,
      int progress,
      BigInt totalSize,
      BigInt uploadedSize,
    )
    uploadProgress,
  }) {
    return newMessage(conversationId, message);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String conversationId, MessageInfo message)? newMessage,
    TResult? Function(String conversationId, MessageInfo message)?
    offlineNewMessage,
    TResult? Function(String conversationId, MessageInfo message)?
    onlineOnlyMessage,
    TResult? Function(
      String conversationId,
      int seq,
      String clientMsgId,
      String revokerId,
      int revokerRole,
      String revokerNickname,
      int revokeTime,
      int sourceMessageSendTime,
      String sourceMessageSendId,
      String sourceMessageSenderNickname,
      int sessionType,
      bool isAdminRevoke,
    )?
    revoked,
    TResult? Function(List<MessageReceipt> receipts)? c2CReadReceipt,
    TResult? Function(String conversationId, List<String> clientMsgIds)?
    deleted,
    TResult? Function(String clientMsgId, String error)? sendFailed,
    TResult? Function(
      String clientMsgId,
      int progress,
      BigInt totalSize,
      BigInt uploadedSize,
    )?
    uploadProgress,
  }) {
    return newMessage?.call(conversationId, message);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String conversationId, MessageInfo message)? newMessage,
    TResult Function(String conversationId, MessageInfo message)?
    offlineNewMessage,
    TResult Function(String conversationId, MessageInfo message)?
    onlineOnlyMessage,
    TResult Function(
      String conversationId,
      int seq,
      String clientMsgId,
      String revokerId,
      int revokerRole,
      String revokerNickname,
      int revokeTime,
      int sourceMessageSendTime,
      String sourceMessageSendId,
      String sourceMessageSenderNickname,
      int sessionType,
      bool isAdminRevoke,
    )?
    revoked,
    TResult Function(List<MessageReceipt> receipts)? c2CReadReceipt,
    TResult Function(String conversationId, List<String> clientMsgIds)? deleted,
    TResult Function(String clientMsgId, String error)? sendFailed,
    TResult Function(
      String clientMsgId,
      int progress,
      BigInt totalSize,
      BigInt uploadedSize,
    )?
    uploadProgress,
    required TResult orElse(),
  }) {
    if (newMessage != null) {
      return newMessage(conversationId, message);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(MessageEvent_NewMessage value) newMessage,
    required TResult Function(MessageEvent_OfflineNewMessage value)
    offlineNewMessage,
    required TResult Function(MessageEvent_OnlineOnlyMessage value)
    onlineOnlyMessage,
    required TResult Function(MessageEvent_Revoked value) revoked,
    required TResult Function(MessageEvent_C2CReadReceipt value) c2CReadReceipt,
    required TResult Function(MessageEvent_Deleted value) deleted,
    required TResult Function(MessageEvent_SendFailed value) sendFailed,
    required TResult Function(MessageEvent_UploadProgress value) uploadProgress,
  }) {
    return newMessage(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(MessageEvent_NewMessage value)? newMessage,
    TResult? Function(MessageEvent_OfflineNewMessage value)? offlineNewMessage,
    TResult? Function(MessageEvent_OnlineOnlyMessage value)? onlineOnlyMessage,
    TResult? Function(MessageEvent_Revoked value)? revoked,
    TResult? Function(MessageEvent_C2CReadReceipt value)? c2CReadReceipt,
    TResult? Function(MessageEvent_Deleted value)? deleted,
    TResult? Function(MessageEvent_SendFailed value)? sendFailed,
    TResult? Function(MessageEvent_UploadProgress value)? uploadProgress,
  }) {
    return newMessage?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(MessageEvent_NewMessage value)? newMessage,
    TResult Function(MessageEvent_OfflineNewMessage value)? offlineNewMessage,
    TResult Function(MessageEvent_OnlineOnlyMessage value)? onlineOnlyMessage,
    TResult Function(MessageEvent_Revoked value)? revoked,
    TResult Function(MessageEvent_C2CReadReceipt value)? c2CReadReceipt,
    TResult Function(MessageEvent_Deleted value)? deleted,
    TResult Function(MessageEvent_SendFailed value)? sendFailed,
    TResult Function(MessageEvent_UploadProgress value)? uploadProgress,
    required TResult orElse(),
  }) {
    if (newMessage != null) {
      return newMessage(this);
    }
    return orElse();
  }
}

abstract class MessageEvent_NewMessage extends MessageEvent {
  const factory MessageEvent_NewMessage({
    required final String conversationId,
    required final MessageInfo message,
  }) = _$MessageEvent_NewMessageImpl;
  const MessageEvent_NewMessage._() : super._();

  String get conversationId;
  MessageInfo get message;

  /// Create a copy of MessageEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MessageEvent_NewMessageImplCopyWith<_$MessageEvent_NewMessageImpl>
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$MessageEvent_OfflineNewMessageImplCopyWith<$Res> {
  factory _$$MessageEvent_OfflineNewMessageImplCopyWith(
    _$MessageEvent_OfflineNewMessageImpl value,
    $Res Function(_$MessageEvent_OfflineNewMessageImpl) then,
  ) = __$$MessageEvent_OfflineNewMessageImplCopyWithImpl<$Res>;
  @useResult
  $Res call({String conversationId, MessageInfo message});
}

/// @nodoc
class __$$MessageEvent_OfflineNewMessageImplCopyWithImpl<$Res>
    extends
        _$MessageEventCopyWithImpl<$Res, _$MessageEvent_OfflineNewMessageImpl>
    implements _$$MessageEvent_OfflineNewMessageImplCopyWith<$Res> {
  __$$MessageEvent_OfflineNewMessageImplCopyWithImpl(
    _$MessageEvent_OfflineNewMessageImpl _value,
    $Res Function(_$MessageEvent_OfflineNewMessageImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of MessageEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? conversationId = null, Object? message = null}) {
    return _then(
      _$MessageEvent_OfflineNewMessageImpl(
        conversationId: null == conversationId
            ? _value.conversationId
            : conversationId // ignore: cast_nullable_to_non_nullable
                  as String,
        message: null == message
            ? _value.message
            : message // ignore: cast_nullable_to_non_nullable
                  as MessageInfo,
      ),
    );
  }
}

/// @nodoc

class _$MessageEvent_OfflineNewMessageImpl
    extends MessageEvent_OfflineNewMessage {
  const _$MessageEvent_OfflineNewMessageImpl({
    required this.conversationId,
    required this.message,
  }) : super._();

  @override
  final String conversationId;
  @override
  final MessageInfo message;

  @override
  String toString() {
    return 'MessageEvent.offlineNewMessage(conversationId: $conversationId, message: $message)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MessageEvent_OfflineNewMessageImpl &&
            (identical(other.conversationId, conversationId) ||
                other.conversationId == conversationId) &&
            (identical(other.message, message) || other.message == message));
  }

  @override
  int get hashCode => Object.hash(runtimeType, conversationId, message);

  /// Create a copy of MessageEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MessageEvent_OfflineNewMessageImplCopyWith<
    _$MessageEvent_OfflineNewMessageImpl
  >
  get copyWith =>
      __$$MessageEvent_OfflineNewMessageImplCopyWithImpl<
        _$MessageEvent_OfflineNewMessageImpl
      >(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String conversationId, MessageInfo message)
    newMessage,
    required TResult Function(String conversationId, MessageInfo message)
    offlineNewMessage,
    required TResult Function(String conversationId, MessageInfo message)
    onlineOnlyMessage,
    required TResult Function(
      String conversationId,
      int seq,
      String clientMsgId,
      String revokerId,
      int revokerRole,
      String revokerNickname,
      int revokeTime,
      int sourceMessageSendTime,
      String sourceMessageSendId,
      String sourceMessageSenderNickname,
      int sessionType,
      bool isAdminRevoke,
    )
    revoked,
    required TResult Function(List<MessageReceipt> receipts) c2CReadReceipt,
    required TResult Function(String conversationId, List<String> clientMsgIds)
    deleted,
    required TResult Function(String clientMsgId, String error) sendFailed,
    required TResult Function(
      String clientMsgId,
      int progress,
      BigInt totalSize,
      BigInt uploadedSize,
    )
    uploadProgress,
  }) {
    return offlineNewMessage(conversationId, message);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String conversationId, MessageInfo message)? newMessage,
    TResult? Function(String conversationId, MessageInfo message)?
    offlineNewMessage,
    TResult? Function(String conversationId, MessageInfo message)?
    onlineOnlyMessage,
    TResult? Function(
      String conversationId,
      int seq,
      String clientMsgId,
      String revokerId,
      int revokerRole,
      String revokerNickname,
      int revokeTime,
      int sourceMessageSendTime,
      String sourceMessageSendId,
      String sourceMessageSenderNickname,
      int sessionType,
      bool isAdminRevoke,
    )?
    revoked,
    TResult? Function(List<MessageReceipt> receipts)? c2CReadReceipt,
    TResult? Function(String conversationId, List<String> clientMsgIds)?
    deleted,
    TResult? Function(String clientMsgId, String error)? sendFailed,
    TResult? Function(
      String clientMsgId,
      int progress,
      BigInt totalSize,
      BigInt uploadedSize,
    )?
    uploadProgress,
  }) {
    return offlineNewMessage?.call(conversationId, message);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String conversationId, MessageInfo message)? newMessage,
    TResult Function(String conversationId, MessageInfo message)?
    offlineNewMessage,
    TResult Function(String conversationId, MessageInfo message)?
    onlineOnlyMessage,
    TResult Function(
      String conversationId,
      int seq,
      String clientMsgId,
      String revokerId,
      int revokerRole,
      String revokerNickname,
      int revokeTime,
      int sourceMessageSendTime,
      String sourceMessageSendId,
      String sourceMessageSenderNickname,
      int sessionType,
      bool isAdminRevoke,
    )?
    revoked,
    TResult Function(List<MessageReceipt> receipts)? c2CReadReceipt,
    TResult Function(String conversationId, List<String> clientMsgIds)? deleted,
    TResult Function(String clientMsgId, String error)? sendFailed,
    TResult Function(
      String clientMsgId,
      int progress,
      BigInt totalSize,
      BigInt uploadedSize,
    )?
    uploadProgress,
    required TResult orElse(),
  }) {
    if (offlineNewMessage != null) {
      return offlineNewMessage(conversationId, message);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(MessageEvent_NewMessage value) newMessage,
    required TResult Function(MessageEvent_OfflineNewMessage value)
    offlineNewMessage,
    required TResult Function(MessageEvent_OnlineOnlyMessage value)
    onlineOnlyMessage,
    required TResult Function(MessageEvent_Revoked value) revoked,
    required TResult Function(MessageEvent_C2CReadReceipt value) c2CReadReceipt,
    required TResult Function(MessageEvent_Deleted value) deleted,
    required TResult Function(MessageEvent_SendFailed value) sendFailed,
    required TResult Function(MessageEvent_UploadProgress value) uploadProgress,
  }) {
    return offlineNewMessage(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(MessageEvent_NewMessage value)? newMessage,
    TResult? Function(MessageEvent_OfflineNewMessage value)? offlineNewMessage,
    TResult? Function(MessageEvent_OnlineOnlyMessage value)? onlineOnlyMessage,
    TResult? Function(MessageEvent_Revoked value)? revoked,
    TResult? Function(MessageEvent_C2CReadReceipt value)? c2CReadReceipt,
    TResult? Function(MessageEvent_Deleted value)? deleted,
    TResult? Function(MessageEvent_SendFailed value)? sendFailed,
    TResult? Function(MessageEvent_UploadProgress value)? uploadProgress,
  }) {
    return offlineNewMessage?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(MessageEvent_NewMessage value)? newMessage,
    TResult Function(MessageEvent_OfflineNewMessage value)? offlineNewMessage,
    TResult Function(MessageEvent_OnlineOnlyMessage value)? onlineOnlyMessage,
    TResult Function(MessageEvent_Revoked value)? revoked,
    TResult Function(MessageEvent_C2CReadReceipt value)? c2CReadReceipt,
    TResult Function(MessageEvent_Deleted value)? deleted,
    TResult Function(MessageEvent_SendFailed value)? sendFailed,
    TResult Function(MessageEvent_UploadProgress value)? uploadProgress,
    required TResult orElse(),
  }) {
    if (offlineNewMessage != null) {
      return offlineNewMessage(this);
    }
    return orElse();
  }
}

abstract class MessageEvent_OfflineNewMessage extends MessageEvent {
  const factory MessageEvent_OfflineNewMessage({
    required final String conversationId,
    required final MessageInfo message,
  }) = _$MessageEvent_OfflineNewMessageImpl;
  const MessageEvent_OfflineNewMessage._() : super._();

  String get conversationId;
  MessageInfo get message;

  /// Create a copy of MessageEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MessageEvent_OfflineNewMessageImplCopyWith<
    _$MessageEvent_OfflineNewMessageImpl
  >
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$MessageEvent_OnlineOnlyMessageImplCopyWith<$Res> {
  factory _$$MessageEvent_OnlineOnlyMessageImplCopyWith(
    _$MessageEvent_OnlineOnlyMessageImpl value,
    $Res Function(_$MessageEvent_OnlineOnlyMessageImpl) then,
  ) = __$$MessageEvent_OnlineOnlyMessageImplCopyWithImpl<$Res>;
  @useResult
  $Res call({String conversationId, MessageInfo message});
}

/// @nodoc
class __$$MessageEvent_OnlineOnlyMessageImplCopyWithImpl<$Res>
    extends
        _$MessageEventCopyWithImpl<$Res, _$MessageEvent_OnlineOnlyMessageImpl>
    implements _$$MessageEvent_OnlineOnlyMessageImplCopyWith<$Res> {
  __$$MessageEvent_OnlineOnlyMessageImplCopyWithImpl(
    _$MessageEvent_OnlineOnlyMessageImpl _value,
    $Res Function(_$MessageEvent_OnlineOnlyMessageImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of MessageEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? conversationId = null, Object? message = null}) {
    return _then(
      _$MessageEvent_OnlineOnlyMessageImpl(
        conversationId: null == conversationId
            ? _value.conversationId
            : conversationId // ignore: cast_nullable_to_non_nullable
                  as String,
        message: null == message
            ? _value.message
            : message // ignore: cast_nullable_to_non_nullable
                  as MessageInfo,
      ),
    );
  }
}

/// @nodoc

class _$MessageEvent_OnlineOnlyMessageImpl
    extends MessageEvent_OnlineOnlyMessage {
  const _$MessageEvent_OnlineOnlyMessageImpl({
    required this.conversationId,
    required this.message,
  }) : super._();

  @override
  final String conversationId;
  @override
  final MessageInfo message;

  @override
  String toString() {
    return 'MessageEvent.onlineOnlyMessage(conversationId: $conversationId, message: $message)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MessageEvent_OnlineOnlyMessageImpl &&
            (identical(other.conversationId, conversationId) ||
                other.conversationId == conversationId) &&
            (identical(other.message, message) || other.message == message));
  }

  @override
  int get hashCode => Object.hash(runtimeType, conversationId, message);

  /// Create a copy of MessageEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MessageEvent_OnlineOnlyMessageImplCopyWith<
    _$MessageEvent_OnlineOnlyMessageImpl
  >
  get copyWith =>
      __$$MessageEvent_OnlineOnlyMessageImplCopyWithImpl<
        _$MessageEvent_OnlineOnlyMessageImpl
      >(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String conversationId, MessageInfo message)
    newMessage,
    required TResult Function(String conversationId, MessageInfo message)
    offlineNewMessage,
    required TResult Function(String conversationId, MessageInfo message)
    onlineOnlyMessage,
    required TResult Function(
      String conversationId,
      int seq,
      String clientMsgId,
      String revokerId,
      int revokerRole,
      String revokerNickname,
      int revokeTime,
      int sourceMessageSendTime,
      String sourceMessageSendId,
      String sourceMessageSenderNickname,
      int sessionType,
      bool isAdminRevoke,
    )
    revoked,
    required TResult Function(List<MessageReceipt> receipts) c2CReadReceipt,
    required TResult Function(String conversationId, List<String> clientMsgIds)
    deleted,
    required TResult Function(String clientMsgId, String error) sendFailed,
    required TResult Function(
      String clientMsgId,
      int progress,
      BigInt totalSize,
      BigInt uploadedSize,
    )
    uploadProgress,
  }) {
    return onlineOnlyMessage(conversationId, message);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String conversationId, MessageInfo message)? newMessage,
    TResult? Function(String conversationId, MessageInfo message)?
    offlineNewMessage,
    TResult? Function(String conversationId, MessageInfo message)?
    onlineOnlyMessage,
    TResult? Function(
      String conversationId,
      int seq,
      String clientMsgId,
      String revokerId,
      int revokerRole,
      String revokerNickname,
      int revokeTime,
      int sourceMessageSendTime,
      String sourceMessageSendId,
      String sourceMessageSenderNickname,
      int sessionType,
      bool isAdminRevoke,
    )?
    revoked,
    TResult? Function(List<MessageReceipt> receipts)? c2CReadReceipt,
    TResult? Function(String conversationId, List<String> clientMsgIds)?
    deleted,
    TResult? Function(String clientMsgId, String error)? sendFailed,
    TResult? Function(
      String clientMsgId,
      int progress,
      BigInt totalSize,
      BigInt uploadedSize,
    )?
    uploadProgress,
  }) {
    return onlineOnlyMessage?.call(conversationId, message);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String conversationId, MessageInfo message)? newMessage,
    TResult Function(String conversationId, MessageInfo message)?
    offlineNewMessage,
    TResult Function(String conversationId, MessageInfo message)?
    onlineOnlyMessage,
    TResult Function(
      String conversationId,
      int seq,
      String clientMsgId,
      String revokerId,
      int revokerRole,
      String revokerNickname,
      int revokeTime,
      int sourceMessageSendTime,
      String sourceMessageSendId,
      String sourceMessageSenderNickname,
      int sessionType,
      bool isAdminRevoke,
    )?
    revoked,
    TResult Function(List<MessageReceipt> receipts)? c2CReadReceipt,
    TResult Function(String conversationId, List<String> clientMsgIds)? deleted,
    TResult Function(String clientMsgId, String error)? sendFailed,
    TResult Function(
      String clientMsgId,
      int progress,
      BigInt totalSize,
      BigInt uploadedSize,
    )?
    uploadProgress,
    required TResult orElse(),
  }) {
    if (onlineOnlyMessage != null) {
      return onlineOnlyMessage(conversationId, message);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(MessageEvent_NewMessage value) newMessage,
    required TResult Function(MessageEvent_OfflineNewMessage value)
    offlineNewMessage,
    required TResult Function(MessageEvent_OnlineOnlyMessage value)
    onlineOnlyMessage,
    required TResult Function(MessageEvent_Revoked value) revoked,
    required TResult Function(MessageEvent_C2CReadReceipt value) c2CReadReceipt,
    required TResult Function(MessageEvent_Deleted value) deleted,
    required TResult Function(MessageEvent_SendFailed value) sendFailed,
    required TResult Function(MessageEvent_UploadProgress value) uploadProgress,
  }) {
    return onlineOnlyMessage(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(MessageEvent_NewMessage value)? newMessage,
    TResult? Function(MessageEvent_OfflineNewMessage value)? offlineNewMessage,
    TResult? Function(MessageEvent_OnlineOnlyMessage value)? onlineOnlyMessage,
    TResult? Function(MessageEvent_Revoked value)? revoked,
    TResult? Function(MessageEvent_C2CReadReceipt value)? c2CReadReceipt,
    TResult? Function(MessageEvent_Deleted value)? deleted,
    TResult? Function(MessageEvent_SendFailed value)? sendFailed,
    TResult? Function(MessageEvent_UploadProgress value)? uploadProgress,
  }) {
    return onlineOnlyMessage?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(MessageEvent_NewMessage value)? newMessage,
    TResult Function(MessageEvent_OfflineNewMessage value)? offlineNewMessage,
    TResult Function(MessageEvent_OnlineOnlyMessage value)? onlineOnlyMessage,
    TResult Function(MessageEvent_Revoked value)? revoked,
    TResult Function(MessageEvent_C2CReadReceipt value)? c2CReadReceipt,
    TResult Function(MessageEvent_Deleted value)? deleted,
    TResult Function(MessageEvent_SendFailed value)? sendFailed,
    TResult Function(MessageEvent_UploadProgress value)? uploadProgress,
    required TResult orElse(),
  }) {
    if (onlineOnlyMessage != null) {
      return onlineOnlyMessage(this);
    }
    return orElse();
  }
}

abstract class MessageEvent_OnlineOnlyMessage extends MessageEvent {
  const factory MessageEvent_OnlineOnlyMessage({
    required final String conversationId,
    required final MessageInfo message,
  }) = _$MessageEvent_OnlineOnlyMessageImpl;
  const MessageEvent_OnlineOnlyMessage._() : super._();

  String get conversationId;
  MessageInfo get message;

  /// Create a copy of MessageEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MessageEvent_OnlineOnlyMessageImplCopyWith<
    _$MessageEvent_OnlineOnlyMessageImpl
  >
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$MessageEvent_RevokedImplCopyWith<$Res> {
  factory _$$MessageEvent_RevokedImplCopyWith(
    _$MessageEvent_RevokedImpl value,
    $Res Function(_$MessageEvent_RevokedImpl) then,
  ) = __$$MessageEvent_RevokedImplCopyWithImpl<$Res>;
  @useResult
  $Res call({
    String conversationId,
    int seq,
    String clientMsgId,
    String revokerId,
    int revokerRole,
    String revokerNickname,
    int revokeTime,
    int sourceMessageSendTime,
    String sourceMessageSendId,
    String sourceMessageSenderNickname,
    int sessionType,
    bool isAdminRevoke,
  });
}

/// @nodoc
class __$$MessageEvent_RevokedImplCopyWithImpl<$Res>
    extends _$MessageEventCopyWithImpl<$Res, _$MessageEvent_RevokedImpl>
    implements _$$MessageEvent_RevokedImplCopyWith<$Res> {
  __$$MessageEvent_RevokedImplCopyWithImpl(
    _$MessageEvent_RevokedImpl _value,
    $Res Function(_$MessageEvent_RevokedImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of MessageEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? conversationId = null,
    Object? seq = null,
    Object? clientMsgId = null,
    Object? revokerId = null,
    Object? revokerRole = null,
    Object? revokerNickname = null,
    Object? revokeTime = null,
    Object? sourceMessageSendTime = null,
    Object? sourceMessageSendId = null,
    Object? sourceMessageSenderNickname = null,
    Object? sessionType = null,
    Object? isAdminRevoke = null,
  }) {
    return _then(
      _$MessageEvent_RevokedImpl(
        conversationId: null == conversationId
            ? _value.conversationId
            : conversationId // ignore: cast_nullable_to_non_nullable
                  as String,
        seq: null == seq
            ? _value.seq
            : seq // ignore: cast_nullable_to_non_nullable
                  as int,
        clientMsgId: null == clientMsgId
            ? _value.clientMsgId
            : clientMsgId // ignore: cast_nullable_to_non_nullable
                  as String,
        revokerId: null == revokerId
            ? _value.revokerId
            : revokerId // ignore: cast_nullable_to_non_nullable
                  as String,
        revokerRole: null == revokerRole
            ? _value.revokerRole
            : revokerRole // ignore: cast_nullable_to_non_nullable
                  as int,
        revokerNickname: null == revokerNickname
            ? _value.revokerNickname
            : revokerNickname // ignore: cast_nullable_to_non_nullable
                  as String,
        revokeTime: null == revokeTime
            ? _value.revokeTime
            : revokeTime // ignore: cast_nullable_to_non_nullable
                  as int,
        sourceMessageSendTime: null == sourceMessageSendTime
            ? _value.sourceMessageSendTime
            : sourceMessageSendTime // ignore: cast_nullable_to_non_nullable
                  as int,
        sourceMessageSendId: null == sourceMessageSendId
            ? _value.sourceMessageSendId
            : sourceMessageSendId // ignore: cast_nullable_to_non_nullable
                  as String,
        sourceMessageSenderNickname: null == sourceMessageSenderNickname
            ? _value.sourceMessageSenderNickname
            : sourceMessageSenderNickname // ignore: cast_nullable_to_non_nullable
                  as String,
        sessionType: null == sessionType
            ? _value.sessionType
            : sessionType // ignore: cast_nullable_to_non_nullable
                  as int,
        isAdminRevoke: null == isAdminRevoke
            ? _value.isAdminRevoke
            : isAdminRevoke // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// @nodoc

class _$MessageEvent_RevokedImpl extends MessageEvent_Revoked {
  const _$MessageEvent_RevokedImpl({
    required this.conversationId,
    required this.seq,
    required this.clientMsgId,
    required this.revokerId,
    required this.revokerRole,
    required this.revokerNickname,
    required this.revokeTime,
    required this.sourceMessageSendTime,
    required this.sourceMessageSendId,
    required this.sourceMessageSenderNickname,
    required this.sessionType,
    required this.isAdminRevoke,
  }) : super._();

  @override
  final String conversationId;
  @override
  final int seq;
  @override
  final String clientMsgId;
  @override
  final String revokerId;
  @override
  final int revokerRole;
  @override
  final String revokerNickname;
  @override
  final int revokeTime;
  @override
  final int sourceMessageSendTime;
  @override
  final String sourceMessageSendId;
  @override
  final String sourceMessageSenderNickname;
  @override
  final int sessionType;
  @override
  final bool isAdminRevoke;

  @override
  String toString() {
    return 'MessageEvent.revoked(conversationId: $conversationId, seq: $seq, clientMsgId: $clientMsgId, revokerId: $revokerId, revokerRole: $revokerRole, revokerNickname: $revokerNickname, revokeTime: $revokeTime, sourceMessageSendTime: $sourceMessageSendTime, sourceMessageSendId: $sourceMessageSendId, sourceMessageSenderNickname: $sourceMessageSenderNickname, sessionType: $sessionType, isAdminRevoke: $isAdminRevoke)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MessageEvent_RevokedImpl &&
            (identical(other.conversationId, conversationId) ||
                other.conversationId == conversationId) &&
            (identical(other.seq, seq) || other.seq == seq) &&
            (identical(other.clientMsgId, clientMsgId) ||
                other.clientMsgId == clientMsgId) &&
            (identical(other.revokerId, revokerId) ||
                other.revokerId == revokerId) &&
            (identical(other.revokerRole, revokerRole) ||
                other.revokerRole == revokerRole) &&
            (identical(other.revokerNickname, revokerNickname) ||
                other.revokerNickname == revokerNickname) &&
            (identical(other.revokeTime, revokeTime) ||
                other.revokeTime == revokeTime) &&
            (identical(other.sourceMessageSendTime, sourceMessageSendTime) ||
                other.sourceMessageSendTime == sourceMessageSendTime) &&
            (identical(other.sourceMessageSendId, sourceMessageSendId) ||
                other.sourceMessageSendId == sourceMessageSendId) &&
            (identical(
                  other.sourceMessageSenderNickname,
                  sourceMessageSenderNickname,
                ) ||
                other.sourceMessageSenderNickname ==
                    sourceMessageSenderNickname) &&
            (identical(other.sessionType, sessionType) ||
                other.sessionType == sessionType) &&
            (identical(other.isAdminRevoke, isAdminRevoke) ||
                other.isAdminRevoke == isAdminRevoke));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    conversationId,
    seq,
    clientMsgId,
    revokerId,
    revokerRole,
    revokerNickname,
    revokeTime,
    sourceMessageSendTime,
    sourceMessageSendId,
    sourceMessageSenderNickname,
    sessionType,
    isAdminRevoke,
  );

  /// Create a copy of MessageEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MessageEvent_RevokedImplCopyWith<_$MessageEvent_RevokedImpl>
  get copyWith =>
      __$$MessageEvent_RevokedImplCopyWithImpl<_$MessageEvent_RevokedImpl>(
        this,
        _$identity,
      );

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String conversationId, MessageInfo message)
    newMessage,
    required TResult Function(String conversationId, MessageInfo message)
    offlineNewMessage,
    required TResult Function(String conversationId, MessageInfo message)
    onlineOnlyMessage,
    required TResult Function(
      String conversationId,
      int seq,
      String clientMsgId,
      String revokerId,
      int revokerRole,
      String revokerNickname,
      int revokeTime,
      int sourceMessageSendTime,
      String sourceMessageSendId,
      String sourceMessageSenderNickname,
      int sessionType,
      bool isAdminRevoke,
    )
    revoked,
    required TResult Function(List<MessageReceipt> receipts) c2CReadReceipt,
    required TResult Function(String conversationId, List<String> clientMsgIds)
    deleted,
    required TResult Function(String clientMsgId, String error) sendFailed,
    required TResult Function(
      String clientMsgId,
      int progress,
      BigInt totalSize,
      BigInt uploadedSize,
    )
    uploadProgress,
  }) {
    return revoked(
      conversationId,
      seq,
      clientMsgId,
      revokerId,
      revokerRole,
      revokerNickname,
      revokeTime,
      sourceMessageSendTime,
      sourceMessageSendId,
      sourceMessageSenderNickname,
      sessionType,
      isAdminRevoke,
    );
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String conversationId, MessageInfo message)? newMessage,
    TResult? Function(String conversationId, MessageInfo message)?
    offlineNewMessage,
    TResult? Function(String conversationId, MessageInfo message)?
    onlineOnlyMessage,
    TResult? Function(
      String conversationId,
      int seq,
      String clientMsgId,
      String revokerId,
      int revokerRole,
      String revokerNickname,
      int revokeTime,
      int sourceMessageSendTime,
      String sourceMessageSendId,
      String sourceMessageSenderNickname,
      int sessionType,
      bool isAdminRevoke,
    )?
    revoked,
    TResult? Function(List<MessageReceipt> receipts)? c2CReadReceipt,
    TResult? Function(String conversationId, List<String> clientMsgIds)?
    deleted,
    TResult? Function(String clientMsgId, String error)? sendFailed,
    TResult? Function(
      String clientMsgId,
      int progress,
      BigInt totalSize,
      BigInt uploadedSize,
    )?
    uploadProgress,
  }) {
    return revoked?.call(
      conversationId,
      seq,
      clientMsgId,
      revokerId,
      revokerRole,
      revokerNickname,
      revokeTime,
      sourceMessageSendTime,
      sourceMessageSendId,
      sourceMessageSenderNickname,
      sessionType,
      isAdminRevoke,
    );
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String conversationId, MessageInfo message)? newMessage,
    TResult Function(String conversationId, MessageInfo message)?
    offlineNewMessage,
    TResult Function(String conversationId, MessageInfo message)?
    onlineOnlyMessage,
    TResult Function(
      String conversationId,
      int seq,
      String clientMsgId,
      String revokerId,
      int revokerRole,
      String revokerNickname,
      int revokeTime,
      int sourceMessageSendTime,
      String sourceMessageSendId,
      String sourceMessageSenderNickname,
      int sessionType,
      bool isAdminRevoke,
    )?
    revoked,
    TResult Function(List<MessageReceipt> receipts)? c2CReadReceipt,
    TResult Function(String conversationId, List<String> clientMsgIds)? deleted,
    TResult Function(String clientMsgId, String error)? sendFailed,
    TResult Function(
      String clientMsgId,
      int progress,
      BigInt totalSize,
      BigInt uploadedSize,
    )?
    uploadProgress,
    required TResult orElse(),
  }) {
    if (revoked != null) {
      return revoked(
        conversationId,
        seq,
        clientMsgId,
        revokerId,
        revokerRole,
        revokerNickname,
        revokeTime,
        sourceMessageSendTime,
        sourceMessageSendId,
        sourceMessageSenderNickname,
        sessionType,
        isAdminRevoke,
      );
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(MessageEvent_NewMessage value) newMessage,
    required TResult Function(MessageEvent_OfflineNewMessage value)
    offlineNewMessage,
    required TResult Function(MessageEvent_OnlineOnlyMessage value)
    onlineOnlyMessage,
    required TResult Function(MessageEvent_Revoked value) revoked,
    required TResult Function(MessageEvent_C2CReadReceipt value) c2CReadReceipt,
    required TResult Function(MessageEvent_Deleted value) deleted,
    required TResult Function(MessageEvent_SendFailed value) sendFailed,
    required TResult Function(MessageEvent_UploadProgress value) uploadProgress,
  }) {
    return revoked(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(MessageEvent_NewMessage value)? newMessage,
    TResult? Function(MessageEvent_OfflineNewMessage value)? offlineNewMessage,
    TResult? Function(MessageEvent_OnlineOnlyMessage value)? onlineOnlyMessage,
    TResult? Function(MessageEvent_Revoked value)? revoked,
    TResult? Function(MessageEvent_C2CReadReceipt value)? c2CReadReceipt,
    TResult? Function(MessageEvent_Deleted value)? deleted,
    TResult? Function(MessageEvent_SendFailed value)? sendFailed,
    TResult? Function(MessageEvent_UploadProgress value)? uploadProgress,
  }) {
    return revoked?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(MessageEvent_NewMessage value)? newMessage,
    TResult Function(MessageEvent_OfflineNewMessage value)? offlineNewMessage,
    TResult Function(MessageEvent_OnlineOnlyMessage value)? onlineOnlyMessage,
    TResult Function(MessageEvent_Revoked value)? revoked,
    TResult Function(MessageEvent_C2CReadReceipt value)? c2CReadReceipt,
    TResult Function(MessageEvent_Deleted value)? deleted,
    TResult Function(MessageEvent_SendFailed value)? sendFailed,
    TResult Function(MessageEvent_UploadProgress value)? uploadProgress,
    required TResult orElse(),
  }) {
    if (revoked != null) {
      return revoked(this);
    }
    return orElse();
  }
}

abstract class MessageEvent_Revoked extends MessageEvent {
  const factory MessageEvent_Revoked({
    required final String conversationId,
    required final int seq,
    required final String clientMsgId,
    required final String revokerId,
    required final int revokerRole,
    required final String revokerNickname,
    required final int revokeTime,
    required final int sourceMessageSendTime,
    required final String sourceMessageSendId,
    required final String sourceMessageSenderNickname,
    required final int sessionType,
    required final bool isAdminRevoke,
  }) = _$MessageEvent_RevokedImpl;
  const MessageEvent_Revoked._() : super._();

  String get conversationId;
  int get seq;
  String get clientMsgId;
  String get revokerId;
  int get revokerRole;
  String get revokerNickname;
  int get revokeTime;
  int get sourceMessageSendTime;
  String get sourceMessageSendId;
  String get sourceMessageSenderNickname;
  int get sessionType;
  bool get isAdminRevoke;

  /// Create a copy of MessageEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MessageEvent_RevokedImplCopyWith<_$MessageEvent_RevokedImpl>
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$MessageEvent_C2CReadReceiptImplCopyWith<$Res> {
  factory _$$MessageEvent_C2CReadReceiptImplCopyWith(
    _$MessageEvent_C2CReadReceiptImpl value,
    $Res Function(_$MessageEvent_C2CReadReceiptImpl) then,
  ) = __$$MessageEvent_C2CReadReceiptImplCopyWithImpl<$Res>;
  @useResult
  $Res call({List<MessageReceipt> receipts});
}

/// @nodoc
class __$$MessageEvent_C2CReadReceiptImplCopyWithImpl<$Res>
    extends _$MessageEventCopyWithImpl<$Res, _$MessageEvent_C2CReadReceiptImpl>
    implements _$$MessageEvent_C2CReadReceiptImplCopyWith<$Res> {
  __$$MessageEvent_C2CReadReceiptImplCopyWithImpl(
    _$MessageEvent_C2CReadReceiptImpl _value,
    $Res Function(_$MessageEvent_C2CReadReceiptImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of MessageEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? receipts = null}) {
    return _then(
      _$MessageEvent_C2CReadReceiptImpl(
        receipts: null == receipts
            ? _value._receipts
            : receipts // ignore: cast_nullable_to_non_nullable
                  as List<MessageReceipt>,
      ),
    );
  }
}

/// @nodoc

class _$MessageEvent_C2CReadReceiptImpl extends MessageEvent_C2CReadReceipt {
  const _$MessageEvent_C2CReadReceiptImpl({
    required final List<MessageReceipt> receipts,
  }) : _receipts = receipts,
       super._();

  final List<MessageReceipt> _receipts;
  @override
  List<MessageReceipt> get receipts {
    if (_receipts is EqualUnmodifiableListView) return _receipts;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_receipts);
  }

  @override
  String toString() {
    return 'MessageEvent.c2CReadReceipt(receipts: $receipts)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MessageEvent_C2CReadReceiptImpl &&
            const DeepCollectionEquality().equals(other._receipts, _receipts));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, const DeepCollectionEquality().hash(_receipts));

  /// Create a copy of MessageEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MessageEvent_C2CReadReceiptImplCopyWith<_$MessageEvent_C2CReadReceiptImpl>
  get copyWith =>
      __$$MessageEvent_C2CReadReceiptImplCopyWithImpl<
        _$MessageEvent_C2CReadReceiptImpl
      >(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String conversationId, MessageInfo message)
    newMessage,
    required TResult Function(String conversationId, MessageInfo message)
    offlineNewMessage,
    required TResult Function(String conversationId, MessageInfo message)
    onlineOnlyMessage,
    required TResult Function(
      String conversationId,
      int seq,
      String clientMsgId,
      String revokerId,
      int revokerRole,
      String revokerNickname,
      int revokeTime,
      int sourceMessageSendTime,
      String sourceMessageSendId,
      String sourceMessageSenderNickname,
      int sessionType,
      bool isAdminRevoke,
    )
    revoked,
    required TResult Function(List<MessageReceipt> receipts) c2CReadReceipt,
    required TResult Function(String conversationId, List<String> clientMsgIds)
    deleted,
    required TResult Function(String clientMsgId, String error) sendFailed,
    required TResult Function(
      String clientMsgId,
      int progress,
      BigInt totalSize,
      BigInt uploadedSize,
    )
    uploadProgress,
  }) {
    return c2CReadReceipt(receipts);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String conversationId, MessageInfo message)? newMessage,
    TResult? Function(String conversationId, MessageInfo message)?
    offlineNewMessage,
    TResult? Function(String conversationId, MessageInfo message)?
    onlineOnlyMessage,
    TResult? Function(
      String conversationId,
      int seq,
      String clientMsgId,
      String revokerId,
      int revokerRole,
      String revokerNickname,
      int revokeTime,
      int sourceMessageSendTime,
      String sourceMessageSendId,
      String sourceMessageSenderNickname,
      int sessionType,
      bool isAdminRevoke,
    )?
    revoked,
    TResult? Function(List<MessageReceipt> receipts)? c2CReadReceipt,
    TResult? Function(String conversationId, List<String> clientMsgIds)?
    deleted,
    TResult? Function(String clientMsgId, String error)? sendFailed,
    TResult? Function(
      String clientMsgId,
      int progress,
      BigInt totalSize,
      BigInt uploadedSize,
    )?
    uploadProgress,
  }) {
    return c2CReadReceipt?.call(receipts);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String conversationId, MessageInfo message)? newMessage,
    TResult Function(String conversationId, MessageInfo message)?
    offlineNewMessage,
    TResult Function(String conversationId, MessageInfo message)?
    onlineOnlyMessage,
    TResult Function(
      String conversationId,
      int seq,
      String clientMsgId,
      String revokerId,
      int revokerRole,
      String revokerNickname,
      int revokeTime,
      int sourceMessageSendTime,
      String sourceMessageSendId,
      String sourceMessageSenderNickname,
      int sessionType,
      bool isAdminRevoke,
    )?
    revoked,
    TResult Function(List<MessageReceipt> receipts)? c2CReadReceipt,
    TResult Function(String conversationId, List<String> clientMsgIds)? deleted,
    TResult Function(String clientMsgId, String error)? sendFailed,
    TResult Function(
      String clientMsgId,
      int progress,
      BigInt totalSize,
      BigInt uploadedSize,
    )?
    uploadProgress,
    required TResult orElse(),
  }) {
    if (c2CReadReceipt != null) {
      return c2CReadReceipt(receipts);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(MessageEvent_NewMessage value) newMessage,
    required TResult Function(MessageEvent_OfflineNewMessage value)
    offlineNewMessage,
    required TResult Function(MessageEvent_OnlineOnlyMessage value)
    onlineOnlyMessage,
    required TResult Function(MessageEvent_Revoked value) revoked,
    required TResult Function(MessageEvent_C2CReadReceipt value) c2CReadReceipt,
    required TResult Function(MessageEvent_Deleted value) deleted,
    required TResult Function(MessageEvent_SendFailed value) sendFailed,
    required TResult Function(MessageEvent_UploadProgress value) uploadProgress,
  }) {
    return c2CReadReceipt(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(MessageEvent_NewMessage value)? newMessage,
    TResult? Function(MessageEvent_OfflineNewMessage value)? offlineNewMessage,
    TResult? Function(MessageEvent_OnlineOnlyMessage value)? onlineOnlyMessage,
    TResult? Function(MessageEvent_Revoked value)? revoked,
    TResult? Function(MessageEvent_C2CReadReceipt value)? c2CReadReceipt,
    TResult? Function(MessageEvent_Deleted value)? deleted,
    TResult? Function(MessageEvent_SendFailed value)? sendFailed,
    TResult? Function(MessageEvent_UploadProgress value)? uploadProgress,
  }) {
    return c2CReadReceipt?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(MessageEvent_NewMessage value)? newMessage,
    TResult Function(MessageEvent_OfflineNewMessage value)? offlineNewMessage,
    TResult Function(MessageEvent_OnlineOnlyMessage value)? onlineOnlyMessage,
    TResult Function(MessageEvent_Revoked value)? revoked,
    TResult Function(MessageEvent_C2CReadReceipt value)? c2CReadReceipt,
    TResult Function(MessageEvent_Deleted value)? deleted,
    TResult Function(MessageEvent_SendFailed value)? sendFailed,
    TResult Function(MessageEvent_UploadProgress value)? uploadProgress,
    required TResult orElse(),
  }) {
    if (c2CReadReceipt != null) {
      return c2CReadReceipt(this);
    }
    return orElse();
  }
}

abstract class MessageEvent_C2CReadReceipt extends MessageEvent {
  const factory MessageEvent_C2CReadReceipt({
    required final List<MessageReceipt> receipts,
  }) = _$MessageEvent_C2CReadReceiptImpl;
  const MessageEvent_C2CReadReceipt._() : super._();

  List<MessageReceipt> get receipts;

  /// Create a copy of MessageEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MessageEvent_C2CReadReceiptImplCopyWith<_$MessageEvent_C2CReadReceiptImpl>
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$MessageEvent_DeletedImplCopyWith<$Res> {
  factory _$$MessageEvent_DeletedImplCopyWith(
    _$MessageEvent_DeletedImpl value,
    $Res Function(_$MessageEvent_DeletedImpl) then,
  ) = __$$MessageEvent_DeletedImplCopyWithImpl<$Res>;
  @useResult
  $Res call({String conversationId, List<String> clientMsgIds});
}

/// @nodoc
class __$$MessageEvent_DeletedImplCopyWithImpl<$Res>
    extends _$MessageEventCopyWithImpl<$Res, _$MessageEvent_DeletedImpl>
    implements _$$MessageEvent_DeletedImplCopyWith<$Res> {
  __$$MessageEvent_DeletedImplCopyWithImpl(
    _$MessageEvent_DeletedImpl _value,
    $Res Function(_$MessageEvent_DeletedImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of MessageEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? conversationId = null, Object? clientMsgIds = null}) {
    return _then(
      _$MessageEvent_DeletedImpl(
        conversationId: null == conversationId
            ? _value.conversationId
            : conversationId // ignore: cast_nullable_to_non_nullable
                  as String,
        clientMsgIds: null == clientMsgIds
            ? _value._clientMsgIds
            : clientMsgIds // ignore: cast_nullable_to_non_nullable
                  as List<String>,
      ),
    );
  }
}

/// @nodoc

class _$MessageEvent_DeletedImpl extends MessageEvent_Deleted {
  const _$MessageEvent_DeletedImpl({
    required this.conversationId,
    required final List<String> clientMsgIds,
  }) : _clientMsgIds = clientMsgIds,
       super._();

  @override
  final String conversationId;
  final List<String> _clientMsgIds;
  @override
  List<String> get clientMsgIds {
    if (_clientMsgIds is EqualUnmodifiableListView) return _clientMsgIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_clientMsgIds);
  }

  @override
  String toString() {
    return 'MessageEvent.deleted(conversationId: $conversationId, clientMsgIds: $clientMsgIds)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MessageEvent_DeletedImpl &&
            (identical(other.conversationId, conversationId) ||
                other.conversationId == conversationId) &&
            const DeepCollectionEquality().equals(
              other._clientMsgIds,
              _clientMsgIds,
            ));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    conversationId,
    const DeepCollectionEquality().hash(_clientMsgIds),
  );

  /// Create a copy of MessageEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MessageEvent_DeletedImplCopyWith<_$MessageEvent_DeletedImpl>
  get copyWith =>
      __$$MessageEvent_DeletedImplCopyWithImpl<_$MessageEvent_DeletedImpl>(
        this,
        _$identity,
      );

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String conversationId, MessageInfo message)
    newMessage,
    required TResult Function(String conversationId, MessageInfo message)
    offlineNewMessage,
    required TResult Function(String conversationId, MessageInfo message)
    onlineOnlyMessage,
    required TResult Function(
      String conversationId,
      int seq,
      String clientMsgId,
      String revokerId,
      int revokerRole,
      String revokerNickname,
      int revokeTime,
      int sourceMessageSendTime,
      String sourceMessageSendId,
      String sourceMessageSenderNickname,
      int sessionType,
      bool isAdminRevoke,
    )
    revoked,
    required TResult Function(List<MessageReceipt> receipts) c2CReadReceipt,
    required TResult Function(String conversationId, List<String> clientMsgIds)
    deleted,
    required TResult Function(String clientMsgId, String error) sendFailed,
    required TResult Function(
      String clientMsgId,
      int progress,
      BigInt totalSize,
      BigInt uploadedSize,
    )
    uploadProgress,
  }) {
    return deleted(conversationId, clientMsgIds);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String conversationId, MessageInfo message)? newMessage,
    TResult? Function(String conversationId, MessageInfo message)?
    offlineNewMessage,
    TResult? Function(String conversationId, MessageInfo message)?
    onlineOnlyMessage,
    TResult? Function(
      String conversationId,
      int seq,
      String clientMsgId,
      String revokerId,
      int revokerRole,
      String revokerNickname,
      int revokeTime,
      int sourceMessageSendTime,
      String sourceMessageSendId,
      String sourceMessageSenderNickname,
      int sessionType,
      bool isAdminRevoke,
    )?
    revoked,
    TResult? Function(List<MessageReceipt> receipts)? c2CReadReceipt,
    TResult? Function(String conversationId, List<String> clientMsgIds)?
    deleted,
    TResult? Function(String clientMsgId, String error)? sendFailed,
    TResult? Function(
      String clientMsgId,
      int progress,
      BigInt totalSize,
      BigInt uploadedSize,
    )?
    uploadProgress,
  }) {
    return deleted?.call(conversationId, clientMsgIds);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String conversationId, MessageInfo message)? newMessage,
    TResult Function(String conversationId, MessageInfo message)?
    offlineNewMessage,
    TResult Function(String conversationId, MessageInfo message)?
    onlineOnlyMessage,
    TResult Function(
      String conversationId,
      int seq,
      String clientMsgId,
      String revokerId,
      int revokerRole,
      String revokerNickname,
      int revokeTime,
      int sourceMessageSendTime,
      String sourceMessageSendId,
      String sourceMessageSenderNickname,
      int sessionType,
      bool isAdminRevoke,
    )?
    revoked,
    TResult Function(List<MessageReceipt> receipts)? c2CReadReceipt,
    TResult Function(String conversationId, List<String> clientMsgIds)? deleted,
    TResult Function(String clientMsgId, String error)? sendFailed,
    TResult Function(
      String clientMsgId,
      int progress,
      BigInt totalSize,
      BigInt uploadedSize,
    )?
    uploadProgress,
    required TResult orElse(),
  }) {
    if (deleted != null) {
      return deleted(conversationId, clientMsgIds);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(MessageEvent_NewMessage value) newMessage,
    required TResult Function(MessageEvent_OfflineNewMessage value)
    offlineNewMessage,
    required TResult Function(MessageEvent_OnlineOnlyMessage value)
    onlineOnlyMessage,
    required TResult Function(MessageEvent_Revoked value) revoked,
    required TResult Function(MessageEvent_C2CReadReceipt value) c2CReadReceipt,
    required TResult Function(MessageEvent_Deleted value) deleted,
    required TResult Function(MessageEvent_SendFailed value) sendFailed,
    required TResult Function(MessageEvent_UploadProgress value) uploadProgress,
  }) {
    return deleted(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(MessageEvent_NewMessage value)? newMessage,
    TResult? Function(MessageEvent_OfflineNewMessage value)? offlineNewMessage,
    TResult? Function(MessageEvent_OnlineOnlyMessage value)? onlineOnlyMessage,
    TResult? Function(MessageEvent_Revoked value)? revoked,
    TResult? Function(MessageEvent_C2CReadReceipt value)? c2CReadReceipt,
    TResult? Function(MessageEvent_Deleted value)? deleted,
    TResult? Function(MessageEvent_SendFailed value)? sendFailed,
    TResult? Function(MessageEvent_UploadProgress value)? uploadProgress,
  }) {
    return deleted?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(MessageEvent_NewMessage value)? newMessage,
    TResult Function(MessageEvent_OfflineNewMessage value)? offlineNewMessage,
    TResult Function(MessageEvent_OnlineOnlyMessage value)? onlineOnlyMessage,
    TResult Function(MessageEvent_Revoked value)? revoked,
    TResult Function(MessageEvent_C2CReadReceipt value)? c2CReadReceipt,
    TResult Function(MessageEvent_Deleted value)? deleted,
    TResult Function(MessageEvent_SendFailed value)? sendFailed,
    TResult Function(MessageEvent_UploadProgress value)? uploadProgress,
    required TResult orElse(),
  }) {
    if (deleted != null) {
      return deleted(this);
    }
    return orElse();
  }
}

abstract class MessageEvent_Deleted extends MessageEvent {
  const factory MessageEvent_Deleted({
    required final String conversationId,
    required final List<String> clientMsgIds,
  }) = _$MessageEvent_DeletedImpl;
  const MessageEvent_Deleted._() : super._();

  String get conversationId;
  List<String> get clientMsgIds;

  /// Create a copy of MessageEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MessageEvent_DeletedImplCopyWith<_$MessageEvent_DeletedImpl>
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$MessageEvent_SendFailedImplCopyWith<$Res> {
  factory _$$MessageEvent_SendFailedImplCopyWith(
    _$MessageEvent_SendFailedImpl value,
    $Res Function(_$MessageEvent_SendFailedImpl) then,
  ) = __$$MessageEvent_SendFailedImplCopyWithImpl<$Res>;
  @useResult
  $Res call({String clientMsgId, String error});
}

/// @nodoc
class __$$MessageEvent_SendFailedImplCopyWithImpl<$Res>
    extends _$MessageEventCopyWithImpl<$Res, _$MessageEvent_SendFailedImpl>
    implements _$$MessageEvent_SendFailedImplCopyWith<$Res> {
  __$$MessageEvent_SendFailedImplCopyWithImpl(
    _$MessageEvent_SendFailedImpl _value,
    $Res Function(_$MessageEvent_SendFailedImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of MessageEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? clientMsgId = null, Object? error = null}) {
    return _then(
      _$MessageEvent_SendFailedImpl(
        clientMsgId: null == clientMsgId
            ? _value.clientMsgId
            : clientMsgId // ignore: cast_nullable_to_non_nullable
                  as String,
        error: null == error
            ? _value.error
            : error // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc

class _$MessageEvent_SendFailedImpl extends MessageEvent_SendFailed {
  const _$MessageEvent_SendFailedImpl({
    required this.clientMsgId,
    required this.error,
  }) : super._();

  @override
  final String clientMsgId;
  @override
  final String error;

  @override
  String toString() {
    return 'MessageEvent.sendFailed(clientMsgId: $clientMsgId, error: $error)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MessageEvent_SendFailedImpl &&
            (identical(other.clientMsgId, clientMsgId) ||
                other.clientMsgId == clientMsgId) &&
            (identical(other.error, error) || other.error == error));
  }

  @override
  int get hashCode => Object.hash(runtimeType, clientMsgId, error);

  /// Create a copy of MessageEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MessageEvent_SendFailedImplCopyWith<_$MessageEvent_SendFailedImpl>
  get copyWith =>
      __$$MessageEvent_SendFailedImplCopyWithImpl<
        _$MessageEvent_SendFailedImpl
      >(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String conversationId, MessageInfo message)
    newMessage,
    required TResult Function(String conversationId, MessageInfo message)
    offlineNewMessage,
    required TResult Function(String conversationId, MessageInfo message)
    onlineOnlyMessage,
    required TResult Function(
      String conversationId,
      int seq,
      String clientMsgId,
      String revokerId,
      int revokerRole,
      String revokerNickname,
      int revokeTime,
      int sourceMessageSendTime,
      String sourceMessageSendId,
      String sourceMessageSenderNickname,
      int sessionType,
      bool isAdminRevoke,
    )
    revoked,
    required TResult Function(List<MessageReceipt> receipts) c2CReadReceipt,
    required TResult Function(String conversationId, List<String> clientMsgIds)
    deleted,
    required TResult Function(String clientMsgId, String error) sendFailed,
    required TResult Function(
      String clientMsgId,
      int progress,
      BigInt totalSize,
      BigInt uploadedSize,
    )
    uploadProgress,
  }) {
    return sendFailed(clientMsgId, error);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String conversationId, MessageInfo message)? newMessage,
    TResult? Function(String conversationId, MessageInfo message)?
    offlineNewMessage,
    TResult? Function(String conversationId, MessageInfo message)?
    onlineOnlyMessage,
    TResult? Function(
      String conversationId,
      int seq,
      String clientMsgId,
      String revokerId,
      int revokerRole,
      String revokerNickname,
      int revokeTime,
      int sourceMessageSendTime,
      String sourceMessageSendId,
      String sourceMessageSenderNickname,
      int sessionType,
      bool isAdminRevoke,
    )?
    revoked,
    TResult? Function(List<MessageReceipt> receipts)? c2CReadReceipt,
    TResult? Function(String conversationId, List<String> clientMsgIds)?
    deleted,
    TResult? Function(String clientMsgId, String error)? sendFailed,
    TResult? Function(
      String clientMsgId,
      int progress,
      BigInt totalSize,
      BigInt uploadedSize,
    )?
    uploadProgress,
  }) {
    return sendFailed?.call(clientMsgId, error);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String conversationId, MessageInfo message)? newMessage,
    TResult Function(String conversationId, MessageInfo message)?
    offlineNewMessage,
    TResult Function(String conversationId, MessageInfo message)?
    onlineOnlyMessage,
    TResult Function(
      String conversationId,
      int seq,
      String clientMsgId,
      String revokerId,
      int revokerRole,
      String revokerNickname,
      int revokeTime,
      int sourceMessageSendTime,
      String sourceMessageSendId,
      String sourceMessageSenderNickname,
      int sessionType,
      bool isAdminRevoke,
    )?
    revoked,
    TResult Function(List<MessageReceipt> receipts)? c2CReadReceipt,
    TResult Function(String conversationId, List<String> clientMsgIds)? deleted,
    TResult Function(String clientMsgId, String error)? sendFailed,
    TResult Function(
      String clientMsgId,
      int progress,
      BigInt totalSize,
      BigInt uploadedSize,
    )?
    uploadProgress,
    required TResult orElse(),
  }) {
    if (sendFailed != null) {
      return sendFailed(clientMsgId, error);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(MessageEvent_NewMessage value) newMessage,
    required TResult Function(MessageEvent_OfflineNewMessage value)
    offlineNewMessage,
    required TResult Function(MessageEvent_OnlineOnlyMessage value)
    onlineOnlyMessage,
    required TResult Function(MessageEvent_Revoked value) revoked,
    required TResult Function(MessageEvent_C2CReadReceipt value) c2CReadReceipt,
    required TResult Function(MessageEvent_Deleted value) deleted,
    required TResult Function(MessageEvent_SendFailed value) sendFailed,
    required TResult Function(MessageEvent_UploadProgress value) uploadProgress,
  }) {
    return sendFailed(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(MessageEvent_NewMessage value)? newMessage,
    TResult? Function(MessageEvent_OfflineNewMessage value)? offlineNewMessage,
    TResult? Function(MessageEvent_OnlineOnlyMessage value)? onlineOnlyMessage,
    TResult? Function(MessageEvent_Revoked value)? revoked,
    TResult? Function(MessageEvent_C2CReadReceipt value)? c2CReadReceipt,
    TResult? Function(MessageEvent_Deleted value)? deleted,
    TResult? Function(MessageEvent_SendFailed value)? sendFailed,
    TResult? Function(MessageEvent_UploadProgress value)? uploadProgress,
  }) {
    return sendFailed?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(MessageEvent_NewMessage value)? newMessage,
    TResult Function(MessageEvent_OfflineNewMessage value)? offlineNewMessage,
    TResult Function(MessageEvent_OnlineOnlyMessage value)? onlineOnlyMessage,
    TResult Function(MessageEvent_Revoked value)? revoked,
    TResult Function(MessageEvent_C2CReadReceipt value)? c2CReadReceipt,
    TResult Function(MessageEvent_Deleted value)? deleted,
    TResult Function(MessageEvent_SendFailed value)? sendFailed,
    TResult Function(MessageEvent_UploadProgress value)? uploadProgress,
    required TResult orElse(),
  }) {
    if (sendFailed != null) {
      return sendFailed(this);
    }
    return orElse();
  }
}

abstract class MessageEvent_SendFailed extends MessageEvent {
  const factory MessageEvent_SendFailed({
    required final String clientMsgId,
    required final String error,
  }) = _$MessageEvent_SendFailedImpl;
  const MessageEvent_SendFailed._() : super._();

  String get clientMsgId;
  String get error;

  /// Create a copy of MessageEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MessageEvent_SendFailedImplCopyWith<_$MessageEvent_SendFailedImpl>
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$MessageEvent_UploadProgressImplCopyWith<$Res> {
  factory _$$MessageEvent_UploadProgressImplCopyWith(
    _$MessageEvent_UploadProgressImpl value,
    $Res Function(_$MessageEvent_UploadProgressImpl) then,
  ) = __$$MessageEvent_UploadProgressImplCopyWithImpl<$Res>;
  @useResult
  $Res call({
    String clientMsgId,
    int progress,
    BigInt totalSize,
    BigInt uploadedSize,
  });
}

/// @nodoc
class __$$MessageEvent_UploadProgressImplCopyWithImpl<$Res>
    extends _$MessageEventCopyWithImpl<$Res, _$MessageEvent_UploadProgressImpl>
    implements _$$MessageEvent_UploadProgressImplCopyWith<$Res> {
  __$$MessageEvent_UploadProgressImplCopyWithImpl(
    _$MessageEvent_UploadProgressImpl _value,
    $Res Function(_$MessageEvent_UploadProgressImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of MessageEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? clientMsgId = null,
    Object? progress = null,
    Object? totalSize = null,
    Object? uploadedSize = null,
  }) {
    return _then(
      _$MessageEvent_UploadProgressImpl(
        clientMsgId: null == clientMsgId
            ? _value.clientMsgId
            : clientMsgId // ignore: cast_nullable_to_non_nullable
                  as String,
        progress: null == progress
            ? _value.progress
            : progress // ignore: cast_nullable_to_non_nullable
                  as int,
        totalSize: null == totalSize
            ? _value.totalSize
            : totalSize // ignore: cast_nullable_to_non_nullable
                  as BigInt,
        uploadedSize: null == uploadedSize
            ? _value.uploadedSize
            : uploadedSize // ignore: cast_nullable_to_non_nullable
                  as BigInt,
      ),
    );
  }
}

/// @nodoc

class _$MessageEvent_UploadProgressImpl extends MessageEvent_UploadProgress {
  const _$MessageEvent_UploadProgressImpl({
    required this.clientMsgId,
    required this.progress,
    required this.totalSize,
    required this.uploadedSize,
  }) : super._();

  @override
  final String clientMsgId;
  @override
  final int progress;
  @override
  final BigInt totalSize;
  @override
  final BigInt uploadedSize;

  @override
  String toString() {
    return 'MessageEvent.uploadProgress(clientMsgId: $clientMsgId, progress: $progress, totalSize: $totalSize, uploadedSize: $uploadedSize)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MessageEvent_UploadProgressImpl &&
            (identical(other.clientMsgId, clientMsgId) ||
                other.clientMsgId == clientMsgId) &&
            (identical(other.progress, progress) ||
                other.progress == progress) &&
            (identical(other.totalSize, totalSize) ||
                other.totalSize == totalSize) &&
            (identical(other.uploadedSize, uploadedSize) ||
                other.uploadedSize == uploadedSize));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, clientMsgId, progress, totalSize, uploadedSize);

  /// Create a copy of MessageEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MessageEvent_UploadProgressImplCopyWith<_$MessageEvent_UploadProgressImpl>
  get copyWith =>
      __$$MessageEvent_UploadProgressImplCopyWithImpl<
        _$MessageEvent_UploadProgressImpl
      >(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String conversationId, MessageInfo message)
    newMessage,
    required TResult Function(String conversationId, MessageInfo message)
    offlineNewMessage,
    required TResult Function(String conversationId, MessageInfo message)
    onlineOnlyMessage,
    required TResult Function(
      String conversationId,
      int seq,
      String clientMsgId,
      String revokerId,
      int revokerRole,
      String revokerNickname,
      int revokeTime,
      int sourceMessageSendTime,
      String sourceMessageSendId,
      String sourceMessageSenderNickname,
      int sessionType,
      bool isAdminRevoke,
    )
    revoked,
    required TResult Function(List<MessageReceipt> receipts) c2CReadReceipt,
    required TResult Function(String conversationId, List<String> clientMsgIds)
    deleted,
    required TResult Function(String clientMsgId, String error) sendFailed,
    required TResult Function(
      String clientMsgId,
      int progress,
      BigInt totalSize,
      BigInt uploadedSize,
    )
    uploadProgress,
  }) {
    return uploadProgress(clientMsgId, progress, totalSize, uploadedSize);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String conversationId, MessageInfo message)? newMessage,
    TResult? Function(String conversationId, MessageInfo message)?
    offlineNewMessage,
    TResult? Function(String conversationId, MessageInfo message)?
    onlineOnlyMessage,
    TResult? Function(
      String conversationId,
      int seq,
      String clientMsgId,
      String revokerId,
      int revokerRole,
      String revokerNickname,
      int revokeTime,
      int sourceMessageSendTime,
      String sourceMessageSendId,
      String sourceMessageSenderNickname,
      int sessionType,
      bool isAdminRevoke,
    )?
    revoked,
    TResult? Function(List<MessageReceipt> receipts)? c2CReadReceipt,
    TResult? Function(String conversationId, List<String> clientMsgIds)?
    deleted,
    TResult? Function(String clientMsgId, String error)? sendFailed,
    TResult? Function(
      String clientMsgId,
      int progress,
      BigInt totalSize,
      BigInt uploadedSize,
    )?
    uploadProgress,
  }) {
    return uploadProgress?.call(clientMsgId, progress, totalSize, uploadedSize);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String conversationId, MessageInfo message)? newMessage,
    TResult Function(String conversationId, MessageInfo message)?
    offlineNewMessage,
    TResult Function(String conversationId, MessageInfo message)?
    onlineOnlyMessage,
    TResult Function(
      String conversationId,
      int seq,
      String clientMsgId,
      String revokerId,
      int revokerRole,
      String revokerNickname,
      int revokeTime,
      int sourceMessageSendTime,
      String sourceMessageSendId,
      String sourceMessageSenderNickname,
      int sessionType,
      bool isAdminRevoke,
    )?
    revoked,
    TResult Function(List<MessageReceipt> receipts)? c2CReadReceipt,
    TResult Function(String conversationId, List<String> clientMsgIds)? deleted,
    TResult Function(String clientMsgId, String error)? sendFailed,
    TResult Function(
      String clientMsgId,
      int progress,
      BigInt totalSize,
      BigInt uploadedSize,
    )?
    uploadProgress,
    required TResult orElse(),
  }) {
    if (uploadProgress != null) {
      return uploadProgress(clientMsgId, progress, totalSize, uploadedSize);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(MessageEvent_NewMessage value) newMessage,
    required TResult Function(MessageEvent_OfflineNewMessage value)
    offlineNewMessage,
    required TResult Function(MessageEvent_OnlineOnlyMessage value)
    onlineOnlyMessage,
    required TResult Function(MessageEvent_Revoked value) revoked,
    required TResult Function(MessageEvent_C2CReadReceipt value) c2CReadReceipt,
    required TResult Function(MessageEvent_Deleted value) deleted,
    required TResult Function(MessageEvent_SendFailed value) sendFailed,
    required TResult Function(MessageEvent_UploadProgress value) uploadProgress,
  }) {
    return uploadProgress(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(MessageEvent_NewMessage value)? newMessage,
    TResult? Function(MessageEvent_OfflineNewMessage value)? offlineNewMessage,
    TResult? Function(MessageEvent_OnlineOnlyMessage value)? onlineOnlyMessage,
    TResult? Function(MessageEvent_Revoked value)? revoked,
    TResult? Function(MessageEvent_C2CReadReceipt value)? c2CReadReceipt,
    TResult? Function(MessageEvent_Deleted value)? deleted,
    TResult? Function(MessageEvent_SendFailed value)? sendFailed,
    TResult? Function(MessageEvent_UploadProgress value)? uploadProgress,
  }) {
    return uploadProgress?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(MessageEvent_NewMessage value)? newMessage,
    TResult Function(MessageEvent_OfflineNewMessage value)? offlineNewMessage,
    TResult Function(MessageEvent_OnlineOnlyMessage value)? onlineOnlyMessage,
    TResult Function(MessageEvent_Revoked value)? revoked,
    TResult Function(MessageEvent_C2CReadReceipt value)? c2CReadReceipt,
    TResult Function(MessageEvent_Deleted value)? deleted,
    TResult Function(MessageEvent_SendFailed value)? sendFailed,
    TResult Function(MessageEvent_UploadProgress value)? uploadProgress,
    required TResult orElse(),
  }) {
    if (uploadProgress != null) {
      return uploadProgress(this);
    }
    return orElse();
  }
}

abstract class MessageEvent_UploadProgress extends MessageEvent {
  const factory MessageEvent_UploadProgress({
    required final String clientMsgId,
    required final int progress,
    required final BigInt totalSize,
    required final BigInt uploadedSize,
  }) = _$MessageEvent_UploadProgressImpl;
  const MessageEvent_UploadProgress._() : super._();

  String get clientMsgId;
  int get progress;
  BigInt get totalSize;
  BigInt get uploadedSize;

  /// Create a copy of MessageEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MessageEvent_UploadProgressImplCopyWith<_$MessageEvent_UploadProgressImpl>
  get copyWith => throw _privateConstructorUsedError;
}
