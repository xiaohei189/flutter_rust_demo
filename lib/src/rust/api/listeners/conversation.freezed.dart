// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'conversation.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$ConversationEvent {
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(bool reinstalled) syncServerStart,
    required TResult Function(bool reinstalled) syncServerFinish,
    required TResult Function(int progress) syncServerProgress,
    required TResult Function(bool reinstalled) syncServerFailed,
    required TResult Function(String conversationList) newConversation,
    required TResult Function(String conversationList) conversationChanged,
    required TResult Function(int totalUnreadCount)
    totalUnreadMessageCountChanged,
    required TResult Function(String change) conversationUserInputStatusChanged,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(bool reinstalled)? syncServerStart,
    TResult? Function(bool reinstalled)? syncServerFinish,
    TResult? Function(int progress)? syncServerProgress,
    TResult? Function(bool reinstalled)? syncServerFailed,
    TResult? Function(String conversationList)? newConversation,
    TResult? Function(String conversationList)? conversationChanged,
    TResult? Function(int totalUnreadCount)? totalUnreadMessageCountChanged,
    TResult? Function(String change)? conversationUserInputStatusChanged,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(bool reinstalled)? syncServerStart,
    TResult Function(bool reinstalled)? syncServerFinish,
    TResult Function(int progress)? syncServerProgress,
    TResult Function(bool reinstalled)? syncServerFailed,
    TResult Function(String conversationList)? newConversation,
    TResult Function(String conversationList)? conversationChanged,
    TResult Function(int totalUnreadCount)? totalUnreadMessageCountChanged,
    TResult Function(String change)? conversationUserInputStatusChanged,
    required TResult orElse(),
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(ConversationEvent_SyncServerStart value)
    syncServerStart,
    required TResult Function(ConversationEvent_SyncServerFinish value)
    syncServerFinish,
    required TResult Function(ConversationEvent_SyncServerProgress value)
    syncServerProgress,
    required TResult Function(ConversationEvent_SyncServerFailed value)
    syncServerFailed,
    required TResult Function(ConversationEvent_NewConversation value)
    newConversation,
    required TResult Function(ConversationEvent_ConversationChanged value)
    conversationChanged,
    required TResult Function(
      ConversationEvent_TotalUnreadMessageCountChanged value,
    )
    totalUnreadMessageCountChanged,
    required TResult Function(
      ConversationEvent_ConversationUserInputStatusChanged value,
    )
    conversationUserInputStatusChanged,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(ConversationEvent_SyncServerStart value)? syncServerStart,
    TResult? Function(ConversationEvent_SyncServerFinish value)?
    syncServerFinish,
    TResult? Function(ConversationEvent_SyncServerProgress value)?
    syncServerProgress,
    TResult? Function(ConversationEvent_SyncServerFailed value)?
    syncServerFailed,
    TResult? Function(ConversationEvent_NewConversation value)? newConversation,
    TResult? Function(ConversationEvent_ConversationChanged value)?
    conversationChanged,
    TResult? Function(ConversationEvent_TotalUnreadMessageCountChanged value)?
    totalUnreadMessageCountChanged,
    TResult? Function(
      ConversationEvent_ConversationUserInputStatusChanged value,
    )?
    conversationUserInputStatusChanged,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(ConversationEvent_SyncServerStart value)? syncServerStart,
    TResult Function(ConversationEvent_SyncServerFinish value)?
    syncServerFinish,
    TResult Function(ConversationEvent_SyncServerProgress value)?
    syncServerProgress,
    TResult Function(ConversationEvent_SyncServerFailed value)?
    syncServerFailed,
    TResult Function(ConversationEvent_NewConversation value)? newConversation,
    TResult Function(ConversationEvent_ConversationChanged value)?
    conversationChanged,
    TResult Function(ConversationEvent_TotalUnreadMessageCountChanged value)?
    totalUnreadMessageCountChanged,
    TResult Function(
      ConversationEvent_ConversationUserInputStatusChanged value,
    )?
    conversationUserInputStatusChanged,
    required TResult orElse(),
  }) => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ConversationEventCopyWith<$Res> {
  factory $ConversationEventCopyWith(
    ConversationEvent value,
    $Res Function(ConversationEvent) then,
  ) = _$ConversationEventCopyWithImpl<$Res, ConversationEvent>;
}

