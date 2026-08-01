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
    required TResult Function(List<LocalConversation> field0) changed,
    required TResult Function(List<String> field0) deleted,
    required TResult Function(List<LocalConversation> field0) new_,
    required TResult Function(int field0) totalUnreadCountChanged,
    required TResult Function() syncStarted,
    required TResult Function() syncFinished,
    required TResult Function(String field0) syncFailed,
    required TResult Function(int progress, String message) syncProgress,
    required TResult Function(
      String conversationId,
      String userId,
      Int32List platformIds,
    )
    userInputStatusChanged,
    required TResult Function(String conversationId)
    updateLatestMessageReadState,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(List<LocalConversation> field0)? changed,
    TResult? Function(List<String> field0)? deleted,
    TResult? Function(List<LocalConversation> field0)? new_,
    TResult? Function(int field0)? totalUnreadCountChanged,
    TResult? Function()? syncStarted,
    TResult? Function()? syncFinished,
    TResult? Function(String field0)? syncFailed,
    TResult? Function(int progress, String message)? syncProgress,
    TResult? Function(
      String conversationId,
      String userId,
      Int32List platformIds,
    )?
    userInputStatusChanged,
    TResult? Function(String conversationId)? updateLatestMessageReadState,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(List<LocalConversation> field0)? changed,
    TResult Function(List<String> field0)? deleted,
    TResult Function(List<LocalConversation> field0)? new_,
    TResult Function(int field0)? totalUnreadCountChanged,
    TResult Function()? syncStarted,
    TResult Function()? syncFinished,
    TResult Function(String field0)? syncFailed,
    TResult Function(int progress, String message)? syncProgress,
    TResult Function(
      String conversationId,
      String userId,
      Int32List platformIds,
    )?
    userInputStatusChanged,
    TResult Function(String conversationId)? updateLatestMessageReadState,
    required TResult orElse(),
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(ConversationEvent_Changed value) changed,
    required TResult Function(ConversationEvent_Deleted value) deleted,
    required TResult Function(ConversationEvent_New value) new_,
    required TResult Function(ConversationEvent_TotalUnreadCountChanged value)
    totalUnreadCountChanged,
    required TResult Function(ConversationEvent_SyncStarted value) syncStarted,
    required TResult Function(ConversationEvent_SyncFinished value)
    syncFinished,
    required TResult Function(ConversationEvent_SyncFailed value) syncFailed,
    required TResult Function(ConversationEvent_SyncProgress value)
    syncProgress,
    required TResult Function(ConversationEvent_UserInputStatusChanged value)
    userInputStatusChanged,
    required TResult Function(
      ConversationEvent_UpdateLatestMessageReadState value,
    )
    updateLatestMessageReadState,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(ConversationEvent_Changed value)? changed,
    TResult? Function(ConversationEvent_Deleted value)? deleted,
    TResult? Function(ConversationEvent_New value)? new_,
    TResult? Function(ConversationEvent_TotalUnreadCountChanged value)?
    totalUnreadCountChanged,
    TResult? Function(ConversationEvent_SyncStarted value)? syncStarted,
    TResult? Function(ConversationEvent_SyncFinished value)? syncFinished,
    TResult? Function(ConversationEvent_SyncFailed value)? syncFailed,
    TResult? Function(ConversationEvent_SyncProgress value)? syncProgress,
    TResult? Function(ConversationEvent_UserInputStatusChanged value)?
    userInputStatusChanged,
    TResult? Function(ConversationEvent_UpdateLatestMessageReadState value)?
    updateLatestMessageReadState,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(ConversationEvent_Changed value)? changed,
    TResult Function(ConversationEvent_Deleted value)? deleted,
    TResult Function(ConversationEvent_New value)? new_,
    TResult Function(ConversationEvent_TotalUnreadCountChanged value)?
    totalUnreadCountChanged,
    TResult Function(ConversationEvent_SyncStarted value)? syncStarted,
    TResult Function(ConversationEvent_SyncFinished value)? syncFinished,
    TResult Function(ConversationEvent_SyncFailed value)? syncFailed,
    TResult Function(ConversationEvent_SyncProgress value)? syncProgress,
    TResult Function(ConversationEvent_UserInputStatusChanged value)?
    userInputStatusChanged,
    TResult Function(ConversationEvent_UpdateLatestMessageReadState value)?
    updateLatestMessageReadState,
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
abstract class _$$ConversationEvent_ChangedImplCopyWith<$Res> {
  factory _$$ConversationEvent_ChangedImplCopyWith(
    _$ConversationEvent_ChangedImpl value,
    $Res Function(_$ConversationEvent_ChangedImpl) then,
  ) = __$$ConversationEvent_ChangedImplCopyWithImpl<$Res>;
  @useResult
  $Res call({List<LocalConversation> field0});
}

/// @nodoc
class __$$ConversationEvent_ChangedImplCopyWithImpl<$Res>
    extends
        _$ConversationEventCopyWithImpl<$Res, _$ConversationEvent_ChangedImpl>
    implements _$$ConversationEvent_ChangedImplCopyWith<$Res> {
  __$$ConversationEvent_ChangedImplCopyWithImpl(
    _$ConversationEvent_ChangedImpl _value,
    $Res Function(_$ConversationEvent_ChangedImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ConversationEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? field0 = null}) {
    return _then(
      _$ConversationEvent_ChangedImpl(
        null == field0
            ? _value._field0
            : field0 // ignore: cast_nullable_to_non_nullable
                  as List<LocalConversation>,
      ),
    );
  }
}

/// @nodoc

class _$ConversationEvent_ChangedImpl extends ConversationEvent_Changed {
  const _$ConversationEvent_ChangedImpl(final List<LocalConversation> field0)
    : _field0 = field0,
      super._();

  final List<LocalConversation> _field0;
  @override
  List<LocalConversation> get field0 {
    if (_field0 is EqualUnmodifiableListView) return _field0;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_field0);
  }

  @override
  String toString() {
    return 'ConversationEvent.changed(field0: $field0)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ConversationEvent_ChangedImpl &&
            const DeepCollectionEquality().equals(other._field0, _field0));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, const DeepCollectionEquality().hash(_field0));

  /// Create a copy of ConversationEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ConversationEvent_ChangedImplCopyWith<_$ConversationEvent_ChangedImpl>
  get copyWith =>
      __$$ConversationEvent_ChangedImplCopyWithImpl<
        _$ConversationEvent_ChangedImpl
      >(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(List<LocalConversation> field0) changed,
    required TResult Function(List<String> field0) deleted,
    required TResult Function(List<LocalConversation> field0) new_,
    required TResult Function(int field0) totalUnreadCountChanged,
    required TResult Function() syncStarted,
    required TResult Function() syncFinished,
    required TResult Function(String field0) syncFailed,
    required TResult Function(int progress, String message) syncProgress,
    required TResult Function(
      String conversationId,
      String userId,
      Int32List platformIds,
    )
    userInputStatusChanged,
    required TResult Function(String conversationId)
    updateLatestMessageReadState,
  }) {
    return changed(field0);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(List<LocalConversation> field0)? changed,
    TResult? Function(List<String> field0)? deleted,
    TResult? Function(List<LocalConversation> field0)? new_,
    TResult? Function(int field0)? totalUnreadCountChanged,
    TResult? Function()? syncStarted,
    TResult? Function()? syncFinished,
    TResult? Function(String field0)? syncFailed,
    TResult? Function(int progress, String message)? syncProgress,
    TResult? Function(
      String conversationId,
      String userId,
      Int32List platformIds,
    )?
    userInputStatusChanged,
    TResult? Function(String conversationId)? updateLatestMessageReadState,
  }) {
    return changed?.call(field0);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(List<LocalConversation> field0)? changed,
    TResult Function(List<String> field0)? deleted,
    TResult Function(List<LocalConversation> field0)? new_,
    TResult Function(int field0)? totalUnreadCountChanged,
    TResult Function()? syncStarted,
    TResult Function()? syncFinished,
    TResult Function(String field0)? syncFailed,
    TResult Function(int progress, String message)? syncProgress,
    TResult Function(
      String conversationId,
      String userId,
      Int32List platformIds,
    )?
    userInputStatusChanged,
    TResult Function(String conversationId)? updateLatestMessageReadState,
    required TResult orElse(),
  }) {
    if (changed != null) {
      return changed(field0);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(ConversationEvent_Changed value) changed,
    required TResult Function(ConversationEvent_Deleted value) deleted,
    required TResult Function(ConversationEvent_New value) new_,
    required TResult Function(ConversationEvent_TotalUnreadCountChanged value)
    totalUnreadCountChanged,
    required TResult Function(ConversationEvent_SyncStarted value) syncStarted,
    required TResult Function(ConversationEvent_SyncFinished value)
    syncFinished,
    required TResult Function(ConversationEvent_SyncFailed value) syncFailed,
    required TResult Function(ConversationEvent_SyncProgress value)
    syncProgress,
    required TResult Function(ConversationEvent_UserInputStatusChanged value)
    userInputStatusChanged,
    required TResult Function(
      ConversationEvent_UpdateLatestMessageReadState value,
    )
    updateLatestMessageReadState,
  }) {
    return changed(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(ConversationEvent_Changed value)? changed,
    TResult? Function(ConversationEvent_Deleted value)? deleted,
    TResult? Function(ConversationEvent_New value)? new_,
    TResult? Function(ConversationEvent_TotalUnreadCountChanged value)?
    totalUnreadCountChanged,
    TResult? Function(ConversationEvent_SyncStarted value)? syncStarted,
    TResult? Function(ConversationEvent_SyncFinished value)? syncFinished,
    TResult? Function(ConversationEvent_SyncFailed value)? syncFailed,
    TResult? Function(ConversationEvent_SyncProgress value)? syncProgress,
    TResult? Function(ConversationEvent_UserInputStatusChanged value)?
    userInputStatusChanged,
    TResult? Function(ConversationEvent_UpdateLatestMessageReadState value)?
    updateLatestMessageReadState,
  }) {
    return changed?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(ConversationEvent_Changed value)? changed,
    TResult Function(ConversationEvent_Deleted value)? deleted,
    TResult Function(ConversationEvent_New value)? new_,
    TResult Function(ConversationEvent_TotalUnreadCountChanged value)?
    totalUnreadCountChanged,
    TResult Function(ConversationEvent_SyncStarted value)? syncStarted,
    TResult Function(ConversationEvent_SyncFinished value)? syncFinished,
    TResult Function(ConversationEvent_SyncFailed value)? syncFailed,
    TResult Function(ConversationEvent_SyncProgress value)? syncProgress,
    TResult Function(ConversationEvent_UserInputStatusChanged value)?
    userInputStatusChanged,
    TResult Function(ConversationEvent_UpdateLatestMessageReadState value)?
    updateLatestMessageReadState,
    required TResult orElse(),
  }) {
    if (changed != null) {
      return changed(this);
    }
    return orElse();
  }
}

abstract class ConversationEvent_Changed extends ConversationEvent {
  const factory ConversationEvent_Changed(
    final List<LocalConversation> field0,
  ) = _$ConversationEvent_ChangedImpl;
  const ConversationEvent_Changed._() : super._();

  List<LocalConversation> get field0;

  /// Create a copy of ConversationEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ConversationEvent_ChangedImplCopyWith<_$ConversationEvent_ChangedImpl>
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$ConversationEvent_DeletedImplCopyWith<$Res> {
  factory _$$ConversationEvent_DeletedImplCopyWith(
    _$ConversationEvent_DeletedImpl value,
    $Res Function(_$ConversationEvent_DeletedImpl) then,
  ) = __$$ConversationEvent_DeletedImplCopyWithImpl<$Res>;
  @useResult
  $Res call({List<String> field0});
}

/// @nodoc
class __$$ConversationEvent_DeletedImplCopyWithImpl<$Res>
    extends
        _$ConversationEventCopyWithImpl<$Res, _$ConversationEvent_DeletedImpl>
    implements _$$ConversationEvent_DeletedImplCopyWith<$Res> {
  __$$ConversationEvent_DeletedImplCopyWithImpl(
    _$ConversationEvent_DeletedImpl _value,
    $Res Function(_$ConversationEvent_DeletedImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ConversationEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? field0 = null}) {
    return _then(
      _$ConversationEvent_DeletedImpl(
        null == field0
            ? _value._field0
            : field0 // ignore: cast_nullable_to_non_nullable
                  as List<String>,
      ),
    );
  }
}

/// @nodoc

class _$ConversationEvent_DeletedImpl extends ConversationEvent_Deleted {
  const _$ConversationEvent_DeletedImpl(final List<String> field0)
    : _field0 = field0,
      super._();

  final List<String> _field0;
  @override
  List<String> get field0 {
    if (_field0 is EqualUnmodifiableListView) return _field0;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_field0);
  }

  @override
  String toString() {
    return 'ConversationEvent.deleted(field0: $field0)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ConversationEvent_DeletedImpl &&
            const DeepCollectionEquality().equals(other._field0, _field0));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, const DeepCollectionEquality().hash(_field0));

  /// Create a copy of ConversationEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ConversationEvent_DeletedImplCopyWith<_$ConversationEvent_DeletedImpl>
  get copyWith =>
      __$$ConversationEvent_DeletedImplCopyWithImpl<
        _$ConversationEvent_DeletedImpl
      >(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(List<LocalConversation> field0) changed,
    required TResult Function(List<String> field0) deleted,
    required TResult Function(List<LocalConversation> field0) new_,
    required TResult Function(int field0) totalUnreadCountChanged,
    required TResult Function() syncStarted,
    required TResult Function() syncFinished,
    required TResult Function(String field0) syncFailed,
    required TResult Function(int progress, String message) syncProgress,
    required TResult Function(
      String conversationId,
      String userId,
      Int32List platformIds,
    )
    userInputStatusChanged,
    required TResult Function(String conversationId)
    updateLatestMessageReadState,
  }) {
    return deleted(field0);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(List<LocalConversation> field0)? changed,
    TResult? Function(List<String> field0)? deleted,
    TResult? Function(List<LocalConversation> field0)? new_,
    TResult? Function(int field0)? totalUnreadCountChanged,
    TResult? Function()? syncStarted,
    TResult? Function()? syncFinished,
    TResult? Function(String field0)? syncFailed,
    TResult? Function(int progress, String message)? syncProgress,
    TResult? Function(
      String conversationId,
      String userId,
      Int32List platformIds,
    )?
    userInputStatusChanged,
    TResult? Function(String conversationId)? updateLatestMessageReadState,
  }) {
    return deleted?.call(field0);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(List<LocalConversation> field0)? changed,
    TResult Function(List<String> field0)? deleted,
    TResult Function(List<LocalConversation> field0)? new_,
    TResult Function(int field0)? totalUnreadCountChanged,
    TResult Function()? syncStarted,
    TResult Function()? syncFinished,
    TResult Function(String field0)? syncFailed,
    TResult Function(int progress, String message)? syncProgress,
    TResult Function(
      String conversationId,
      String userId,
      Int32List platformIds,
    )?
    userInputStatusChanged,
    TResult Function(String conversationId)? updateLatestMessageReadState,
    required TResult orElse(),
  }) {
    if (deleted != null) {
      return deleted(field0);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(ConversationEvent_Changed value) changed,
    required TResult Function(ConversationEvent_Deleted value) deleted,
    required TResult Function(ConversationEvent_New value) new_,
    required TResult Function(ConversationEvent_TotalUnreadCountChanged value)
    totalUnreadCountChanged,
    required TResult Function(ConversationEvent_SyncStarted value) syncStarted,
    required TResult Function(ConversationEvent_SyncFinished value)
    syncFinished,
    required TResult Function(ConversationEvent_SyncFailed value) syncFailed,
    required TResult Function(ConversationEvent_SyncProgress value)
    syncProgress,
    required TResult Function(ConversationEvent_UserInputStatusChanged value)
    userInputStatusChanged,
    required TResult Function(
      ConversationEvent_UpdateLatestMessageReadState value,
    )
    updateLatestMessageReadState,
  }) {
    return deleted(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(ConversationEvent_Changed value)? changed,
    TResult? Function(ConversationEvent_Deleted value)? deleted,
    TResult? Function(ConversationEvent_New value)? new_,
    TResult? Function(ConversationEvent_TotalUnreadCountChanged value)?
    totalUnreadCountChanged,
    TResult? Function(ConversationEvent_SyncStarted value)? syncStarted,
    TResult? Function(ConversationEvent_SyncFinished value)? syncFinished,
    TResult? Function(ConversationEvent_SyncFailed value)? syncFailed,
    TResult? Function(ConversationEvent_SyncProgress value)? syncProgress,
    TResult? Function(ConversationEvent_UserInputStatusChanged value)?
    userInputStatusChanged,
    TResult? Function(ConversationEvent_UpdateLatestMessageReadState value)?
    updateLatestMessageReadState,
  }) {
    return deleted?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(ConversationEvent_Changed value)? changed,
    TResult Function(ConversationEvent_Deleted value)? deleted,
    TResult Function(ConversationEvent_New value)? new_,
    TResult Function(ConversationEvent_TotalUnreadCountChanged value)?
    totalUnreadCountChanged,
    TResult Function(ConversationEvent_SyncStarted value)? syncStarted,
    TResult Function(ConversationEvent_SyncFinished value)? syncFinished,
    TResult Function(ConversationEvent_SyncFailed value)? syncFailed,
    TResult Function(ConversationEvent_SyncProgress value)? syncProgress,
    TResult Function(ConversationEvent_UserInputStatusChanged value)?
    userInputStatusChanged,
    TResult Function(ConversationEvent_UpdateLatestMessageReadState value)?
    updateLatestMessageReadState,
    required TResult orElse(),
  }) {
    if (deleted != null) {
      return deleted(this);
    }
    return orElse();
  }
}

abstract class ConversationEvent_Deleted extends ConversationEvent {
  const factory ConversationEvent_Deleted(final List<String> field0) =
      _$ConversationEvent_DeletedImpl;
  const ConversationEvent_Deleted._() : super._();

  List<String> get field0;