/// @nodoc
class _$ConversationEventCopyWithImpl<$Res, $Val extends ConversationEvent>
    implements $ConversationEventCopyWith<$Res> {
  _$ConversationEventCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ConversationEvent
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc
abstract class _$$ConversationEvent_SyncServerStartImplCopyWith<$Res> {
  factory _$$ConversationEvent_SyncServerStartImplCopyWith(
    _$ConversationEvent_SyncServerStartImpl value,
    $Res Function(_$ConversationEvent_SyncServerStartImpl) then,
  ) = __$$ConversationEvent_SyncServerStartImplCopyWithImpl<$Res>;
  @useResult
  $Res call({bool reinstalled});
}

/// @nodoc
class __$$ConversationEvent_SyncServerStartImplCopyWithImpl<$Res>
    extends
        _$ConversationEventCopyWithImpl<
          $Res,
          _$ConversationEvent_SyncServerStartImpl
        >
    implements _$$ConversationEvent_SyncServerStartImplCopyWith<$Res> {
  __$$ConversationEvent_SyncServerStartImplCopyWithImpl(
    _$ConversationEvent_SyncServerStartImpl _value,
    $Res Function(_$ConversationEvent_SyncServerStartImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ConversationEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? reinstalled = null}) {
    return _then(
      _$ConversationEvent_SyncServerStartImpl(
        reinstalled: null == reinstalled
            ? _value.reinstalled
            : reinstalled // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// @nodoc

class _$ConversationEvent_SyncServerStartImpl
    extends ConversationEvent_SyncServerStart {
  const _$ConversationEvent_SyncServerStartImpl({required this.reinstalled})
    : super._();

  @override
  final bool reinstalled;

  @override
  String toString() {
    return 'ConversationEvent.syncServerStart(reinstalled: $reinstalled)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ConversationEvent_SyncServerStartImpl &&
            (identical(other.reinstalled, reinstalled) ||
                other.reinstalled == reinstalled));
  }

  @override
  int get hashCode => Object.hash(runtimeType, reinstalled);

  /// Create a copy of ConversationEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ConversationEvent_SyncServerStartImplCopyWith<
    _$ConversationEvent_SyncServerStartImpl
  >
  get copyWith =>
      __$$ConversationEvent_SyncServerStartImplCopyWithImpl<
        _$ConversationEvent_SyncServerStartImpl
      >(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(bool reinstalled) syncServerStart,
    required TResult Function(bool reinstalled) syncServerFinish,
    required TResult Function(int progress) syncServerProgress,
    required TResult Function(bool reinstalled) syncServerFailed,
    required TResult Function(String conversationList) newConversation,
    required TResult Function(String conversationList) conversationChanged,
    required TResult Function(int totalUnreadCount)
    totalUnreadMessageCountChanged,
    required TResult Function(String change) conversationUserInputStatusChanged,
  }) {
    return syncServerStart(reinstalled);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(bool reinstalled)? syncServerStart,
    TResult? Function(bool reinstalled)? syncServerFinish,
    TResult? Function(int progress)? syncServerProgress,
    TResult? Function(bool reinstalled)? syncServerFailed,
    TResult? Function(String conversationList)? newConversation,
    TResult? Function(String conversationList)? conversationChanged,
    TResult? Function(int totalUnreadCount)? totalUnreadMessageCountChanged,
    TResult? Function(String change)? conversationUserInputStatusChanged,
  }) {
    return syncServerStart?.call(reinstalled);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(bool reinstalled)? syncServerStart,
    TResult Function(bool reinstalled)? syncServerFinish,
    TResult Function(int progress)? syncServerProgress,
    TResult Function(bool reinstalled)? syncServerFailed,
    TResult Function(String conversationList)? newConversation,
    TResult Function(String conversationList)? conversationChanged,
    TResult Function(int totalUnreadCount)? totalUnreadMessageCountChanged,
    TResult Function(String change)? conversationUserInputStatusChanged,
    required TResult orElse(),
  }) {
    if (syncServerStart != null) {
      return syncServerStart(reinstalled);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(ConversationEvent_SyncServerStart value)
    syncServerStart,
    required TResult Function(ConversationEvent_SyncServerFinish value)
    syncServerFinish,
    required TResult Function(ConversationEvent_SyncServerProgress value)
    syncServerProgress,
    required TResult Function(ConversationEvent_SyncServerFailed value)
    syncServerFailed,
    required TResult Function(ConversationEvent_NewConversation value)
    newConversation,
    required TResult Function(ConversationEvent_ConversationChanged value)
    conversationChanged,
    required TResult Function(
      ConversationEvent_TotalUnreadMessageCountChanged value,
    )
    totalUnreadMessageCountChanged,
    required TResult Function(
      ConversationEvent_ConversationUserInputStatusChanged value,
    )
    conversationUserInputStatusChanged,
  }) {
    return syncServerStart(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(ConversationEvent_SyncServerStart value)? syncServerStart,
    TResult? Function(ConversationEvent_SyncServerFinish value)?
    syncServerFinish,
    TResult? Function(ConversationEvent_SyncServerProgress value)?
    syncServerProgress,
    TResult? Function(ConversationEvent_SyncServerFailed value)?
    syncServerFailed,
    TResult? Function(ConversationEvent_NewConversation value)? newConversation,
    TResult? Function(ConversationEvent_ConversationChanged value)?
    conversationChanged,
    TResult? Function(ConversationEvent_TotalUnreadMessageCountChanged value)?
    totalUnreadMessageCountChanged,
    TResult? Function(
      ConversationEvent_ConversationUserInputStatusChanged value,
    )?
    conversationUserInputStatusChanged,
  }) {
    return syncServerStart?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(ConversationEvent_SyncServerStart value)? syncServerStart,
    TResult Function(ConversationEvent_SyncServerFinish value)?
    syncServerFinish,
    TResult Function(ConversationEvent_SyncServerProgress value)?
    syncServerProgress,
    TResult Function(ConversationEvent_SyncServerFailed value)?
    syncServerFailed,
    TResult Function(ConversationEvent_NewConversation value)? newConversation,
    TResult Function(ConversationEvent_ConversationChanged value)?
    conversationChanged,
    TResult Function(ConversationEvent_TotalUnreadMessageCountChanged value)?
    totalUnreadMessageCountChanged,
    TResult Function(
      ConversationEvent_ConversationUserInputStatusChanged value,
    )?
    conversationUserInputStatusChanged,
    required TResult orElse(),
  }) {
    if (syncServerStart != null) {
      return syncServerStart(this);
    }
    return orElse();
  }
}

abstract class ConversationEvent_SyncServerStart extends ConversationEvent {
  const factory ConversationEvent_SyncServerStart({
    required final bool reinstalled,
  }) = _$ConversationEvent_SyncServerStartImpl;
  const ConversationEvent_SyncServerStart._() : super._();

  bool get reinstalled;

  /// Create a copy of ConversationEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ConversationEvent_SyncServerStartImplCopyWith<
    _$ConversationEvent_SyncServerStartImpl
  >
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$ConversationEvent_SyncServerFinishImplCopyWith<$Res> {
  factory _$$ConversationEvent_SyncServerFinishImplCopyWith(
    _$ConversationEvent_SyncServerFinishImpl value,
    $Res Function(_$ConversationEvent_SyncServerFinishImpl) then,
  ) = __$$ConversationEvent_SyncServerFinishImplCopyWithImpl<$Res>;
  @useResult
  $Res call({bool reinstalled});
}

/// @nodoc
class __$$ConversationEvent_SyncServerFinishImplCopyWithImpl<$Res>
    extends
        _$ConversationEventCopyWithImpl<
          $Res,
          _$ConversationEvent_SyncServerFinishImpl
        >
    implements _$$ConversationEvent_SyncServerFinishImplCopyWith<$Res> {
  __$$ConversationEvent_SyncServerFinishImplCopyWithImpl(
    _$ConversationEvent_SyncServerFinishImpl _value,
    $Res Function(_$ConversationEvent_SyncServerFinishImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ConversationEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? reinstalled = null}) {
    return _then(
      _$ConversationEvent_SyncServerFinishImpl(
        reinstalled: null == reinstalled
            ? _value.reinstalled
            : reinstalled // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// @nodoc

class _$ConversationEvent_SyncServerFinishImpl
    extends ConversationEvent_SyncServerFinish {
  const _$ConversationEvent_SyncServerFinishImpl({required this.reinstalled})
    : super._();

  @override
  final bool reinstalled;

  @override
  String toString() {
    return 'ConversationEvent.syncServerFinish(reinstalled: $reinstalled)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ConversationEvent_SyncServerFinishImpl &&
            (identical(other.reinstalled, reinstalled) ||
                other.reinstalled == reinstalled));
  }

  @override
  int get hashCode => Object.hash(runtimeType, reinstalled);

  /// Create a copy of ConversationEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ConversationEvent_SyncServerFinishImplCopyWith<
    _$ConversationEvent_SyncServerFinishImpl
  >
  get copyWith =>
      __$$ConversationEvent_SyncServerFinishImplCopyWithImpl<
        _$ConversationEvent_SyncServerFinishImpl
      >(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(bool reinstalled) syncServerStart,
    required TResult Function(bool reinstalled) syncServerFinish,
    required TResult Function(int progress) syncServerProgress,
    required TResult Function(bool reinstalled) syncServerFailed,
    required TResult Function(String conversationList) newConversation,
    required TResult Function(String conversationList) conversationChanged,
    required TResult Function(int totalUnreadCount)
    totalUnreadMessageCountChanged,
    required TResult Function(String change) conversationUserInputStatusChanged,
  }) {
    return syncServerFinish(reinstalled);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(bool reinstalled)? syncServerStart,
    TResult? Function(bool reinstalled)? syncServerFinish,
    TResult? Function(int progress)? syncServerProgress,
    TResult? Function(bool reinstalled)? syncServerFailed,
    TResult? Function(String conversationList)? newConversation,
    TResult? Function(String conversationList)? conversationChanged,
    TResult? Function(int totalUnreadCount)? totalUnreadMessageCountChanged,
    TResult? Function(String change)? conversationUserInputStatusChanged,
  }) {
    return syncServerFinish?.call(reinstalled);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(bool reinstalled)? syncServerStart,
    TResult Function(bool reinstalled)? syncServerFinish,
    TResult Function(int progress)? syncServerProgress,
    TResult Function(bool reinstalled)? syncServerFailed,
    TResult Function(String conversationList)? newConversation,
    TResult Function(String conversationList)? conversationChanged,
    TResult Function(int totalUnreadCount)? totalUnreadMessageCountChanged,
    TResult Function(String change)? conversationUserInputStatusChanged,
    required TResult orElse(),
  }) {
    if (syncServerFinish != null) {
      return syncServerFinish(reinstalled);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(ConversationEvent_SyncServerStart value)
    syncServerStart,
    required TResult Function(ConversationEvent_SyncServerFinish value)
    syncServerFinish,
    required TResult Function(ConversationEvent_SyncServerProgress value)
    syncServerProgress,
    required TResult Function(ConversationEvent_SyncServerFailed value)
    syncServerFailed,
    required TResult Function(ConversationEvent_NewConversation value)
    newConversation,
    required TResult Function(ConversationEvent_ConversationChanged value)
    conversationChanged,
    required TResult Function(
      ConversationEvent_TotalUnreadMessageCountChanged value,
    )
    totalUnreadMessageCountChanged,
    required TResult Function(
      ConversationEvent_ConversationUserInputStatusChanged value,
    )
    conversationUserInputStatusChanged,
  }) {
    return syncServerFinish(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(ConversationEvent_SyncServerStart value)? syncServerStart,
    TResult? Function(ConversationEvent_SyncServerFinish value)?
    syncServerFinish,
    TResult? Function(ConversationEvent_SyncServerProgress value)?
    syncServerProgress,
    TResult? Function(ConversationEvent_SyncServerFailed value)?
    syncServerFailed,
    TResult? Function(ConversationEvent_NewConversation value)? newConversation,
    TResult? Function(ConversationEvent_ConversationChanged value)?
    conversationChanged,
    TResult? Function(ConversationEvent_TotalUnreadMessageCountChanged value)?
    totalUnreadMessageCountChanged,
    TResult? Function(
      ConversationEvent_ConversationUserInputStatusChanged value,
    )?
    conversationUserInputStatusChanged,
  }) {
    return syncServerFinish?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(ConversationEvent_SyncServerStart value)? syncServerStart,
    TResult Function(ConversationEvent_SyncServerFinish value)?
    syncServerFinish,
    TResult Function(ConversationEvent_SyncServerProgress value)?
    syncServerProgress,
    TResult Function(ConversationEvent_SyncServerFailed value)?
    syncServerFailed,
    TResult Function(ConversationEvent_NewConversation value)? newConversation,
    TResult Function(ConversationEvent_ConversationChanged value)?
    conversationChanged,
    TResult Function(ConversationEvent_TotalUnreadMessageCountChanged value)?
    totalUnreadMessageCountChanged,
    TResult Function(
      ConversationEvent_ConversationUserInputStatusChanged value,
    )?
    conversationUserInputStatusChanged,
    required TResult orElse(),
  }) {
    if (syncServerFinish != null) {
      return syncServerFinish(this);
    }
    return orElse();
  }
}