  /// Create a copy of ConversationEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ConversationEvent_DeletedImplCopyWith<_$ConversationEvent_DeletedImpl>
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$ConversationEvent_NewImplCopyWith<$Res> {
  factory _$$ConversationEvent_NewImplCopyWith(
    _$ConversationEvent_NewImpl value,
    $Res Function(_$ConversationEvent_NewImpl) then,
  ) = __$$ConversationEvent_NewImplCopyWithImpl<$Res>;
  @useResult
  $Res call({List<LocalConversation> field0});
}

/// @nodoc
class __$$ConversationEvent_NewImplCopyWithImpl<$Res>
    extends _$ConversationEventCopyWithImpl<$Res, _$ConversationEvent_NewImpl>
    implements _$$ConversationEvent_NewImplCopyWith<$Res> {
  __$$ConversationEvent_NewImplCopyWithImpl(
    _$ConversationEvent_NewImpl _value,
    $Res Function(_$ConversationEvent_NewImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ConversationEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? field0 = null}) {
    return _then(
      _$ConversationEvent_NewImpl(
        null == field0
            ? _value._field0
            : field0 // ignore: cast_nullable_to_non_nullable
                  as List<LocalConversation>,
      ),
    );
  }
}

/// @nodoc

class _$ConversationEvent_NewImpl extends ConversationEvent_New {
  const _$ConversationEvent_NewImpl(final List<LocalConversation> field0)
    : _field0 = field0,
      super._();

  final List<LocalConversation> _field0;
  @override
  List<LocalConversation> get field0 {
    if (_field0 is EqualUnmodifiableListView) return _field0;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_field0);
  }

  @override
  String toString() {
    return 'ConversationEvent.new_(field0: $field0)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ConversationEvent_NewImpl &&
            const DeepCollectionEquality().equals(other._field0, _field0));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, const DeepCollectionEquality().hash(_field0));

  /// Create a copy of ConversationEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ConversationEvent_NewImplCopyWith<_$ConversationEvent_NewImpl>
  get copyWith =>
      __$$ConversationEvent_NewImplCopyWithImpl<_$ConversationEvent_NewImpl>(
        this,
        _$identity,
      );

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(List<LocalConversation> field0) changed,
    required TResult Function(List<String> field0) deleted,
    required TResult Function(List<LocalConversation> field0) new_,
    required TResult Function(int field0) totalUnreadCountChanged,
    required TResult Function() syncStarted,
    required TResult Function() syncFinished,
    required TResult Function(String field0) syncFailed,
    required TResult Function(int progress, String message) syncProgress,
    required TResult Function(
      String conversationId,
      String userId,
      Int32List platformIds,
    )
    userInputStatusChanged,
    required TResult Function(String conversationId)
    updateLatestMessageReadState,
  }) {
    return new_(field0);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(List<LocalConversation> field0)? changed,
    TResult? Function(List<String> field0)? deleted,
    TResult? Function(List<LocalConversation> field0)? new_,
    TResult? Function(int field0)? totalUnreadCountChanged,
    TResult? Function()? syncStarted,
    TResult? Function()? syncFinished,
    TResult? Function(String field0)? syncFailed,
    TResult? Function(int progress, String message)? syncProgress,
    TResult? Function(
      String conversationId,
      String userId,
      Int32List platformIds,
    )?
    userInputStatusChanged,
    TResult? Function(String conversationId)? updateLatestMessageReadState,
  }) {
    return new_?.call(field0);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(List<LocalConversation> field0)? changed,
    TResult Function(List<String> field0)? deleted,
    TResult Function(List<LocalConversation> field0)? new_,
    TResult Function(int field0)? totalUnreadCountChanged,
    TResult Function()? syncStarted,
    TResult Function()? syncFinished,
    TResult Function(String field0)? syncFailed,
    TResult Function(int progress, String message)? syncProgress,
    TResult Function(
      String conversationId,
      String userId,
      Int32List platformIds,
    )?
    userInputStatusChanged,
    TResult Function(String conversationId)? updateLatestMessageReadState,
    required TResult orElse(),
  }) {
    if (new_ != null) {
      return new_(field0);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(ConversationEvent_Changed value) changed,
    required TResult Function(ConversationEvent_Deleted value) deleted,
    required TResult Function(ConversationEvent_New value) new_,
    required TResult Function(ConversationEvent_TotalUnreadCountChanged value)
    totalUnreadCountChanged,
    required TResult Function(ConversationEvent_SyncStarted value) syncStarted,
    required TResult Function(ConversationEvent_SyncFinished value)
    syncFinished,
    required TResult Function(ConversationEvent_SyncFailed value) syncFailed,
    required TResult Function(ConversationEvent_SyncProgress value)
    syncProgress,
    required TResult Function(ConversationEvent_UserInputStatusChanged value)
    userInputStatusChanged,
    required TResult Function(
      ConversationEvent_UpdateLatestMessageReadState value,
    )
    updateLatestMessageReadState,
  }) {
    return new_(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(ConversationEvent_Changed value)? changed,
    TResult? Function(ConversationEvent_Deleted value)? deleted,
    TResult? Function(ConversationEvent_New value)? new_,
    TResult? Function(ConversationEvent_TotalUnreadCountChanged value)?
    totalUnreadCountChanged,
    TResult? Function(ConversationEvent_SyncStarted value)? syncStarted,
    TResult? Function(ConversationEvent_SyncFinished value)? syncFinished,
    TResult? Function(ConversationEvent_SyncFailed value)? syncFailed,
    TResult? Function(ConversationEvent_SyncProgress value)? syncProgress,
    TResult? Function(ConversationEvent_UserInputStatusChanged value)?
    userInputStatusChanged,
    TResult? Function(ConversationEvent_UpdateLatestMessageReadState value)?
    updateLatestMessageReadState,
  }) {
    return new_?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(ConversationEvent_Changed value)? changed,
    TResult Function(ConversationEvent_Deleted value)? deleted,
    TResult Function(ConversationEvent_New value)? new_,
    TResult Function(ConversationEvent_TotalUnreadCountChanged value)?
    totalUnreadCountChanged,
    TResult Function(ConversationEvent_SyncStarted value)? syncStarted,
    TResult Function(ConversationEvent_SyncFinished value)? syncFinished,
    TResult Function(ConversationEvent_SyncFailed value)? syncFailed,
    TResult Function(ConversationEvent_SyncProgress value)? syncProgress,
    TResult Function(ConversationEvent_UserInputStatusChanged value)?
    userInputStatusChanged,
    TResult Function(ConversationEvent_UpdateLatestMessageReadState value)?
    updateLatestMessageReadState,
    required TResult orElse(),
  }) {
    if (new_ != null) {
      return new_(this);
    }
    return orElse();
  }
}

abstract class ConversationEvent_New extends ConversationEvent {
  const factory ConversationEvent_New(final List<LocalConversation> field0) =
      _$ConversationEvent_NewImpl;
  const ConversationEvent_New._() : super._();

  List<LocalConversation> get field0;

  /// Create a copy of ConversationEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ConversationEvent_NewImplCopyWith<_$ConversationEvent_NewImpl>
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$ConversationEvent_TotalUnreadCountChangedImplCopyWith<$Res> {
  factory _$$ConversationEvent_TotalUnreadCountChangedImplCopyWith(
    _$ConversationEvent_TotalUnreadCountChangedImpl value,
    $Res Function(_$ConversationEvent_TotalUnreadCountChangedImpl) then,
  ) = __$$ConversationEvent_TotalUnreadCountChangedImplCopyWithImpl<$Res>;
  @useResult
  $Res call({int field0});
}

/// @nodoc
class __$$ConversationEvent_TotalUnreadCountChangedImplCopyWithImpl<$Res>
    extends
        _$ConversationEventCopyWithImpl<
          $Res,
          _$ConversationEvent_TotalUnreadCountChangedImpl
        >
    implements _$$ConversationEvent_TotalUnreadCountChangedImplCopyWith<$Res> {
  __$$ConversationEvent_TotalUnreadCountChangedImplCopyWithImpl(
    _$ConversationEvent_TotalUnreadCountChangedImpl _value,
    $Res Function(_$ConversationEvent_TotalUnreadCountChangedImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ConversationEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? field0 = null}) {
    return _then(
      _$ConversationEvent_TotalUnreadCountChangedImpl(
        null == field0
            ? _value.field0
            : field0 // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc

class _$ConversationEvent_TotalUnreadCountChangedImpl
    extends ConversationEvent_TotalUnreadCountChanged {
  const _$ConversationEvent_TotalUnreadCountChangedImpl(this.field0)
    : super._();

  @override
  final int field0;

  @override
  String toString() {
    return 'ConversationEvent.totalUnreadCountChanged(field0: $field0)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ConversationEvent_TotalUnreadCountChangedImpl &&
            (identical(other.field0, field0) || other.field0 == field0));
  }

  @override
  int get hashCode => Object.hash(runtimeType, field0);

  /// Create a copy of ConversationEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ConversationEvent_TotalUnreadCountChangedImplCopyWith<
    _$ConversationEvent_TotalUnreadCountChangedImpl
  >
  get copyWith =>
      __$$ConversationEvent_TotalUnreadCountChangedImplCopyWithImpl<
        _$ConversationEvent_TotalUnreadCountChangedImpl
      >(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(List<LocalConversation> field0) changed,
    required TResult Function(List<String> field0) deleted,
    required TResult Function(List<LocalConversation> field0) new_,
    required TResult Function(int field0) totalUnreadCountChanged,
    required TResult Function() syncStarted,
    required TResult Function() syncFinished,
    required TResult Function(String field0) syncFailed,
    required TResult Function(int progress, String message) syncProgress,
    required TResult Function(
      String conversationId,
      String userId,
      Int32List platformIds,
    )
    userInputStatusChanged,
    required TResult Function(String conversationId)
    updateLatestMessageReadState,
  }) {
    return totalUnreadCountChanged(field0);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(List<LocalConversation> field0)? changed,
    TResult? Function(List<String> field0)? deleted,
    TResult? Function(List<LocalConversation> field0)? new_,
    TResult? Function(int field0)? totalUnreadCountChanged,
    TResult? Function()? syncStarted,
    TResult? Function()? syncFinished,
    TResult? Function(String field0)? syncFailed,
    TResult? Function(int progress, String message)? syncProgress,
    TResult? Function(
      String conversationId,
      String userId,
      Int32List platformIds,
    )?
    userInputStatusChanged,
    TResult? Function(String conversationId)? updateLatestMessageReadState,
  }) {
    return totalUnreadCountChanged?.call(field0);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(List<LocalConversation> field0)? changed,
    TResult Function(List<String> field0)? deleted,
    TResult Function(List<LocalConversation> field0)? new_,
    TResult Function(int field0)? totalUnreadCountChanged,
    TResult Function()? syncStarted,
    TResult Function()? syncFinished,
    TResult Function(String field0)? syncFailed,
    TResult Function(int progress, String message)? syncProgress,
    TResult Function(
      String conversationId,
      String userId,
      Int32List platformIds,
    )?
    userInputStatusChanged,
    TResult Function(String conversationId)? updateLatestMessageReadState,
    required TResult orElse(),
  }) {
    if (totalUnreadCountChanged != null) {
      return totalUnreadCountChanged(field0);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(ConversationEvent_Changed value) changed,
    required TResult Function(ConversationEvent_Deleted value) deleted,
    required TResult Function(ConversationEvent_New value) new_,
    required TResult Function(ConversationEvent_TotalUnreadCountChanged value)
    totalUnreadCountChanged,
    required TResult Function(ConversationEvent_SyncStarted value) syncStarted,
    required TResult Function(ConversationEvent_SyncFinished value)
    syncFinished,
    required TResult Function(ConversationEvent_SyncFailed value) syncFailed,
    required TResult Function(ConversationEvent_SyncProgress value)
    syncProgress,
    required TResult Function(ConversationEvent_UserInputStatusChanged value)
    userInputStatusChanged,
    required TResult Function(
      ConversationEvent_UpdateLatestMessageReadState value,
    )
    updateLatestMessageReadState,
  }) {
    return totalUnreadCountChanged(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(ConversationEvent_Changed value)? changed,
    TResult? Function(ConversationEvent_Deleted value)? deleted,
    TResult? Function(ConversationEvent_New value)? new_,
    TResult? Function(ConversationEvent_TotalUnreadCountChanged value)?
    totalUnreadCountChanged,
    TResult? Function(ConversationEvent_SyncStarted value)? syncStarted,
    TResult? Function(ConversationEvent_SyncFinished value)? syncFinished,
    TResult? Function(ConversationEvent_SyncFailed value)? syncFailed,
    TResult? Function(ConversationEvent_SyncProgress value)? syncProgress,
    TResult? Function(ConversationEvent_UserInputStatusChanged value)?
    userInputStatusChanged,
    TResult? Function(ConversationEvent_UpdateLatestMessageReadState value)?
    updateLatestMessageReadState,
  }) {
    return totalUnreadCountChanged?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(ConversationEvent_Changed value)? changed,
    TResult Function(ConversationEvent_Deleted value)? deleted,
    TResult Function(ConversationEvent_New value)? new_,
    TResult Function(ConversationEvent_TotalUnreadCountChanged value)?
    totalUnreadCountChanged,
    TResult Function(ConversationEvent_SyncStarted value)? syncStarted,
    TResult Function(ConversationEvent_SyncFinished value)? syncFinished,
    TResult Function(ConversationEvent_SyncFailed value)? syncFailed,
    TResult Function(ConversationEvent_SyncProgress value)? syncProgress,
    TResult Function(ConversationEvent_UserInputStatusChanged value)?
    userInputStatusChanged,
    TResult Function(ConversationEvent_UpdateLatestMessageReadState value)?
    updateLatestMessageReadState,
    required TResult orElse(),
  }) {
    if (totalUnreadCountChanged != null) {
      return totalUnreadCountChanged(this);
    }
    return orElse();
  }
}

abstract class ConversationEvent_TotalUnreadCountChanged
    extends ConversationEvent {
  const factory ConversationEvent_TotalUnreadCountChanged(final int field0) =
      _$ConversationEvent_TotalUnreadCountChangedImpl;
  const ConversationEvent_TotalUnreadCountChanged._() : super._();

  int get field0;

  /// Create a copy of ConversationEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ConversationEvent_TotalUnreadCountChangedImplCopyWith<
    _$ConversationEvent_TotalUnreadCountChangedImpl
  >
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$ConversationEvent_SyncStartedImplCopyWith<$Res> {
  factory _$$ConversationEvent_SyncStartedImplCopyWith(
    _$ConversationEvent_SyncStartedImpl value,
    $Res Function(_$ConversationEvent_SyncStartedImpl) then,
  ) = __$$ConversationEvent_SyncStartedImplCopyWithImpl<$Res>;
}

/// @nodoc
class __$$ConversationEvent_SyncStartedImplCopyWithImpl<$Res>
    extends
        _$ConversationEventCopyWithImpl<
          $Res,
          _$ConversationEvent_SyncStartedImpl
        >
    implements _$$ConversationEvent_SyncStartedImplCopyWith<$Res> {
  __$$ConversationEvent_SyncStartedImplCopyWithImpl(
    _$ConversationEvent_SyncStartedImpl _value,
    $Res Function(_$ConversationEvent_SyncStartedImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ConversationEvent
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc

class _$ConversationEvent_SyncStartedImpl
    extends ConversationEvent_SyncStarted {
  const _$ConversationEvent_SyncStartedImpl() : super._();

  @override
  String toString() {
    return 'ConversationEvent.syncStarted()';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ConversationEvent_SyncStartedImpl);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(List<LocalConversation> field0) changed,
    required TResult Function(List<String> field0) deleted,
    required TResult Function(List<LocalConversation> field0) new_,
    required TResult Function(int field0) totalUnreadCountChanged,
    required TResult Function() syncStarted,
    required TResult Function() syncFinished,
    required TResult Function(String field0) syncFailed,
    required TResult Function(int progress, String message) syncProgress,
    required TResult Function(
      String conversationId,
      String userId,
      Int32List platformIds,
    )
    userInputStatusChanged,
    required TResult Function(String conversationId)
    updateLatestMessageReadState,
  }) {
    return syncStarted();
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(List<LocalConversation> field0)? changed,
    TResult? Function(List<String> field0)? deleted,
    TResult? Function(List<LocalConversation> field0)? new_,
    TResult? Function(int field0)? totalUnreadCountChanged,
    TResult? Function()? syncStarted,
    TResult? Function()? syncFinished,
    TResult? Function(String field0)? syncFailed,
    TResult? Function(int progress, String message)? syncProgress,
    TResult? Function(
      String conversationId,
      String userId,
      Int32List platformIds,
    )?
    userInputStatusChanged,
    TResult? Function(String conversationId)? updateLatestMessageReadState,
  }) {
    return syncStarted?.call();
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(List<LocalConversation> field0)? changed,
    TResult Function(List<String> field0)? deleted,
    TResult Function(List<LocalConversation> field0)? new_,
    TResult Function(int field0)? totalUnreadCountChanged,
    TResult Function()? syncStarted,
    TResult Function()? syncFinished,
    TResult Function(String field0)? syncFailed,
    TResult Function(int progress, String message)? syncProgress,
    TResult Function(
      String conversationId,
      String userId,
      Int32List platformIds,
    )?
    userInputStatusChanged,
    TResult Function(String conversationId)? updateLatestMessageReadState,
    required TResult orElse(),
  }) {
    if (syncStarted != null) {
      return syncStarted();
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(ConversationEvent_Changed value) changed,
    required TResult Function(ConversationEvent_Deleted value) deleted,
    required TResult Function(ConversationEvent_New value) new_,
    required TResult Function(ConversationEvent_TotalUnreadCountChanged value)
    totalUnreadCountChanged,
    required TResult Function(ConversationEvent_SyncStarted value) syncStarted,
    required TResult Function(ConversationEvent_SyncFinished value)
    syncFinished,
    required TResult Function(ConversationEvent_SyncFailed value) syncFailed,
    required TResult Function(ConversationEvent_SyncProgress value)
    syncProgress,
    required TResult Function(ConversationEvent_UserInputStatusChanged value)
    userInputStatusChanged,
    required TResult Function(
      ConversationEvent_UpdateLatestMessageReadState value,
    )
    updateLatestMessageReadState,
  }) {
    return syncStarted(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(ConversationEvent_Changed value)? changed,
    TResult? Function(ConversationEvent_Deleted value)? deleted,
    TResult? Function(ConversationEvent_New value)? new_,
    TResult? Function(ConversationEvent_TotalUnreadCountChanged value)?
    totalUnreadCountChanged,
    TResult? Function(ConversationEvent_SyncStarted value)? syncStarted,
    TResult? Function(ConversationEvent_SyncFinished value)? syncFinished,
    TResult? Function(ConversationEvent_SyncFailed value)? syncFailed,
    TResult? Function(ConversationEvent_SyncProgress value)? syncProgress,
    TResult? Function(ConversationEvent_UserInputStatusChanged value)?
    userInputStatusChanged,
    TResult? Function(ConversationEvent_UpdateLatestMessageReadState value)?
    updateLatestMessageReadState,
  }) {
    return syncStarted?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(ConversationEvent_Changed value)? changed,
    TResult Function(ConversationEvent_Deleted value)? deleted,
    TResult Function(ConversationEvent_New value)? new_,
    TResult Function(ConversationEvent_TotalUnreadCountChanged value)?
    totalUnreadCountChanged,
    TResult Function(ConversationEvent_SyncStarted value)? syncStarted,
    TResult Function(ConversationEvent_SyncFinished value)? syncFinished,
    TResult Function(ConversationEvent_SyncFailed value)? syncFailed,
    TResult Function(ConversationEvent_SyncProgress value)? syncProgress,
    TResult Function(ConversationEvent_UserInputStatusChanged value)?
    userInputStatusChanged,
    TResult Function(ConversationEvent_UpdateLatestMessageReadState value)?
    updateLatestMessageReadState,
    required TResult orElse(),
  }) {
    if (syncStarted != null) {
      return syncStarted(this);
    }
    return orElse();
  }
}