abstract class ConversationEvent_SyncServerFinish extends ConversationEvent {
  const factory ConversationEvent_SyncServerFinish({
    required final bool reinstalled,
  }) = _$ConversationEvent_SyncServerFinishImpl;
  const ConversationEvent_SyncServerFinish._() : super._();

  bool get reinstalled;

  /// Create a copy of ConversationEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ConversationEvent_SyncServerFinishImplCopyWith<
    _$ConversationEvent_SyncServerFinishImpl
  >
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$ConversationEvent_SyncServerProgressImplCopyWith<$Res> {
  factory _$$ConversationEvent_SyncServerProgressImplCopyWith(
    _$ConversationEvent_SyncServerProgressImpl value,
    $Res Function(_$ConversationEvent_SyncServerProgressImpl) then,
  ) = __$$ConversationEvent_SyncServerProgressImplCopyWithImpl<$Res>;
  @useResult
  $Res call({int progress});
}

/// @nodoc
class __$$ConversationEvent_SyncServerProgressImplCopyWithImpl<$Res>
    extends
        _$ConversationEventCopyWithImpl<
          $Res,
          _$ConversationEvent_SyncServerProgressImpl
        >
    implements _$$ConversationEvent_SyncServerProgressImplCopyWith<$Res> {
  __$$ConversationEvent_SyncServerProgressImplCopyWithImpl(
    _$ConversationEvent_SyncServerProgressImpl _value,
    $Res Function(_$ConversationEvent_SyncServerProgressImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ConversationEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? progress = null}) {
    return _then(
      _$ConversationEvent_SyncServerProgressImpl(
        progress: null == progress
            ? _value.progress
            : progress // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc

class _$ConversationEvent_SyncServerProgressImpl
    extends ConversationEvent_SyncServerProgress {
  const _$ConversationEvent_SyncServerProgressImpl({required this.progress})
    : super._();

  @override
  final int progress;

  @override
  String toString() {
    return 'ConversationEvent.syncServerProgress(progress: $progress)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ConversationEvent_SyncServerProgressImpl &&
            (identical(other.progress, progress) ||
                other.progress == progress));
  }

  @override
  int get hashCode => Object.hash(runtimeType, progress);

  /// Create a copy of ConversationEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ConversationEvent_SyncServerProgressImplCopyWith<
    _$ConversationEvent_SyncServerProgressImpl
  >
  get copyWith =>
      __$$ConversationEvent_SyncServerProgressImplCopyWithImpl<
        _$ConversationEvent_SyncServerProgressImpl
      >(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(bool reinstalled) syncServerStart,
    required TResult Function(bool reinstalled) syncServerFinish,
    required TResult Function(int progress) syncServerProgress,
    required TResult Function(bool reinstalled) syncServerFailed,
    required TResult Function(String conversationList) newConversation,
    required TResult Function(String conversationList) conversationChanged,
    required TResult Function(int totalUnreadCount)
    totalUnreadMessageCountChanged,
    required TResult Function(String change) conversationUserInputStatusChanged,
  }) {
    return syncServerProgress(progress);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(bool reinstalled)? syncServerStart,
    TResult? Function(bool reinstalled)? syncServerFinish,
    TResult? Function(int progress)? syncServerProgress,
    TResult? Function(bool reinstalled)? syncServerFailed,
    TResult? Function(String conversationList)? newConversation,
    TResult? Function(String conversationList)? conversationChanged,
    TResult? Function(int totalUnreadCount)? totalUnreadMessageCountChanged,
    TResult? Function(String change)? conversationUserInputStatusChanged,
  }) {
    return syncServerProgress?.call(progress);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(bool reinstalled)? syncServerStart,
    TResult Function(bool reinstalled)? syncServerFinish,
    TResult Function(int progress)? syncServerProgress,
    TResult Function(bool reinstalled)? syncServerFailed,
    TResult Function(String conversationList)? newConversation,
    TResult Function(String conversationList)? conversationChanged,
    TResult Function(int totalUnreadCount)? totalUnreadMessageCountChanged,
    TResult Function(String change)? conversationUserInputStatusChanged,
    required TResult orElse(),
  }) {
    if (syncServerProgress != null) {
      return syncServerProgress(progress);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(ConversationEvent_SyncServerStart value)
    syncServerStart,
    required TResult Function(ConversationEvent_SyncServerFinish value)
    syncServerFinish,
    required TResult Function(ConversationEvent_SyncServerProgress value)
    syncServerProgress,
    required TResult Function(ConversationEvent_SyncServerFailed value)
    syncServerFailed,
    required TResult Function(ConversationEvent_NewConversation value)
    newConversation,
    required TResult Function(ConversationEvent_ConversationChanged value)
    conversationChanged,
    required TResult Function(
      ConversationEvent_TotalUnreadMessageCountChanged value,
    )
    totalUnreadMessageCountChanged,
    required TResult Function(
      ConversationEvent_ConversationUserInputStatusChanged value,
    )
    conversationUserInputStatusChanged,
  }) {
    return syncServerProgress(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(ConversationEvent_SyncServerStart value)? syncServerStart,
    TResult? Function(ConversationEvent_SyncServerFinish value)?
    syncServerFinish,
    TResult? Function(ConversationEvent_SyncServerProgress value)?
    syncServerProgress,
    TResult? Function(ConversationEvent_SyncServerFailed value)?
    syncServerFailed,
    TResult? Function(ConversationEvent_NewConversation value)? newConversation,
    TResult? Function(ConversationEvent_ConversationChanged value)?
    conversationChanged,
    TResult? Function(ConversationEvent_TotalUnreadMessageCountChanged value)?
    totalUnreadMessageCountChanged,
    TResult? Function(
      ConversationEvent_ConversationUserInputStatusChanged value,
    )?
    conversationUserInputStatusChanged,
  }) {
    return syncServerProgress?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(ConversationEvent_SyncServerStart value)? syncServerStart,
    TResult Function(ConversationEvent_SyncServerFinish value)?
    syncServerFinish,
    TResult Function(ConversationEvent_SyncServerProgress value)?
    syncServerProgress,
    TResult Function(ConversationEvent_SyncServerFailed value)?
    syncServerFailed,
    TResult Function(ConversationEvent_NewConversation value)? newConversation,
    TResult Function(ConversationEvent_ConversationChanged value)?
    conversationChanged,
    TResult Function(ConversationEvent_TotalUnreadMessageCountChanged value)?
    totalUnreadMessageCountChanged,
    TResult Function(
      ConversationEvent_ConversationUserInputStatusChanged value,
    )?
    conversationUserInputStatusChanged,
    required TResult orElse(),
  }) {
    if (syncServerProgress != null) {
      return syncServerProgress(this);
    }
    return orElse();
  }
}