abstract class ConversationEvent_SyncStarted extends ConversationEvent {
  const factory ConversationEvent_SyncStarted() =
      _$ConversationEvent_SyncStartedImpl;
  const ConversationEvent_SyncStarted._() : super._();
}

/// @nodoc
abstract class _$$ConversationEvent_SyncFinishedImplCopyWith<$Res> {
  factory _$$ConversationEvent_SyncFinishedImplCopyWith(
    _$ConversationEvent_SyncFinishedImpl value,
    $Res Function(_$ConversationEvent_SyncFinishedImpl) then,
  ) = __$$ConversationEvent_SyncFinishedImplCopyWithImpl<$Res>;
}

/// @nodoc
class __$$ConversationEvent_SyncFinishedImplCopyWithImpl<$Res>
    extends
        _$ConversationEventCopyWithImpl<
          $Res,
          _$ConversationEvent_SyncFinishedImpl
        >
    implements _$$ConversationEvent_SyncFinishedImplCopyWith<$Res> {
  __$$ConversationEvent_SyncFinishedImplCopyWithImpl(
    _$ConversationEvent_SyncFinishedImpl _value,
    $Res Function(_$ConversationEvent_SyncFinishedImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ConversationEvent
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc

class _$ConversationEvent_SyncFinishedImpl
    extends ConversationEvent_SyncFinished {
  const _$ConversationEvent_SyncFinishedImpl() : super._();

  @override
  String toString() {
    return 'ConversationEvent.syncFinished()';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ConversationEvent_SyncFinishedImpl);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(List<LocalConversation> field0) changed,
    required TResult Function(List<String> field0) deleted,
    required TResult Function(List<LocalConversation> field0) new_,
    required TResult Function(int field0) totalUnreadCountChanged,
    required TResult Function() syncStarted,
    required TResult Function() syncFinished,
    required TResult Function(String field0) syncFailed,
    required TResult Function(int progress, String message) syncProgress,
    required TResult Function(
      String conversationId,
      String userId,
      Int32List platformIds,
    )
    userInputStatusChanged,
    required TResult Function(String conversationId)
    updateLatestMessageReadState,
  }) {
    return syncFinished();
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(List<LocalConversation> field0)? changed,
    TResult? Function(List<String> field0)? deleted,
    TResult? Function(List<LocalConversation> field0)? new_,
    TResult? Function(int field0)? totalUnreadCountChanged,
    TResult? Function()? syncStarted,
    TResult? Function()? syncFinished,
    TResult? Function(String field0)? syncFailed,
    TResult? Function(int progress, String message)? syncProgress,
    TResult? Function(
      String conversationId,
      String userId,
      Int32List platformIds,
    )?
    userInputStatusChanged,
    TResult? Function(String conversationId)? updateLatestMessageReadState,
  }) {
    return syncFinished?.call();
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(List<LocalConversation> field0)? changed,
    TResult Function(List<String> field0)? deleted,
    TResult Function(List<LocalConversation> field0)? new_,
    TResult Function(int field0)? totalUnreadCountChanged,
    TResult Function()? syncStarted,
    TResult Function()? syncFinished,
    TResult Function(String field0)? syncFailed,
    TResult Function(int progress, String message)? syncProgress,
    TResult Function(
      String conversationId,
      String userId,
      Int32List platformIds,
    )?
    userInputStatusChanged,
    TResult Function(String conversationId)? updateLatestMessageReadState,
    required TResult orElse(),
  }) {
    if (syncFinished != null) {
      return syncFinished();
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(ConversationEvent_Changed value) changed,
    required TResult Function(ConversationEvent_Deleted value) deleted,
    required TResult Function(ConversationEvent_New value) new_,
    required TResult Function(ConversationEvent_TotalUnreadCountChanged value)
    totalUnreadCountChanged,
    required TResult Function(ConversationEvent_SyncStarted value) syncStarted,
    required TResult Function(ConversationEvent_SyncFinished value)
    syncFinished,
    required TResult Function(ConversationEvent_SyncFailed value) syncFailed,
    required TResult Function(ConversationEvent_SyncProgress value)
    syncProgress,
    required TResult Function(ConversationEvent_UserInputStatusChanged value)
    userInputStatusChanged,
    required TResult Function(
      ConversationEvent_UpdateLatestMessageReadState value,
    )
    updateLatestMessageReadState,
  }) {
    return syncFinished(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(ConversationEvent_Changed value)? changed,
    TResult? Function(ConversationEvent_Deleted value)? deleted,
    TResult? Function(ConversationEvent_New value)? new_,
    TResult? Function(ConversationEvent_TotalUnreadCountChanged value)?
    totalUnreadCountChanged,
    TResult? Function(ConversationEvent_SyncStarted value)? syncStarted,
    TResult? Function(ConversationEvent_SyncFinished value)? syncFinished,
    TResult? Function(ConversationEvent_SyncFailed value)? syncFailed,
    TResult? Function(ConversationEvent_SyncProgress value)? syncProgress,
    TResult? Function(ConversationEvent_UserInputStatusChanged value)?
    userInputStatusChanged,
    TResult? Function(ConversationEvent_UpdateLatestMessageReadState value)?
    updateLatestMessageReadState,
  }) {
    return syncFinished?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(ConversationEvent_Changed value)? changed,
    TResult Function(ConversationEvent_Deleted value)? deleted,
    TResult Function(ConversationEvent_New value)? new_,
    TResult Function(ConversationEvent_TotalUnreadCountChanged value)?
    totalUnreadCountChanged,
    TResult Function(ConversationEvent_SyncStarted value)? syncStarted,
    TResult Function(ConversationEvent_SyncFinished value)? syncFinished,
    TResult Function(ConversationEvent_SyncFailed value)? syncFailed,
    TResult Function(ConversationEvent_SyncProgress value)? syncProgress,
    TResult Function(ConversationEvent_UserInputStatusChanged value)?
    userInputStatusChanged,
    TResult Function(ConversationEvent_UpdateLatestMessageReadState value)?
    updateLatestMessageReadState,
    required TResult orElse(),
  }) {
    if (syncFinished != null) {
      return syncFinished(this);
    }
    return orElse();
  }
}

abstract class ConversationEvent_SyncFinished extends ConversationEvent {
  const factory ConversationEvent_SyncFinished() =
      _$ConversationEvent_SyncFinishedImpl;
  const ConversationEvent_SyncFinished._() : super._();
}

/// @nodoc
abstract class _$$ConversationEvent_SyncFailedImplCopyWith<$Res> {
  factory _$$ConversationEvent_SyncFailedImplCopyWith(
    _$ConversationEvent_SyncFailedImpl value,
    $Res Function(_$ConversationEvent_SyncFailedImpl) then,
  ) = __$$ConversationEvent_SyncFailedImplCopyWithImpl<$Res>;
  @useResult
  $Res call({String field0});
}

/// @nodoc
class __$$ConversationEvent_SyncFailedImplCopyWithImpl<$Res>
    extends
        _$ConversationEventCopyWithImpl<
          $Res,
          _$ConversationEvent_SyncFailedImpl
        >
    implements _$$ConversationEvent_SyncFailedImplCopyWith<$Res> {
  __$$ConversationEvent_SyncFailedImplCopyWithImpl(
    _$ConversationEvent_SyncFailedImpl _value,
    $Res Function(_$ConversationEvent_SyncFailedImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ConversationEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? field0 = null}) {
    return _then(
      _$ConversationEvent_SyncFailedImpl(
        null == field0
            ? _value.field0
            : field0 // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc

class _$ConversationEvent_SyncFailedImpl extends ConversationEvent_SyncFailed {
  const _$ConversationEvent_SyncFailedImpl(this.field0) : super._();

  @override
  final String field0;

  @override
  String toString() {
    return 'ConversationEvent.syncFailed(field0: $field0)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ConversationEvent_SyncFailedImpl &&
            (identical(other.field0, field0) || other.field0 == field0));
  }

  @override
  int get hashCode => Object.hash(runtimeType, field0);

  /// Create a copy of ConversationEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ConversationEvent_SyncFailedImplCopyWith<
    _$ConversationEvent_SyncFailedImpl
  >
  get copyWith =>
      __$$ConversationEvent_SyncFailedImplCopyWithImpl<
        _$ConversationEvent_SyncFailedImpl
      >(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(List<LocalConversation> field0) changed,
    required TResult Function(List<String> field0) deleted,
    required TResult Function(List<LocalConversation> field0) new_,
    required TResult Function(int field0) totalUnreadCountChanged,
    required TResult Function() syncStarted,
    required TResult Function() syncFinished,
    required TResult Function(String field0) syncFailed,
    required TResult Function(int progress, String message) syncProgress,
    required TResult Function(
      String conversationId,
      String userId,
      Int32List platformIds,
    )
    userInputStatusChanged,
    required TResult Function(String conversationId)
    updateLatestMessageReadState,
  }) {
    return syncFailed(field0);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(List<LocalConversation> field0)? changed,
    TResult? Function(List<String> field0)? deleted,
    TResult? Function(List<LocalConversation> field0)? new_,
    TResult? Function(int field0)? totalUnreadCountChanged,
    TResult? Function()? syncStarted,
    TResult? Function()? syncFinished,
    TResult? Function(String field0)? syncFailed,
    TResult? Function(int progress, String message)? syncProgress,
    TResult? Function(
      String conversationId,
      String userId,
      Int32List platformIds,
    )?
    userInputStatusChanged,
    TResult? Function(String conversationId)? updateLatestMessageReadState,
  }) {
    return syncFailed?.call(field0);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(List<LocalConversation> field0)? changed,
    TResult Function(List<String> field0)? deleted,
    TResult Function(List<LocalConversation> field0)? new_,
    TResult Function(int field0)? totalUnreadCountChanged,
    TResult Function()? syncStarted,
    TResult Function()? syncFinished,
    TResult Function(String field0)? syncFailed,
    TResult Function(int progress, String message)? syncProgress,
    TResult Function(
      String conversationId,
      String userId,
      Int32List platformIds,
    )?
    userInputStatusChanged,
    TResult Function(String conversationId)? updateLatestMessageReadState,
    required TResult orElse(),
  }) {
    if (syncFailed != null) {
      return syncFailed(field0);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(ConversationEvent_Changed value) changed,
    required TResult Function(ConversationEvent_Deleted value) deleted,
    required TResult Function(ConversationEvent_New value) new_,
    required TResult Function(ConversationEvent_TotalUnreadCountChanged value)
    totalUnreadCountChanged,
    required TResult Function(ConversationEvent_SyncStarted value) syncStarted,
    required TResult Function(ConversationEvent_SyncFinished value)
    syncFinished,
    required TResult Function(ConversationEvent_SyncFailed value) syncFailed,
    required TResult Function(ConversationEvent_SyncProgress value)
    syncProgress,
    required TResult Function(ConversationEvent_UserInputStatusChanged value)
    userInputStatusChanged,
    required TResult Function(
      ConversationEvent_UpdateLatestMessageReadState value,
    )
    updateLatestMessageReadState,
  }) {
    return syncFailed(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(ConversationEvent_Changed value)? changed,
    TResult? Function(ConversationEvent_Deleted value)? deleted,
    TResult? Function(ConversationEvent_New value)? new_,
    TResult? Function(ConversationEvent_TotalUnreadCountChanged value)?
    totalUnreadCountChanged,
    TResult? Function(ConversationEvent_SyncStarted value)? syncStarted,
    TResult? Function(ConversationEvent_SyncFinished value)? syncFinished,
    TResult? Function(ConversationEvent_SyncFailed value)? syncFailed,
    TResult? Function(ConversationEvent_SyncProgress value)? syncProgress,
    TResult? Function(ConversationEvent_UserInputStatusChanged value)?
    userInputStatusChanged,
    TResult? Function(ConversationEvent_UpdateLatestMessageReadState value)?
    updateLatestMessageReadState,
  }) {
    return syncFailed?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(ConversationEvent_Changed value)? changed,
    TResult Function(ConversationEvent_Deleted value)? deleted,
    TResult Function(ConversationEvent_New value)? new_,
    TResult Function(ConversationEvent_TotalUnreadCountChanged value)?
    totalUnreadCountChanged,
    TResult Function(ConversationEvent_SyncStarted value)? syncStarted,
    TResult Function(ConversationEvent_SyncFinished value)? syncFinished,
    TResult Function(ConversationEvent_SyncFailed value)? syncFailed,
    TResult Function(ConversationEvent_SyncProgress value)? syncProgress,
    TResult Function(ConversationEvent_UserInputStatusChanged value)?
    userInputStatusChanged,
    TResult Function(ConversationEvent_UpdateLatestMessageReadState value)?
    updateLatestMessageReadState,
    required TResult orElse(),
  }) {
    if (syncFailed != null) {
      return syncFailed(this);
    }
    return orElse();
  }
}

abstract class ConversationEvent_SyncFailed extends ConversationEvent {
  const factory ConversationEvent_SyncFailed(final String field0) =
      _$ConversationEvent_SyncFailedImpl;
  const ConversationEvent_SyncFailed._() : super._();

  String get field0;

  /// Create a copy of ConversationEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ConversationEvent_SyncFailedImplCopyWith<
    _$ConversationEvent_SyncFailedImpl
  >
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$ConversationEvent_SyncProgressImplCopyWith<$Res> {
  factory _$$ConversationEvent_SyncProgressImplCopyWith(
    _$ConversationEvent_SyncProgressImpl value,
    $Res Function(_$ConversationEvent_SyncProgressImpl) then,
  ) = __$$ConversationEvent_SyncProgressImplCopyWithImpl<$Res>;
  @useResult
  $Res call({int progress, String message});
}

/// @nodoc
class __$$ConversationEvent_SyncProgressImplCopyWithImpl<$Res>
    extends
        _$ConversationEventCopyWithImpl<
          $Res,
          _$ConversationEvent_SyncProgressImpl
        >
    implements _$$ConversationEvent_SyncProgressImplCopyWith<$Res> {
  __$$ConversationEvent_SyncProgressImplCopyWithImpl(
    _$ConversationEvent_SyncProgressImpl _value,
    $Res Function(_$ConversationEvent_SyncProgressImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ConversationEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? progress = null, Object? message = null}) {
    return _then(
      _$ConversationEvent_SyncProgressImpl(
        progress: null == progress
            ? _value.progress
            : progress // ignore: cast_nullable_to_non_nullable
                  as int,
        message: null == message
            ? _value.message
            : message // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc

class _$ConversationEvent_SyncProgressImpl
    extends ConversationEvent_SyncProgress {
  const _$ConversationEvent_SyncProgressImpl({
    required this.progress,
    required this.message,
  }) : super._();

  @override
  final int progress;
  @override
  final String message;

  @override
  String toString() {
    return 'ConversationEvent.syncProgress(progress: $progress, message: $message)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ConversationEvent_SyncProgressImpl &&
            (identical(other.progress, progress) ||
                other.progress == progress) &&
            (identical(other.message, message) || other.message == message));
  }

  @override
  int get hashCode => Object.hash(runtimeType, progress, message);

  /// Create a copy of ConversationEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ConversationEvent_SyncProgressImplCopyWith<
    _$ConversationEvent_SyncProgressImpl
  >
  get copyWith =>
      __$$ConversationEvent_SyncProgressImplCopyWithImpl<
        _$ConversationEvent_SyncProgressImpl
      >(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(List<LocalConversation> field0) changed,
    required TResult Function(List<String> field0) deleted,
    required TResult Function(List<LocalConversation> field0) new_,
    required TResult Function(int field0) totalUnreadCountChanged,
    required TResult Function() syncStarted,
    required TResult Function() syncFinished,
    required TResult Function(String field0) syncFailed,
    required TResult Function(int progress, String message) syncProgress,
    required TResult Function(
      String conversationId,
      String userId,
      Int32List platformIds,
    )
    userInputStatusChanged,
    required TResult Function(String conversationId)
    updateLatestMessageReadState,
  }) {
    return syncProgress(progress, message);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(List<LocalConversation> field0)? changed,
    TResult? Function(List<String> field0)? deleted,
    TResult? Function(List<LocalConversation> field0)? new_,
    TResult? Function(int field0)? totalUnreadCountChanged,
    TResult? Function()? syncStarted,
    TResult? Function()? syncFinished,
    TResult? Function(String field0)? syncFailed,
    TResult? Function(int progress, String message)? syncProgress,
    TResult? Function(
      String conversationId,
      String userId,
      Int32List platformIds,
    )?
    userInputStatusChanged,
    TResult? Function(String conversationId)? updateLatestMessageReadState,
  }) {
    return syncProgress?.call(progress, message);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(List<LocalConversation> field0)? changed,
    TResult Function(List<String> field0)? deleted,
    TResult Function(List<LocalConversation> field0)? new_,
    TResult Function(int field0)? totalUnreadCountChanged,
    TResult Function()? syncStarted,
    TResult Function()? syncFinished,
    TResult Function(String field0)? syncFailed,
    TResult Function(int progress, String message)? syncProgress,
    TResult Function(
      String conversationId,
      String userId,
      Int32List platformIds,
    )?
    userInputStatusChanged,
    TResult Function(String conversationId)? updateLatestMessageReadState,
    required TResult orElse(),
  }) {
    if (syncProgress != null) {
      return syncProgress(progress, message);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(ConversationEvent_Changed value) changed,
    required TResult Function(ConversationEvent_Deleted value) deleted,
    required TResult Function(ConversationEvent_New value) new_,
    required TResult Function(ConversationEvent_TotalUnreadCountChanged value)
    totalUnreadCountChanged,
    required TResult Function(ConversationEvent_SyncStarted value) syncStarted,
    required TResult Function(ConversationEvent_SyncFinished value)
    syncFinished,
    required TResult Function(ConversationEvent_SyncFailed value) syncFailed,
    required TResult Function(ConversationEvent_SyncProgress value)
    syncProgress,
    required TResult Function(ConversationEvent_UserInputStatusChanged value)
    userInputStatusChanged,
    required TResult Function(
      ConversationEvent_UpdateLatestMessageReadState value,
    )
    updateLatestMessageReadState,
  }) {
    return syncProgress(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(ConversationEvent_Changed value)? changed,
    TResult? Function(ConversationEvent_Deleted value)? deleted,
    TResult? Function(ConversationEvent_New value)? new_,
    TResult? Function(ConversationEvent_TotalUnreadCountChanged value)?
    totalUnreadCountChanged,
    TResult? Function(ConversationEvent_SyncStarted value)? syncStarted,
    TResult? Function(ConversationEvent_SyncFinished value)? syncFinished,
    TResult? Function(ConversationEvent_SyncFailed value)? syncFailed,
    TResult? Function(ConversationEvent_SyncProgress value)? syncProgress,
    TResult? Function(ConversationEvent_UserInputStatusChanged value)?
    userInputStatusChanged,
    TResult? Function(ConversationEvent_UpdateLatestMessageReadState value)?
    updateLatestMessageReadState,
  }) {
    return syncProgress?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(ConversationEvent_Changed value)? changed,
    TResult Function(ConversationEvent_Deleted value)? deleted,
    TResult Function(ConversationEvent_New value)? new_,
    TResult Function(ConversationEvent_TotalUnreadCountChanged value)?
    totalUnreadCountChanged,
    TResult Function(ConversationEvent_SyncStarted value)? syncStarted,
    TResult Function(ConversationEvent_SyncFinished value)? syncFinished,
    TResult Function(ConversationEvent_SyncFailed value)? syncFailed,
    TResult Function(ConversationEvent_SyncProgress value)? syncProgress,
    TResult Function(ConversationEvent_UserInputStatusChanged value)?
    userInputStatusChanged,
    TResult Function(ConversationEvent_UpdateLatestMessageReadState value)?
    updateLatestMessageReadState,
    required TResult orElse(),
  }) {
    if (syncProgress != null) {
      return syncProgress(this);
    }
    return orElse();
  }
}