abstract class ConversationEvent_SyncServerProgress extends ConversationEvent {
  const factory ConversationEvent_SyncServerProgress({
    required final int progress,
  }) = _$ConversationEvent_SyncServerProgressImpl;
  const ConversationEvent_SyncServerProgress._() : super._();

  int get progress;

  /// Create a copy of ConversationEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ConversationEvent_SyncServerProgressImplCopyWith<
    _$ConversationEvent_SyncServerProgressImpl
  >
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$ConversationEvent_SyncServerFailedImplCopyWith<$Res> {
  factory _$$ConversationEvent_SyncServerFailedImplCopyWith(
    _$ConversationEvent_SyncServerFailedImpl value,
    $Res Function(_$ConversationEvent_SyncServerFailedImpl) then,
  ) = __$$ConversationEvent_SyncServerFailedImplCopyWithImpl<$Res>;
  @useResult
  $Res call({bool reinstalled});
}

/// @nodoc
class __$$ConversationEvent_SyncServerFailedImplCopyWithImpl<$Res>
    extends
        _$ConversationEventCopyWithImpl<
          $Res,
          _$ConversationEvent_SyncServerFailedImpl
        >
    implements _$$ConversationEvent_SyncServerFailedImplCopyWith<$Res> {
  __$$ConversationEvent_SyncServerFailedImplCopyWithImpl(
    _$ConversationEvent_SyncServerFailedImpl _value,
    $Res Function(_$ConversationEvent_SyncServerFailedImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ConversationEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? reinstalled = null}) {
    return _then(
      _$ConversationEvent_SyncServerFailedImpl(
        reinstalled: null == reinstalled
            ? _value.reinstalled
            : reinstalled // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// @nodoc

class _$ConversationEvent_SyncServerFailedImpl
    extends ConversationEvent_SyncServerFailed {
  const _$ConversationEvent_SyncServerFailedImpl({required this.reinstalled})
    : super._();

  @override
  final bool reinstalled;

  @override
  String toString() {
    return 'ConversationEvent.syncServerFailed(reinstalled: $reinstalled)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ConversationEvent_SyncServerFailedImpl &&
            (identical(other.reinstalled, reinstalled) ||
                other.reinstalled == reinstalled));
  }

  @override
  int get hashCode => Object.hash(runtimeType, reinstalled);

  /// Create a copy of ConversationEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ConversationEvent_SyncServerFailedImplCopyWith<
    _$ConversationEvent_SyncServerFailedImpl
  >
  get copyWith =>
      __$$ConversationEvent_SyncServerFailedImplCopyWithImpl<
        _$ConversationEvent_SyncServerFailedImpl
      >(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(bool reinstalled) syncServerStart,
    required TResult Function(bool reinstalled) syncServerFinish,
    required TResult Function(int progress) syncServerProgress,
    required TResult Function(bool reinstalled) syncServerFailed,
    required TResult Function(String conversationList) newConversation,
    required TResult Function(String conversationList) conversationChanged,
    required TResult Function(int totalUnreadCount)
    totalUnreadMessageCountChanged,
    required TResult Function(String change) conversationUserInputStatusChanged,
  }) {
    return syncServerFailed(reinstalled);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(bool reinstalled)? syncServerStart,
    TResult? Function(bool reinstalled)? syncServerFinish,
    TResult? Function(int progress)? syncServerProgress,
    TResult? Function(bool reinstalled)? syncServerFailed,
    TResult? Function(String conversationList)? newConversation,
    TResult? Function(String conversationList)? conversationChanged,
    TResult? Function(int totalUnreadCount)? totalUnreadMessageCountChanged,
    TResult? Function(String change)? conversationUserInputStatusChanged,
  }) {
    return syncServerFailed?.call(reinstalled);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(bool reinstalled)? syncServerStart,
    TResult Function(bool reinstalled)? syncServerFinish,
    TResult Function(int progress)? syncServerProgress,
    TResult Function(bool reinstalled)? syncServerFailed,
    TResult Function(String conversationList)? newConversation,
    TResult Function(String conversationList)? conversationChanged,
    TResult Function(int totalUnreadCount)? totalUnreadMessageCountChanged,
    TResult Function(String change)? conversationUserInputStatusChanged,
    required TResult orElse(),
  }) {
    if (syncServerFailed != null) {
      return syncServerFailed(reinstalled);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(ConversationEvent_SyncServerStart value)
    syncServerStart,
    required TResult Function(ConversationEvent_SyncServerFinish value)
    syncServerFinish,
    required TResult Function(ConversationEvent_SyncServerProgress value)
    syncServerProgress,
    required TResult Function(ConversationEvent_SyncServerFailed value)
    syncServerFailed,
    required TResult Function(ConversationEvent_NewConversation value)
    newConversation,
    required TResult Function(ConversationEvent_ConversationChanged value)
    conversationChanged,
    required TResult Function(
      ConversationEvent_TotalUnreadMessageCountChanged value,
    )
    totalUnreadMessageCountChanged,
    required TResult Function(
      ConversationEvent_ConversationUserInputStatusChanged value,
    )
    conversationUserInputStatusChanged,
  }) {
    return syncServerFailed(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(ConversationEvent_SyncServerStart value)? syncServerStart,
    TResult? Function(ConversationEvent_SyncServerFinish value)?
    syncServerFinish,
    TResult? Function(ConversationEvent_SyncServerProgress value)?
    syncServerProgress,
    TResult? Function(ConversationEvent_SyncServerFailed value)?
    syncServerFailed,
    TResult? Function(ConversationEvent_NewConversation value)? newConversation,
    TResult? Function(ConversationEvent_ConversationChanged value)?
    conversationChanged,
    TResult? Function(ConversationEvent_TotalUnreadMessageCountChanged value)?
    totalUnreadMessageCountChanged,
    TResult? Function(
      ConversationEvent_ConversationUserInputStatusChanged value,
    )?
    conversationUserInputStatusChanged,
  }) {
    return syncServerFailed?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(ConversationEvent_SyncServerStart value)? syncServerStart,
    TResult Function(ConversationEvent_SyncServerFinish value)?
    syncServerFinish,
    TResult Function(ConversationEvent_SyncServerProgress value)?
    syncServerProgress,
    TResult Function(ConversationEvent_SyncServerFailed value)?
    syncServerFailed,
    TResult Function(ConversationEvent_NewConversation value)? newConversation,
    TResult Function(ConversationEvent_ConversationChanged value)?
    conversationChanged,
    TResult Function(ConversationEvent_TotalUnreadMessageCountChanged value)?
    totalUnreadMessageCountChanged,
    TResult Function(
      ConversationEvent_ConversationUserInputStatusChanged value,
    )?
    conversationUserInputStatusChanged,
    required TResult orElse(),
  }) {
    if (syncServerFailed != null) {
      return syncServerFailed(this);
    }
    return orElse();
  }
}