abstract class ConversationEvent_SyncProgress extends ConversationEvent {
  const factory ConversationEvent_SyncProgress({
    required final int progress,
    required final String message,
  }) = _$ConversationEvent_SyncProgressImpl;
  const ConversationEvent_SyncProgress._() : super._();

  int get progress;
  String get message;

  /// Create a copy of ConversationEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ConversationEvent_SyncProgressImplCopyWith<
    _$ConversationEvent_SyncProgressImpl
  >
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$ConversationEvent_UserInputStatusChangedImplCopyWith<$Res> {
  factory _$$ConversationEvent_UserInputStatusChangedImplCopyWith(
    _$ConversationEvent_UserInputStatusChangedImpl value,
    $Res Function(_$ConversationEvent_UserInputStatusChangedImpl) then,
  ) = __$$ConversationEvent_UserInputStatusChangedImplCopyWithImpl<$Res>;
  @useResult
  $Res call({String conversationId, String userId, Int32List platformIds});
}

/// @nodoc
class __$$ConversationEvent_UserInputStatusChangedImplCopyWithImpl<$Res>
    extends
        _$ConversationEventCopyWithImpl<
          $Res,
          _$ConversationEvent_UserInputStatusChangedImpl
        >
    implements _$$ConversationEvent_UserInputStatusChangedImplCopyWith<$Res> {
  __$$ConversationEvent_UserInputStatusChangedImplCopyWithImpl(
    _$ConversationEvent_UserInputStatusChangedImpl _value,
    $Res Function(_$ConversationEvent_UserInputStatusChangedImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ConversationEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? conversationId = null,
    Object? userId = null,
    Object? platformIds = null,
  }) {
    return _then(
      _$ConversationEvent_UserInputStatusChangedImpl(
        conversationId: null == conversationId
            ? _value.conversationId
            : conversationId // ignore: cast_nullable_to_non_nullable
                  as String,
        userId: null == userId
            ? _value.userId
            : userId // ignore: cast_nullable_to_non_nullable
                  as String,
        platformIds: null == platformIds
            ? _value.platformIds
            : platformIds // ignore: cast_nullable_to_non_nullable
                  as Int32List,
      ),
    );
  }
}

/// @nodoc

class _$ConversationEvent_UserInputStatusChangedImpl
    extends ConversationEvent_UserInputStatusChanged {
  const _$ConversationEvent_UserInputStatusChangedImpl({
    required this.conversationId,
    required this.userId,
    required this.platformIds,
  }) : super._();

  @override
  final String conversationId;
  @override
  final String userId;
  @override
  final Int32List platformIds;

  @override
  String toString() {
    return 'ConversationEvent.userInputStatusChanged(conversationId: $conversationId, userId: $userId, platformIds: $platformIds)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ConversationEvent_UserInputStatusChangedImpl &&
            (identical(other.conversationId, conversationId) ||
                other.conversationId == conversationId) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            const DeepCollectionEquality().equals(
              other.platformIds,
              platformIds,
            ));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    conversationId,
    userId,
    const DeepCollectionEquality().hash(platformIds),
  );

  /// Create a copy of ConversationEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ConversationEvent_UserInputStatusChangedImplCopyWith<
    _$ConversationEvent_UserInputStatusChangedImpl
  >
  get copyWith =>
      __$$ConversationEvent_UserInputStatusChangedImplCopyWithImpl<
        _$ConversationEvent_UserInputStatusChangedImpl
      >(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(List<LocalConversation> field0) changed,
    required TResult Function(List<String> field0) deleted,
    required TResult Function(List<LocalConversation> field0) new_,
    required TResult Function(int field0) totalUnreadCountChanged,
    required TResult Function() syncStarted,
    required TResult Function() syncFinished,
    required TResult Function(String field0) syncFailed,
    required TResult Function(int progress, String message) syncProgress,
    required TResult Function(
      String conversationId,
      String userId,
      Int32List platformIds,
    )
    userInputStatusChanged,
    required TResult Function(String conversationId)
    updateLatestMessageReadState,
  }) {
    return userInputStatusChanged(conversationId, userId, platformIds);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(List<LocalConversation> field0)? changed,
    TResult? Function(List<String> field0)? deleted,
    TResult? Function(List<LocalConversation> field0)? new_,
    TResult? Function(int field0)? totalUnreadCountChanged,
    TResult? Function()? syncStarted,
    TResult? Function()? syncFinished,
    TResult? Function(String field0)? syncFailed,
    TResult? Function(int progress, String message)? syncProgress,
    TResult? Function(
      String conversationId,
      String userId,
      Int32List platformIds,
    )?
    userInputStatusChanged,
    TResult? Function(String conversationId)? updateLatestMessageReadState,
  }) {
    return userInputStatusChanged?.call(conversationId, userId, platformIds);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(List<LocalConversation> field0)? changed,
    TResult Function(List<String> field0)? deleted,
    TResult Function(List<LocalConversation> field0)? new_,
    TResult Function(int field0)? totalUnreadCountChanged,
    TResult Function()? syncStarted,
    TResult Function()? syncFinished,
    TResult Function(String field0)? syncFailed,
    TResult Function(int progress, String message)? syncProgress,
    TResult Function(
      String conversationId,
      String userId,
      Int32List platformIds,
    )?
    userInputStatusChanged,
    TResult Function(String conversationId)? updateLatestMessageReadState,
    required TResult orElse(),
  }) {
    if (userInputStatusChanged != null) {
      return userInputStatusChanged(conversationId, userId, platformIds);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(ConversationEvent_Changed value) changed,
    required TResult Function(ConversationEvent_Deleted value) deleted,
    required TResult Function(ConversationEvent_New value) new_,
    required TResult Function(ConversationEvent_TotalUnreadCountChanged value)
    totalUnreadCountChanged,
    required TResult Function(ConversationEvent_SyncStarted value) syncStarted,
    required TResult Function(ConversationEvent_SyncFinished value)
    syncFinished,
    required TResult Function(ConversationEvent_SyncFailed value) syncFailed,
    required TResult Function(ConversationEvent_SyncProgress value)
    syncProgress,
    required TResult Function(ConversationEvent_UserInputStatusChanged value)
    userInputStatusChanged,
    required TResult Function(
      ConversationEvent_UpdateLatestMessageReadState value,
    )
    updateLatestMessageReadState,
  }) {
    return userInputStatusChanged(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(ConversationEvent_Changed value)? changed,
    TResult? Function(ConversationEvent_Deleted value)? deleted,
    TResult? Function(ConversationEvent_New value)? new_,
    TResult? Function(ConversationEvent_TotalUnreadCountChanged value)?
    totalUnreadCountChanged,
    TResult? Function(ConversationEvent_SyncStarted value)? syncStarted,
    TResult? Function(ConversationEvent_SyncFinished value)? syncFinished,
    TResult? Function(ConversationEvent_SyncFailed value)? syncFailed,
    TResult? Function(ConversationEvent_SyncProgress value)? syncProgress,
    TResult? Function(ConversationEvent_UserInputStatusChanged value)?
    userInputStatusChanged,
    TResult? Function(ConversationEvent_UpdateLatestMessageReadState value)?
    updateLatestMessageReadState,
  }) {
    return userInputStatusChanged?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(ConversationEvent_Changed value)? changed,
    TResult Function(ConversationEvent_Deleted value)? deleted,
    TResult Function(ConversationEvent_New value)? new_,
    TResult Function(ConversationEvent_TotalUnreadCountChanged value)?
    totalUnreadCountChanged,
    TResult Function(ConversationEvent_SyncStarted value)? syncStarted,
    TResult Function(ConversationEvent_SyncFinished value)? syncFinished,
    TResult Function(ConversationEvent_SyncFailed value)? syncFailed,
    TResult Function(ConversationEvent_SyncProgress value)? syncProgress,
    TResult Function(ConversationEvent_UserInputStatusChanged value)?
    userInputStatusChanged,
    TResult Function(ConversationEvent_UpdateLatestMessageReadState value)?
    updateLatestMessageReadState,
    required TResult orElse(),
  }) {
    if (userInputStatusChanged != null) {
      return userInputStatusChanged(this);
    }
    return orElse();
  }
}