abstract class ConversationEvent_SyncServerFailed extends ConversationEvent {
  const factory ConversationEvent_SyncServerFailed({
    required final bool reinstalled,
  }) = _$ConversationEvent_SyncServerFailedImpl;
  const ConversationEvent_SyncServerFailed._() : super._();

  bool get reinstalled;

  /// Create a copy of ConversationEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ConversationEvent_SyncServerFailedImplCopyWith<
    _$ConversationEvent_SyncServerFailedImpl
  >
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$ConversationEvent_NewConversationImplCopyWith<$Res> {
  factory _$$ConversationEvent_NewConversationImplCopyWith(
    _$ConversationEvent_NewConversationImpl value,
    $Res Function(_$ConversationEvent_NewConversationImpl) then,
  ) = __$$ConversationEvent_NewConversationImplCopyWithImpl<$Res>;
  @useResult
  $Res call({String conversationList});
}

/// @nodoc
class __$$ConversationEvent_NewConversationImplCopyWithImpl<$Res>
    extends
        _$ConversationEventCopyWithImpl<
          $Res,
          _$ConversationEvent_NewConversationImpl
        >
    implements _$$ConversationEvent_NewConversationImplCopyWith<$Res> {
  __$$ConversationEvent_NewConversationImplCopyWithImpl(
    _$ConversationEvent_NewConversationImpl _value,
    $Res Function(_$ConversationEvent_NewConversationImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ConversationEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? conversationList = null}) {
    return _then(
      _$ConversationEvent_NewConversationImpl(
        conversationList: null == conversationList
            ? _value.conversationList
            : conversationList // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc

class _$ConversationEvent_NewConversationImpl
    extends ConversationEvent_NewConversation {
  const _$ConversationEvent_NewConversationImpl({
    required this.conversationList,
  }) : super._();

  @override
  final String conversationList;

  @override
  String toString() {
    return 'ConversationEvent.newConversation(conversationList: $conversationList)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ConversationEvent_NewConversationImpl &&
            (identical(other.conversationList, conversationList) ||
                other.conversationList == conversationList));
  }

  @override
  int get hashCode => Object.hash(runtimeType, conversationList);

  /// Create a copy of ConversationEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ConversationEvent_NewConversationImplCopyWith<
    _$ConversationEvent_NewConversationImpl
  >
  get copyWith =>
      __$$ConversationEvent_NewConversationImplCopyWithImpl<
        _$ConversationEvent_NewConversationImpl
      >(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(bool reinstalled) syncServerStart,
    required TResult Function(bool reinstalled) syncServerFinish,
    required TResult Function(int progress) syncServerProgress,
    required TResult Function(bool reinstalled) syncServerFailed,
    required TResult Function(String conversationList) newConversation,
    required TResult Function(String conversationList) conversationChanged,
    required TResult Function(int totalUnreadCount)
    totalUnreadMessageCountChanged,
    required TResult Function(String change) conversationUserInputStatusChanged,
  }) {
    return newConversation(conversationList);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(bool reinstalled)? syncServerStart,
    TResult? Function(bool reinstalled)? syncServerFinish,
    TResult? Function(int progress)? syncServerProgress,
    TResult? Function(bool reinstalled)? syncServerFailed,
    TResult? Function(String conversationList)? newConversation,
    TResult? Function(String conversationList)? conversationChanged,
    TResult? Function(int totalUnreadCount)? totalUnreadMessageCountChanged,
    TResult? Function(String change)? conversationUserInputStatusChanged,
  }) {
    return newConversation?.call(conversationList);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(bool reinstalled)? syncServerStart,
    TResult Function(bool reinstalled)? syncServerFinish,
    TResult Function(int progress)? syncServerProgress,
    TResult Function(bool reinstalled)? syncServerFailed,
    TResult Function(String conversationList)? newConversation,
    TResult Function(String conversationList)? conversationChanged,
    TResult Function(int totalUnreadCount)? totalUnreadMessageCountChanged,
    TResult Function(String change)? conversationUserInputStatusChanged,
    required TResult orElse(),
  }) {
    if (newConversation != null) {
      return newConversation(conversationList);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(ConversationEvent_SyncServerStart value)
    syncServerStart,
    required TResult Function(ConversationEvent_SyncServerFinish value)
    syncServerFinish,
    required TResult Function(ConversationEvent_SyncServerProgress value)
    syncServerProgress,
    required TResult Function(ConversationEvent_SyncServerFailed value)
    syncServerFailed,
    required TResult Function(ConversationEvent_NewConversation value)
    newConversation,
    required TResult Function(ConversationEvent_ConversationChanged value)
    conversationChanged,
    required TResult Function(
      ConversationEvent_TotalUnreadMessageCountChanged value,
    )
    totalUnreadMessageCountChanged,
    required TResult Function(
      ConversationEvent_ConversationUserInputStatusChanged value,
    )
    conversationUserInputStatusChanged,
  }) {
    return newConversation(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(ConversationEvent_SyncServerStart value)? syncServerStart,
    TResult? Function(ConversationEvent_SyncServerFinish value)?
    syncServerFinish,
    TResult? Function(ConversationEvent_SyncServerProgress value)?
    syncServerProgress,
    TResult? Function(ConversationEvent_SyncServerFailed value)?
    syncServerFailed,
    TResult? Function(ConversationEvent_NewConversation value)? newConversation,
    TResult? Function(ConversationEvent_ConversationChanged value)?
    conversationChanged,
    TResult? Function(ConversationEvent_TotalUnreadMessageCountChanged value)?
    totalUnreadMessageCountChanged,
    TResult? Function(
      ConversationEvent_ConversationUserInputStatusChanged value,
    )?
    conversationUserInputStatusChanged,
  }) {
    return newConversation?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(ConversationEvent_SyncServerStart value)? syncServerStart,
    TResult Function(ConversationEvent_SyncServerFinish value)?
    syncServerFinish,
    TResult Function(ConversationEvent_SyncServerProgress value)?
    syncServerProgress,
    TResult Function(ConversationEvent_SyncServerFailed value)?
    syncServerFailed,
    TResult Function(ConversationEvent_NewConversation value)? newConversation,
    TResult Function(ConversationEvent_ConversationChanged value)?
    conversationChanged,
    TResult Function(ConversationEvent_TotalUnreadMessageCountChanged value)?
    totalUnreadMessageCountChanged,
    TResult Function(
      ConversationEvent_ConversationUserInputStatusChanged value,
    )?
    conversationUserInputStatusChanged,
    required TResult orElse(),
  }) {
    if (newConversation != null) {
      return newConversation(this);
    }
    return orElse();
  }
}

abstract class ConversationEvent_NewConversation extends ConversationEvent {
  const factory ConversationEvent_NewConversation({
    required final String conversationList,
  }) = _$ConversationEvent_NewConversationImpl;
  const ConversationEvent_NewConversation._() : super._();

  String get conversationList;

  /// Create a copy of ConversationEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ConversationEvent_NewConversationImplCopyWith<
    _$ConversationEvent_NewConversationImpl
  >
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$ConversationEvent_ConversationChangedImplCopyWith<$Res> {
  factory _$$ConversationEvent_ConversationChangedImplCopyWith(
    _$ConversationEvent_ConversationChangedImpl value,
    $Res Function(_$ConversationEvent_ConversationChangedImpl) then,
  ) = __$$ConversationEvent_ConversationChangedImplCopyWithImpl<$Res>;
  @useResult
  $Res call({String conversationList});
}

/// @nodoc
class __$$ConversationEvent_ConversationChangedImplCopyWithImpl<$Res>
    extends
        _$ConversationEventCopyWithImpl<
          $Res,
          _$ConversationEvent_ConversationChangedImpl
        >
    implements _$$ConversationEvent_ConversationChangedImplCopyWith<$Res> {
  __$$ConversationEvent_ConversationChangedImplCopyWithImpl(
    _$ConversationEvent_ConversationChangedImpl _value,
    $Res Function(_$ConversationEvent_ConversationChangedImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ConversationEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? conversationList = null}) {
    return _then(
      _$ConversationEvent_ConversationChangedImpl(
        conversationList: null == conversationList
            ? _value.conversationList
            : conversationList // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc

class _$ConversationEvent_ConversationChangedImpl
    extends ConversationEvent_ConversationChanged {
  const _$ConversationEvent_ConversationChangedImpl({
    required this.conversationList,
  }) : super._();

  @override
  final String conversationList;

  @override
  String toString() {
    return 'ConversationEvent.conversationChanged(conversationList: $conversationList)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ConversationEvent_ConversationChangedImpl &&
            (identical(other.conversationList, conversationList) ||
                other.conversationList == conversationList));
  }

  @override
  int get hashCode => Object.hash(runtimeType, conversationList);

  /// Create a copy of ConversationEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ConversationEvent_ConversationChangedImplCopyWith<
    _$ConversationEvent_ConversationChangedImpl
  >
  get copyWith =>
      __$$ConversationEvent_ConversationChangedImplCopyWithImpl<
        _$ConversationEvent_ConversationChangedImpl
      >(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(bool reinstalled) syncServerStart,
    required TResult Function(bool reinstalled) syncServerFinish,
    required TResult Function(int progress) syncServerProgress,
    required TResult Function(bool reinstalled) syncServerFailed,
    required TResult Function(String conversationList) newConversation,
    required TResult Function(String conversationList) conversationChanged,
    required TResult Function(int totalUnreadCount)
    totalUnreadMessageCountChanged,
    required TResult Function(String change) conversationUserInputStatusChanged,
  }) {
    return conversationChanged(conversationList);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(bool reinstalled)? syncServerStart,
    TResult? Function(bool reinstalled)? syncServerFinish,
    TResult? Function(int progress)? syncServerProgress,
    TResult? Function(bool reinstalled)? syncServerFailed,
    TResult? Function(String conversationList)? newConversation,
    TResult? Function(String conversationList)? conversationChanged,
    TResult? Function(int totalUnreadCount)? totalUnreadMessageCountChanged,
    TResult? Function(String change)? conversationUserInputStatusChanged,
  }) {
    return conversationChanged?.call(conversationList);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(bool reinstalled)? syncServerStart,
    TResult Function(bool reinstalled)? syncServerFinish,
    TResult Function(int progress)? syncServerProgress,
    TResult Function(bool reinstalled)? syncServerFailed,
    TResult Function(String conversationList)? newConversation,
    TResult Function(String conversationList)? conversationChanged,
    TResult Function(int totalUnreadCount)? totalUnreadMessageCountChanged,
    TResult Function(String change)? conversationUserInputStatusChanged,
    required TResult orElse(),
  }) {
    if (conversationChanged != null) {
      return conversationChanged(conversationList);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(ConversationEvent_SyncServerStart value)
    syncServerStart,
    required TResult Function(ConversationEvent_SyncServerFinish value)
    syncServerFinish,
    required TResult Function(ConversationEvent_SyncServerProgress value)
    syncServerProgress,
    required TResult Function(ConversationEvent_SyncServerFailed value)
    syncServerFailed,
    required TResult Function(ConversationEvent_NewConversation value)
    newConversation,
    required TResult Function(ConversationEvent_ConversationChanged value)
    conversationChanged,
    required TResult Function(
      ConversationEvent_TotalUnreadMessageCountChanged value,
    )
    totalUnreadMessageCountChanged,
    required TResult Function(
      ConversationEvent_ConversationUserInputStatusChanged value,
    )
    conversationUserInputStatusChanged,
  }) {
    return conversationChanged(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(ConversationEvent_SyncServerStart value)? syncServerStart,
    TResult? Function(ConversationEvent_SyncServerFinish value)?
    syncServerFinish,
    TResult? Function(ConversationEvent_SyncServerProgress value)?
    syncServerProgress,
    TResult? Function(ConversationEvent_SyncServerFailed value)?
    syncServerFailed,
    TResult? Function(ConversationEvent_NewConversation value)? newConversation,
    TResult? Function(ConversationEvent_ConversationChanged value)?
    conversationChanged,
    TResult? Function(ConversationEvent_TotalUnreadMessageCountChanged value)?
    totalUnreadMessageCountChanged,
    TResult? Function(
      ConversationEvent_ConversationUserInputStatusChanged value,
    )?
    conversationUserInputStatusChanged,
  }) {
    return conversationChanged?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(ConversationEvent_SyncServerStart value)? syncServerStart,
    TResult Function(ConversationEvent_SyncServerFinish value)?
    syncServerFinish,
    TResult Function(ConversationEvent_SyncServerProgress value)?
    syncServerProgress,
    TResult Function(ConversationEvent_SyncServerFailed value)?
    syncServerFailed,
    TResult Function(ConversationEvent_NewConversation value)? newConversation,
    TResult Function(ConversationEvent_ConversationChanged value)?
    conversationChanged,
    TResult Function(ConversationEvent_TotalUnreadMessageCountChanged value)?
    totalUnreadMessageCountChanged,
    TResult Function(
      ConversationEvent_ConversationUserInputStatusChanged value,
    )?
    conversationUserInputStatusChanged,
    required TResult orElse(),
  }) {
    if (conversationChanged != null) {
      return conversationChanged(this);
    }
    return orElse();
  }
}

abstract class ConversationEvent_ConversationChanged extends ConversationEvent {
  const factory ConversationEvent_ConversationChanged({
    required final String conversationList,
  }) = _$ConversationEvent_ConversationChangedImpl;
  const ConversationEvent_ConversationChanged._() : super._();

  String get conversationList;