abstract class ConversationEvent_UserInputStatusChanged
    extends ConversationEvent {
  const factory ConversationEvent_UserInputStatusChanged({
    required final String conversationId,
    required final String userId,
    required final Int32List platformIds,
  }) = _$ConversationEvent_UserInputStatusChangedImpl;
  const ConversationEvent_UserInputStatusChanged._() : super._();

  String get conversationId;
  String get userId;
  Int32List get platformIds;

  /// Create a copy of ConversationEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ConversationEvent_UserInputStatusChangedImplCopyWith<
    _$ConversationEvent_UserInputStatusChangedImpl
  >
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$ConversationEvent_UpdateLatestMessageReadStateImplCopyWith<
  $Res
> {
  factory _$$ConversationEvent_UpdateLatestMessageReadStateImplCopyWith(
    _$ConversationEvent_UpdateLatestMessageReadStateImpl value,
    $Res Function(_$ConversationEvent_UpdateLatestMessageReadStateImpl) then,
  ) = __$$ConversationEvent_UpdateLatestMessageReadStateImplCopyWithImpl<$Res>;
  @useResult
  $Res call({String conversationId});
}

/// @nodoc
class __$$ConversationEvent_UpdateLatestMessageReadStateImplCopyWithImpl<$Res>
    extends
        _$ConversationEventCopyWithImpl<
          $Res,
          _$ConversationEvent_UpdateLatestMessageReadStateImpl
        >
    implements
        _$$ConversationEvent_UpdateLatestMessageReadStateImplCopyWith<$Res> {
  __$$ConversationEvent_UpdateLatestMessageReadStateImplCopyWithImpl(
    _$ConversationEvent_UpdateLatestMessageReadStateImpl _value,
    $Res Function(_$ConversationEvent_UpdateLatestMessageReadStateImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ConversationEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? conversationId = null}) {
    return _then(
      _$ConversationEvent_UpdateLatestMessageReadStateImpl(
        conversationId: null == conversationId
            ? _value.conversationId
            : conversationId // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc

class _$ConversationEvent_UpdateLatestMessageReadStateImpl
    extends ConversationEvent_UpdateLatestMessageReadState {
  const _$ConversationEvent_UpdateLatestMessageReadStateImpl({
    required this.conversationId,
  }) : super._();

  @override
  final String conversationId;

  @override
  String toString() {
    return 'ConversationEvent.updateLatestMessageReadState(conversationId: $conversationId)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ConversationEvent_UpdateLatestMessageReadStateImpl &&
            (identical(other.conversationId, conversationId) ||
                other.conversationId == conversationId));
  }

  @override
  int get hashCode => Object.hash(runtimeType, conversationId);

  /// Create a copy of ConversationEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ConversationEvent_UpdateLatestMessageReadStateImplCopyWith<
    _$ConversationEvent_UpdateLatestMessageReadStateImpl
  >
  get copyWith =>
      __$$ConversationEvent_UpdateLatestMessageReadStateImplCopyWithImpl<
        _$ConversationEvent_UpdateLatestMessageReadStateImpl
      >(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(List<LocalConversation> field0) changed,
    required TResult Function(List<String> field0) deleted,
    required TResult Function(List<LocalConversation> field0) new_,
    required TResult Function(int field0) totalUnreadCountChanged,
    required TResult Function() syncStarted,
    required TResult Function() syncFinished,
    required TResult Function(String field0) syncFailed,
    required TResult Function(int progress, String message) syncProgress,
    required TResult Function(
      String conversationId,
      String userId,
      Int32List platformIds,
    )
    userInputStatusChanged,
    required TResult Function(String conversationId)
    updateLatestMessageReadState,
  }) {
    return updateLatestMessageReadState(conversationId);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(List<LocalConversation> field0)? changed,
    TResult? Function(List<String> field0)? deleted,
    TResult? Function(List<LocalConversation> field0)? new_,
    TResult? Function(int field0)? totalUnreadCountChanged,
    TResult? Function()? syncStarted,
    TResult? Function()? syncFinished,
    TResult? Function(String field0)? syncFailed,
    TResult? Function(int progress, String message)? syncProgress,
    TResult? Function(
      String conversationId,
      String userId,
      Int32List platformIds,
    )?
    userInputStatusChanged,
    TResult? Function(String conversationId)? updateLatestMessageReadState,
  }) {
    return updateLatestMessageReadState?.call(conversationId);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(List<LocalConversation> field0)? changed,
    TResult Function(List<String> field0)? deleted,
    TResult Function(List<LocalConversation> field0)? new_,
    TResult Function(int field0)? totalUnreadCountChanged,
    TResult Function()? syncStarted,
    TResult Function()? syncFinished,
    TResult Function(String field0)? syncFailed,
    TResult Function(int progress, String message)? syncProgress,
    TResult Function(
      String conversationId,
      String userId,
      Int32List platformIds,
    )?
    userInputStatusChanged,
    TResult Function(String conversationId)? updateLatestMessageReadState,
    required TResult orElse(),
  }) {
    if (updateLatestMessageReadState != null) {
      return updateLatestMessageReadState(conversationId);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(ConversationEvent_Changed value) changed,
    required TResult Function(ConversationEvent_Deleted value) deleted,
    required TResult Function(ConversationEvent_New value) new_,
    required TResult Function(ConversationEvent_TotalUnreadCountChanged value)
    totalUnreadCountChanged,
    required TResult Function(ConversationEvent_SyncStarted value) syncStarted,
    required TResult Function(ConversationEvent_SyncFinished value)
    syncFinished,
    required TResult Function(ConversationEvent_SyncFailed value) syncFailed,
    required TResult Function(ConversationEvent_SyncProgress value)
    syncProgress,
    required TResult Function(ConversationEvent_UserInputStatusChanged value)
    userInputStatusChanged,
    required TResult Function(
      ConversationEvent_UpdateLatestMessageReadState value,
    )
    updateLatestMessageReadState,
  }) {
    return updateLatestMessageReadState(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(ConversationEvent_Changed value)? changed,
    TResult? Function(ConversationEvent_Deleted value)? deleted,
    TResult? Function(ConversationEvent_New value)? new_,
    TResult? Function(ConversationEvent_TotalUnreadCountChanged value)?
    totalUnreadCountChanged,
    TResult? Function(ConversationEvent_SyncStarted value)? syncStarted,
    TResult? Function(ConversationEvent_SyncFinished value)? syncFinished,
    TResult? Function(ConversationEvent_SyncFailed value)? syncFailed,
    TResult? Function(ConversationEvent_SyncProgress value)? syncProgress,
    TResult? Function(ConversationEvent_UserInputStatusChanged value)?
    userInputStatusChanged,
    TResult? Function(ConversationEvent_UpdateLatestMessageReadState value)?
    updateLatestMessageReadState,
  }) {
    return updateLatestMessageReadState?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(ConversationEvent_Changed value)? changed,
    TResult Function(ConversationEvent_Deleted value)? deleted,
    TResult Function(ConversationEvent_New value)? new_,
    TResult Function(ConversationEvent_TotalUnreadCountChanged value)?
    totalUnreadCountChanged,
    TResult Function(ConversationEvent_SyncStarted value)? syncStarted,
    TResult Function(ConversationEvent_SyncFinished value)? syncFinished,
    TResult Function(ConversationEvent_SyncFailed value)? syncFailed,
    TResult Function(ConversationEvent_SyncProgress value)? syncProgress,
    TResult Function(ConversationEvent_UserInputStatusChanged value)?
    userInputStatusChanged,
    TResult Function(ConversationEvent_UpdateLatestMessageReadState value)?
    updateLatestMessageReadState,
    required TResult orElse(),
  }) {
    if (updateLatestMessageReadState != null) {
      return updateLatestMessageReadState(this);
    }
    return orElse();
  }
}

abstract class ConversationEvent_UpdateLatestMessageReadState
    extends ConversationEvent {
  const factory ConversationEvent_UpdateLatestMessageReadState({
    required final String conversationId,
  }) = _$ConversationEvent_UpdateLatestMessageReadStateImpl;
  const ConversationEvent_UpdateLatestMessageReadState._() : super._();

  String get conversationId;

  /// Create a copy of ConversationEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ConversationEvent_UpdateLatestMessageReadStateImplCopyWith<
    _$ConversationEvent_UpdateLatestMessageReadStateImpl
  >
  get copyWith => throw _privateConstructorUsedError;
}