  /// Create a copy of ConversationEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ConversationEvent_ConversationChangedImplCopyWith<
    _$ConversationEvent_ConversationChangedImpl
  >
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$ConversationEvent_TotalUnreadMessageCountChangedImplCopyWith<
  $Res
> {
  factory _$$ConversationEvent_TotalUnreadMessageCountChangedImplCopyWith(
    _$ConversationEvent_TotalUnreadMessageCountChangedImpl value,
    $Res Function(_$ConversationEvent_TotalUnreadMessageCountChangedImpl) then,
  ) =
      __$$ConversationEvent_TotalUnreadMessageCountChangedImplCopyWithImpl<
        $Res
      >;
  @useResult
  $Res call({int totalUnreadCount});
}

/// @nodoc
class __$$ConversationEvent_TotalUnreadMessageCountChangedImplCopyWithImpl<$Res>
    extends
        _$ConversationEventCopyWithImpl<
          $Res,
          _$ConversationEvent_TotalUnreadMessageCountChangedImpl
        >
    implements
        _$$ConversationEvent_TotalUnreadMessageCountChangedImplCopyWith<$Res> {
  __$$ConversationEvent_TotalUnreadMessageCountChangedImplCopyWithImpl(
    _$ConversationEvent_TotalUnreadMessageCountChangedImpl _value,
    $Res Function(_$ConversationEvent_TotalUnreadMessageCountChangedImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ConversationEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? totalUnreadCount = null}) {
    return _then(
      _$ConversationEvent_TotalUnreadMessageCountChangedImpl(
        totalUnreadCount: null == totalUnreadCount
            ? _value.totalUnreadCount
            : totalUnreadCount // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc

class _$ConversationEvent_TotalUnreadMessageCountChangedImpl
    extends ConversationEvent_TotalUnreadMessageCountChanged {
  const _$ConversationEvent_TotalUnreadMessageCountChangedImpl({
    required this.totalUnreadCount,
  }) : super._();

  @override
  final int totalUnreadCount;

  @override
  String toString() {
    return 'ConversationEvent.totalUnreadMessageCountChanged(totalUnreadCount: $totalUnreadCount)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ConversationEvent_TotalUnreadMessageCountChangedImpl &&
            (identical(other.totalUnreadCount, totalUnreadCount) ||
                other.totalUnreadCount == totalUnreadCount));
  }

  @override
  int get hashCode => Object.hash(runtimeType, totalUnreadCount);

  /// Create a copy of ConversationEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ConversationEvent_TotalUnreadMessageCountChangedImplCopyWith<
    _$ConversationEvent_TotalUnreadMessageCountChangedImpl
  >
  get copyWith =>
      __$$ConversationEvent_TotalUnreadMessageCountChangedImplCopyWithImpl<
        _$ConversationEvent_TotalUnreadMessageCountChangedImpl
      >(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(bool reinstalled) syncServerStart,
    required TResult Function(bool reinstalled) syncServerFinish,
    required TResult Function(int progress) syncServerProgress,
    required TResult Function(bool reinstalled) syncServerFailed,
    required TResult Function(String conversationList) newConversation,
    required TResult Function(String conversationList) conversationChanged,
    required TResult Function(int totalUnreadCount)
    totalUnreadMessageCountChanged,
    required TResult Function(String change) conversationUserInputStatusChanged,
  }) {
    return totalUnreadMessageCountChanged(totalUnreadCount);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(bool reinstalled)? syncServerStart,
    TResult? Function(bool reinstalled)? syncServerFinish,
    TResult? Function(int progress)? syncServerProgress,
    TResult? Function(bool reinstalled)? syncServerFailed,
    TResult? Function(String conversationList)? newConversation,
    TResult? Function(String conversationList)? conversationChanged,
    TResult? Function(int totalUnreadCount)? totalUnreadMessageCountChanged,
    TResult? Function(String change)? conversationUserInputStatusChanged,
  }) {
    return totalUnreadMessageCountChanged?.call(totalUnreadCount);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(bool reinstalled)? syncServerStart,
    TResult Function(bool reinstalled)? syncServerFinish,
    TResult Function(int progress)? syncServerProgress,
    TResult Function(bool reinstalled)? syncServerFailed,
    TResult Function(String conversationList)? newConversation,
    TResult Function(String conversationList)? conversationChanged,
    TResult Function(int totalUnreadCount)? totalUnreadMessageCountChanged,
    TResult Function(String change)? conversationUserInputStatusChanged,
    required TResult orElse(),
  }) {
    if (totalUnreadMessageCountChanged != null) {
      return totalUnreadMessageCountChanged(totalUnreadCount);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(ConversationEvent_SyncServerStart value)
    syncServerStart,
    required TResult Function(ConversationEvent_SyncServerFinish value)
    syncServerFinish,
    required TResult Function(ConversationEvent_SyncServerProgress value)
    syncServerProgress,
    required TResult Function(ConversationEvent_SyncServerFailed value)
    syncServerFailed,
    required TResult Function(ConversationEvent_NewConversation value)
    newConversation,
    required TResult Function(ConversationEvent_ConversationChanged value)
    conversationChanged,
    required TResult Function(
      ConversationEvent_TotalUnreadMessageCountChanged value,
    )
    totalUnreadMessageCountChanged,
    required TResult Function(
      ConversationEvent_ConversationUserInputStatusChanged value,
    )
    conversationUserInputStatusChanged,
  }) {
    return totalUnreadMessageCountChanged(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(ConversationEvent_SyncServerStart value)? syncServerStart,
    TResult? Function(ConversationEvent_SyncServerFinish value)?
    syncServerFinish,
    TResult? Function(ConversationEvent_SyncServerProgress value)?
    syncServerProgress,
    TResult? Function(ConversationEvent_SyncServerFailed value)?
    syncServerFailed,
    TResult? Function(ConversationEvent_NewConversation value)? newConversation,
    TResult? Function(ConversationEvent_ConversationChanged value)?
    conversationChanged,
    TResult? Function(ConversationEvent_TotalUnreadMessageCountChanged value)?
    totalUnreadMessageCountChanged,
    TResult? Function(
      ConversationEvent_ConversationUserInputStatusChanged value,
    )?
    conversationUserInputStatusChanged,
  }) {
    return totalUnreadMessageCountChanged?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(ConversationEvent_SyncServerStart value)? syncServerStart,
    TResult Function(ConversationEvent_SyncServerFinish value)?
    syncServerFinish,
    TResult Function(ConversationEvent_SyncServerProgress value)?
    syncServerProgress,
    TResult Function(ConversationEvent_SyncServerFailed value)?
    syncServerFailed,
    TResult Function(ConversationEvent_NewConversation value)? newConversation,
    TResult Function(ConversationEvent_ConversationChanged value)?
    conversationChanged,
    TResult Function(ConversationEvent_TotalUnreadMessageCountChanged value)?
    totalUnreadMessageCountChanged,
    TResult Function(
      ConversationEvent_ConversationUserInputStatusChanged value,
    )?
    conversationUserInputStatusChanged,
    required TResult orElse(),
  }) {
    if (totalUnreadMessageCountChanged != null) {
      return totalUnreadMessageCountChanged(this);
    }
    return orElse();
  }
}

abstract class ConversationEvent_TotalUnreadMessageCountChanged
    extends ConversationEvent {
  const factory ConversationEvent_TotalUnreadMessageCountChanged({
    required final int totalUnreadCount,
  }) = _$ConversationEvent_TotalUnreadMessageCountChangedImpl;
  const ConversationEvent_TotalUnreadMessageCountChanged._() : super._();

  int get totalUnreadCount;

  /// Create a copy of ConversationEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ConversationEvent_TotalUnreadMessageCountChangedImplCopyWith<
    _$ConversationEvent_TotalUnreadMessageCountChangedImpl
  >
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$ConversationEvent_ConversationUserInputStatusChangedImplCopyWith<
  $Res
> {
  factory _$$ConversationEvent_ConversationUserInputStatusChangedImplCopyWith(
    _$ConversationEvent_ConversationUserInputStatusChangedImpl value,
    $Res Function(_$ConversationEvent_ConversationUserInputStatusChangedImpl)
    then,
  ) =
      __$$ConversationEvent_ConversationUserInputStatusChangedImplCopyWithImpl<
        $Res
      >;
  @useResult
  $Res call({String change});
}

/// @nodoc
class __$$ConversationEvent_ConversationUserInputStatusChangedImplCopyWithImpl<
  $Res
>
    extends
        _$ConversationEventCopyWithImpl<
          $Res,
          _$ConversationEvent_ConversationUserInputStatusChangedImpl
        >
    implements
        _$$ConversationEvent_ConversationUserInputStatusChangedImplCopyWith<
          $Res
        > {
  __$$ConversationEvent_ConversationUserInputStatusChangedImplCopyWithImpl(
    _$ConversationEvent_ConversationUserInputStatusChangedImpl _value,
    $Res Function(_$ConversationEvent_ConversationUserInputStatusChangedImpl)
    _then,
  ) : super(_value, _then);

  /// Create a copy of ConversationEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? change = null}) {
    return _then(
      _$ConversationEvent_ConversationUserInputStatusChangedImpl(
        change: null == change
            ? _value.change
            : change // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc

class _$ConversationEvent_ConversationUserInputStatusChangedImpl
    extends ConversationEvent_ConversationUserInputStatusChanged {
  const _$ConversationEvent_ConversationUserInputStatusChangedImpl({
    required this.change,
  }) : super._();

  @override
  final String change;

  @override
  String toString() {
    return 'ConversationEvent.conversationUserInputStatusChanged(change: $change)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other
                is _$ConversationEvent_ConversationUserInputStatusChangedImpl &&
            (identical(other.change, change) || other.change == change));
  }

  @override
  int get hashCode => Object.hash(runtimeType, change);

  /// Create a copy of ConversationEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ConversationEvent_ConversationUserInputStatusChangedImplCopyWith<
    _$ConversationEvent_ConversationUserInputStatusChangedImpl
  >
  get copyWith =>
      __$$ConversationEvent_ConversationUserInputStatusChangedImplCopyWithImpl<
        _$ConversationEvent_ConversationUserInputStatusChangedImpl
      >(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(bool reinstalled) syncServerStart,
    required TResult Function(bool reinstalled) syncServerFinish,
    required TResult Function(int progress) syncServerProgress,
    required TResult Function(bool reinstalled) syncServerFailed,
    required TResult Function(String conversationList) newConversation,
    required TResult Function(String conversationList) conversationChanged,
    required TResult Function(int totalUnreadCount)
    totalUnreadMessageCountChanged,
    required TResult Function(String change) conversationUserInputStatusChanged,
  }) {
    return conversationUserInputStatusChanged(change);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(bool reinstalled)? syncServerStart,
    TResult? Function(bool reinstalled)? syncServerFinish,
    TResult? Function(int progress)? syncServerProgress,
    TResult? Function(bool reinstalled)? syncServerFailed,
    TResult? Function(String conversationList)? newConversation,
    TResult? Function(String conversationList)? conversationChanged,
    TResult? Function(int totalUnreadCount)? totalUnreadMessageCountChanged,
    TResult? Function(String change)? conversationUserInputStatusChanged,
  }) {
    return conversationUserInputStatusChanged?.call(change);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(bool reinstalled)? syncServerStart,
    TResult Function(bool reinstalled)? syncServerFinish,
    TResult Function(int progress)? syncServerProgress,
    TResult Function(bool reinstalled)? syncServerFailed,
    TResult Function(String conversationList)? newConversation,
    TResult Function(String conversationList)? conversationChanged,
    TResult Function(int totalUnreadCount)? totalUnreadMessageCountChanged,
    TResult Function(String change)? conversationUserInputStatusChanged,
    required TResult orElse(),
  }) {
    if (conversationUserInputStatusChanged != null) {
      return conversationUserInputStatusChanged(change);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(ConversationEvent_SyncServerStart value)
    syncServerStart,
    required TResult Function(ConversationEvent_SyncServerFinish value)
    syncServerFinish,
    required TResult Function(ConversationEvent_SyncServerProgress value)
    syncServerProgress,
    required TResult Function(ConversationEvent_SyncServerFailed value)
    syncServerFailed,
    required TResult Function(ConversationEvent_NewConversation value)
    newConversation,
    required TResult Function(ConversationEvent_ConversationChanged value)
    conversationChanged,
    required TResult Function(
      ConversationEvent_TotalUnreadMessageCountChanged value,
    )
    totalUnreadMessageCountChanged,
    required TResult Function(
      ConversationEvent_ConversationUserInputStatusChanged value,
    )
    conversationUserInputStatusChanged,
  }) {
    return conversationUserInputStatusChanged(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(ConversationEvent_SyncServerStart value)? syncServerStart,
    TResult? Function(ConversationEvent_SyncServerFinish value)?
    syncServerFinish,
    TResult? Function(ConversationEvent_SyncServerProgress value)?
    syncServerProgress,
    TResult? Function(ConversationEvent_SyncServerFailed value)?
    syncServerFailed,
    TResult? Function(ConversationEvent_NewConversation value)? newConversation,
    TResult? Function(ConversationEvent_ConversationChanged value)?
    conversationChanged,
    TResult? Function(ConversationEvent_TotalUnreadMessageCountChanged value)?
    totalUnreadMessageCountChanged,
    TResult? Function(
      ConversationEvent_ConversationUserInputStatusChanged value,
    )?
    conversationUserInputStatusChanged,
  }) {
    return conversationUserInputStatusChanged?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(ConversationEvent_SyncServerStart value)? syncServerStart,
    TResult Function(ConversationEvent_SyncServerFinish value)?
    syncServerFinish,
    TResult Function(ConversationEvent_SyncServerProgress value)?
    syncServerProgress,
    TResult Function(ConversationEvent_SyncServerFailed value)?
    syncServerFailed,
    TResult Function(ConversationEvent_NewConversation value)? newConversation,
    TResult Function(ConversationEvent_ConversationChanged value)?
    conversationChanged,
    TResult Function(ConversationEvent_TotalUnreadMessageCountChanged value)?
    totalUnreadMessageCountChanged,
    TResult Function(
      ConversationEvent_ConversationUserInputStatusChanged value,
    )?
    conversationUserInputStatusChanged,
    required TResult orElse(),
  }) {
    if (conversationUserInputStatusChanged != null) {
      return conversationUserInputStatusChanged(this);
    }
    return orElse();
  }
}

abstract class ConversationEvent_ConversationUserInputStatusChanged
    extends ConversationEvent {
  const factory ConversationEvent_ConversationUserInputStatusChanged({
    required final String change,
  }) = _$ConversationEvent_ConversationUserInputStatusChangedImpl;
  const ConversationEvent_ConversationUserInputStatusChanged._() : super._();

  String get change;

  /// Create a copy of ConversationEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ConversationEvent_ConversationUserInputStatusChangedImplCopyWith<
    _$ConversationEvent_ConversationUserInputStatusChangedImpl
  >
  get copyWith => throw _privateConstructorUsedError;
}
