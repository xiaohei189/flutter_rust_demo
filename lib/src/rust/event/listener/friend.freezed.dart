// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'friend.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$FriendEvent {
  Object get field0 => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(List<FriendInfo> field0) added,
    required TResult Function(String field0) deleted,
    required TResult Function(List<FriendInfo> field0) infoChanged,
    required TResult Function(String field0) blackAdded,
    required TResult Function(String field0) blackDeleted,
    required TResult Function(String field0) applicationAdded,
    required TResult Function(String field0) applicationAccepted,
    required TResult Function(String field0) applicationRejected,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(List<FriendInfo> field0)? added,
    TResult? Function(String field0)? deleted,
    TResult? Function(List<FriendInfo> field0)? infoChanged,
    TResult? Function(String field0)? blackAdded,
    TResult? Function(String field0)? blackDeleted,
    TResult? Function(String field0)? applicationAdded,
    TResult? Function(String field0)? applicationAccepted,
    TResult? Function(String field0)? applicationRejected,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(List<FriendInfo> field0)? added,
    TResult Function(String field0)? deleted,
    TResult Function(List<FriendInfo> field0)? infoChanged,
    TResult Function(String field0)? blackAdded,
    TResult Function(String field0)? blackDeleted,
    TResult Function(String field0)? applicationAdded,
    TResult Function(String field0)? applicationAccepted,
    TResult Function(String field0)? applicationRejected,
    required TResult orElse(),
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(FriendEvent_Added value) added,
    required TResult Function(FriendEvent_Deleted value) deleted,
    required TResult Function(FriendEvent_InfoChanged value) infoChanged,
    required TResult Function(FriendEvent_BlackAdded value) blackAdded,
    required TResult Function(FriendEvent_BlackDeleted value) blackDeleted,
    required TResult Function(FriendEvent_ApplicationAdded value)
    applicationAdded,
    required TResult Function(FriendEvent_ApplicationAccepted value)
    applicationAccepted,
    required TResult Function(FriendEvent_ApplicationRejected value)
    applicationRejected,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(FriendEvent_Added value)? added,
    TResult? Function(FriendEvent_Deleted value)? deleted,
    TResult? Function(FriendEvent_InfoChanged value)? infoChanged,
    TResult? Function(FriendEvent_BlackAdded value)? blackAdded,
    TResult? Function(FriendEvent_BlackDeleted value)? blackDeleted,
    TResult? Function(FriendEvent_ApplicationAdded value)? applicationAdded,
    TResult? Function(FriendEvent_ApplicationAccepted value)?
    applicationAccepted,
    TResult? Function(FriendEvent_ApplicationRejected value)?
    applicationRejected,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(FriendEvent_Added value)? added,
    TResult Function(FriendEvent_Deleted value)? deleted,
    TResult Function(FriendEvent_InfoChanged value)? infoChanged,
    TResult Function(FriendEvent_BlackAdded value)? blackAdded,
    TResult Function(FriendEvent_BlackDeleted value)? blackDeleted,
    TResult Function(FriendEvent_ApplicationAdded value)? applicationAdded,
    TResult Function(FriendEvent_ApplicationAccepted value)?
    applicationAccepted,
    TResult Function(FriendEvent_ApplicationRejected value)?
    applicationRejected,
    required TResult orElse(),
  }) => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $FriendEventCopyWith<$Res> {
  factory $FriendEventCopyWith(
    FriendEvent value,
    $Res Function(FriendEvent) then,
  ) = _$FriendEventCopyWithImpl<$Res, FriendEvent>;
}

/// @nodoc
class _$FriendEventCopyWithImpl<$Res, $Val extends FriendEvent>
    implements $FriendEventCopyWith<$Res> {
  _$FriendEventCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of FriendEvent
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc
abstract class _$$FriendEvent_AddedImplCopyWith<$Res> {
  factory _$$FriendEvent_AddedImplCopyWith(
    _$FriendEvent_AddedImpl value,
    $Res Function(_$FriendEvent_AddedImpl) then,
  ) = __$$FriendEvent_AddedImplCopyWithImpl<$Res>;
  @useResult
  $Res call({List<FriendInfo> field0});
}

/// @nodoc
class __$$FriendEvent_AddedImplCopyWithImpl<$Res>
    extends _$FriendEventCopyWithImpl<$Res, _$FriendEvent_AddedImpl>
    implements _$$FriendEvent_AddedImplCopyWith<$Res> {
  __$$FriendEvent_AddedImplCopyWithImpl(
    _$FriendEvent_AddedImpl _value,
    $Res Function(_$FriendEvent_AddedImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of FriendEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? field0 = null}) {
    return _then(
      _$FriendEvent_AddedImpl(
        null == field0
            ? _value._field0
            : field0 // ignore: cast_nullable_to_non_nullable
                  as List<FriendInfo>,
      ),
    );
  }
}

/// @nodoc

class _$FriendEvent_AddedImpl extends FriendEvent_Added {
  const _$FriendEvent_AddedImpl(final List<FriendInfo> field0)
    : _field0 = field0,
      super._();

  final List<FriendInfo> _field0;
  @override
  List<FriendInfo> get field0 {
    if (_field0 is EqualUnmodifiableListView) return _field0;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_field0);
  }

  @override
  String toString() {
    return 'FriendEvent.added(field0: $field0)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FriendEvent_AddedImpl &&
            const DeepCollectionEquality().equals(other._field0, _field0));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, const DeepCollectionEquality().hash(_field0));

  /// Create a copy of FriendEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$FriendEvent_AddedImplCopyWith<_$FriendEvent_AddedImpl> get copyWith =>
      __$$FriendEvent_AddedImplCopyWithImpl<_$FriendEvent_AddedImpl>(
        this,
        _$identity,
      );

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(List<FriendInfo> field0) added,
    required TResult Function(String field0) deleted,
    required TResult Function(List<FriendInfo> field0) infoChanged,
    required TResult Function(String field0) blackAdded,
    required TResult Function(String field0) blackDeleted,
    required TResult Function(String field0) applicationAdded,
    required TResult Function(String field0) applicationAccepted,
    required TResult Function(String field0) applicationRejected,
  }) {
    return added(field0);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(List<FriendInfo> field0)? added,
    TResult? Function(String field0)? deleted,
    TResult? Function(List<FriendInfo> field0)? infoChanged,
    TResult? Function(String field0)? blackAdded,
    TResult? Function(String field0)? blackDeleted,
    TResult? Function(String field0)? applicationAdded,
    TResult? Function(String field0)? applicationAccepted,
    TResult? Function(String field0)? applicationRejected,
  }) {
    return added?.call(field0);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(List<FriendInfo> field0)? added,
    TResult Function(String field0)? deleted,
    TResult Function(List<FriendInfo> field0)? infoChanged,
    TResult Function(String field0)? blackAdded,
    TResult Function(String field0)? blackDeleted,
    TResult Function(String field0)? applicationAdded,
    TResult Function(String field0)? applicationAccepted,
    TResult Function(String field0)? applicationRejected,
    required TResult orElse(),
  }) {
    if (added != null) {
      return added(field0);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(FriendEvent_Added value) added,
    required TResult Function(FriendEvent_Deleted value) deleted,
    required TResult Function(FriendEvent_InfoChanged value) infoChanged,
    required TResult Function(FriendEvent_BlackAdded value) blackAdded,
    required TResult Function(FriendEvent_BlackDeleted value) blackDeleted,
    required TResult Function(FriendEvent_ApplicationAdded value)
    applicationAdded,
    required TResult Function(FriendEvent_ApplicationAccepted value)
    applicationAccepted,
    required TResult Function(FriendEvent_ApplicationRejected value)
    applicationRejected,
  }) {
    return added(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(FriendEvent_Added value)? added,
    TResult? Function(FriendEvent_Deleted value)? deleted,
    TResult? Function(FriendEvent_InfoChanged value)? infoChanged,
    TResult? Function(FriendEvent_BlackAdded value)? blackAdded,
    TResult? Function(FriendEvent_BlackDeleted value)? blackDeleted,
    TResult? Function(FriendEvent_ApplicationAdded value)? applicationAdded,
    TResult? Function(FriendEvent_ApplicationAccepted value)?
    applicationAccepted,
    TResult? Function(FriendEvent_ApplicationRejected value)?
    applicationRejected,
  }) {
    return added?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(FriendEvent_Added value)? added,
    TResult Function(FriendEvent_Deleted value)? deleted,
    TResult Function(FriendEvent_InfoChanged value)? infoChanged,
    TResult Function(FriendEvent_BlackAdded value)? blackAdded,
    TResult Function(FriendEvent_BlackDeleted value)? blackDeleted,
    TResult Function(FriendEvent_ApplicationAdded value)? applicationAdded,
    TResult Function(FriendEvent_ApplicationAccepted value)?
    applicationAccepted,
    TResult Function(FriendEvent_ApplicationRejected value)?
    applicationRejected,
    required TResult orElse(),
  }) {
    if (added != null) {
      return added(this);
    }
    return orElse();
  }
}

abstract class FriendEvent_Added extends FriendEvent {
  const factory FriendEvent_Added(final List<FriendInfo> field0) =
      _$FriendEvent_AddedImpl;
  const FriendEvent_Added._() : super._();

  @override
  List<FriendInfo> get field0;

  /// Create a copy of FriendEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$FriendEvent_AddedImplCopyWith<_$FriendEvent_AddedImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$FriendEvent_DeletedImplCopyWith<$Res> {
  factory _$$FriendEvent_DeletedImplCopyWith(
    _$FriendEvent_DeletedImpl value,
    $Res Function(_$FriendEvent_DeletedImpl) then,
  ) = __$$FriendEvent_DeletedImplCopyWithImpl<$Res>;
  @useResult
  $Res call({String field0});
}

/// @nodoc
class __$$FriendEvent_DeletedImplCopyWithImpl<$Res>
    extends _$FriendEventCopyWithImpl<$Res, _$FriendEvent_DeletedImpl>
    implements _$$FriendEvent_DeletedImplCopyWith<$Res> {
  __$$FriendEvent_DeletedImplCopyWithImpl(
    _$FriendEvent_DeletedImpl _value,
    $Res Function(_$FriendEvent_DeletedImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of FriendEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? field0 = null}) {
    return _then(
      _$FriendEvent_DeletedImpl(
        null == field0
            ? _value.field0
            : field0 // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc

class _$FriendEvent_DeletedImpl extends FriendEvent_Deleted {
  const _$FriendEvent_DeletedImpl(this.field0) : super._();

  @override
  final String field0;

  @override
  String toString() {
    return 'FriendEvent.deleted(field0: $field0)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FriendEvent_DeletedImpl &&
            (identical(other.field0, field0) || other.field0 == field0));
  }

  @override
  int get hashCode => Object.hash(runtimeType, field0);

  /// Create a copy of FriendEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$FriendEvent_DeletedImplCopyWith<_$FriendEvent_DeletedImpl> get copyWith =>
      __$$FriendEvent_DeletedImplCopyWithImpl<_$FriendEvent_DeletedImpl>(
        this,
        _$identity,
      );

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(List<FriendInfo> field0) added,
    required TResult Function(String field0) deleted,
    required TResult Function(List<FriendInfo> field0) infoChanged,
    required TResult Function(String field0) blackAdded,
    required TResult Function(String field0) blackDeleted,
    required TResult Function(String field0) applicationAdded,
    required TResult Function(String field0) applicationAccepted,
    required TResult Function(String field0) applicationRejected,
  }) {
    return deleted(field0);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(List<FriendInfo> field0)? added,
    TResult? Function(String field0)? deleted,
    TResult? Function(List<FriendInfo> field0)? infoChanged,
    TResult? Function(String field0)? blackAdded,
    TResult? Function(String field0)? blackDeleted,
    TResult? Function(String field0)? applicationAdded,
    TResult? Function(String field0)? applicationAccepted,
    TResult? Function(String field0)? applicationRejected,
  }) {
    return deleted?.call(field0);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(List<FriendInfo> field0)? added,
    TResult Function(String field0)? deleted,
    TResult Function(List<FriendInfo> field0)? infoChanged,
    TResult Function(String field0)? blackAdded,
    TResult Function(String field0)? blackDeleted,
    TResult Function(String field0)? applicationAdded,
    TResult Function(String field0)? applicationAccepted,
    TResult Function(String field0)? applicationRejected,
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
    required TResult Function(FriendEvent_Added value) added,
    required TResult Function(FriendEvent_Deleted value) deleted,
    required TResult Function(FriendEvent_InfoChanged value) infoChanged,
    required TResult Function(FriendEvent_BlackAdded value) blackAdded,
    required TResult Function(FriendEvent_BlackDeleted value) blackDeleted,
    required TResult Function(FriendEvent_ApplicationAdded value)
    applicationAdded,
    required TResult Function(FriendEvent_ApplicationAccepted value)
    applicationAccepted,
    required TResult Function(FriendEvent_ApplicationRejected value)
    applicationRejected,
  }) {
    return deleted(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(FriendEvent_Added value)? added,
    TResult? Function(FriendEvent_Deleted value)? deleted,
    TResult? Function(FriendEvent_InfoChanged value)? infoChanged,
    TResult? Function(FriendEvent_BlackAdded value)? blackAdded,
    TResult? Function(FriendEvent_BlackDeleted value)? blackDeleted,
    TResult? Function(FriendEvent_ApplicationAdded value)? applicationAdded,
    TResult? Function(FriendEvent_ApplicationAccepted value)?
    applicationAccepted,
    TResult? Function(FriendEvent_ApplicationRejected value)?
    applicationRejected,
  }) {
    return deleted?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(FriendEvent_Added value)? added,
    TResult Function(FriendEvent_Deleted value)? deleted,
    TResult Function(FriendEvent_InfoChanged value)? infoChanged,
    TResult Function(FriendEvent_BlackAdded value)? blackAdded,
    TResult Function(FriendEvent_BlackDeleted value)? blackDeleted,
    TResult Function(FriendEvent_ApplicationAdded value)? applicationAdded,
    TResult Function(FriendEvent_ApplicationAccepted value)?
    applicationAccepted,
    TResult Function(FriendEvent_ApplicationRejected value)?
    applicationRejected,
    required TResult orElse(),
  }) {
    if (deleted != null) {
      return deleted(this);
    }
    return orElse();
  }
}

abstract class FriendEvent_Deleted extends FriendEvent {
  const factory FriendEvent_Deleted(final String field0) =
      _$FriendEvent_DeletedImpl;
  const FriendEvent_Deleted._() : super._();

  @override
  String get field0;

  /// Create a copy of FriendEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$FriendEvent_DeletedImplCopyWith<_$FriendEvent_DeletedImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$FriendEvent_InfoChangedImplCopyWith<$Res> {
  factory _$$FriendEvent_InfoChangedImplCopyWith(
    _$FriendEvent_InfoChangedImpl value,
    $Res Function(_$FriendEvent_InfoChangedImpl) then,
  ) = __$$FriendEvent_InfoChangedImplCopyWithImpl<$Res>;
  @useResult
  $Res call({List<FriendInfo> field0});
}

/// @nodoc
class __$$FriendEvent_InfoChangedImplCopyWithImpl<$Res>
    extends _$FriendEventCopyWithImpl<$Res, _$FriendEvent_InfoChangedImpl>
    implements _$$FriendEvent_InfoChangedImplCopyWith<$Res> {
  __$$FriendEvent_InfoChangedImplCopyWithImpl(
    _$FriendEvent_InfoChangedImpl _value,
    $Res Function(_$FriendEvent_InfoChangedImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of FriendEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? field0 = null}) {
    return _then(
      _$FriendEvent_InfoChangedImpl(
        null == field0
            ? _value._field0
            : field0 // ignore: cast_nullable_to_non_nullable
                  as List<FriendInfo>,
      ),
    );
  }
}

/// @nodoc

class _$FriendEvent_InfoChangedImpl extends FriendEvent_InfoChanged {
  const _$FriendEvent_InfoChangedImpl(final List<FriendInfo> field0)
    : _field0 = field0,
      super._();

  final List<FriendInfo> _field0;
  @override
  List<FriendInfo> get field0 {
    if (_field0 is EqualUnmodifiableListView) return _field0;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_field0);
  }

  @override
  String toString() {
    return 'FriendEvent.infoChanged(field0: $field0)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FriendEvent_InfoChangedImpl &&
            const DeepCollectionEquality().equals(other._field0, _field0));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, const DeepCollectionEquality().hash(_field0));

  /// Create a copy of FriendEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$FriendEvent_InfoChangedImplCopyWith<_$FriendEvent_InfoChangedImpl>
  get copyWith =>
      __$$FriendEvent_InfoChangedImplCopyWithImpl<
        _$FriendEvent_InfoChangedImpl
      >(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(List<FriendInfo> field0) added,
    required TResult Function(String field0) deleted,
    required TResult Function(List<FriendInfo> field0) infoChanged,
    required TResult Function(String field0) blackAdded,
    required TResult Function(String field0) blackDeleted,
    required TResult Function(String field0) applicationAdded,
    required TResult Function(String field0) applicationAccepted,
    required TResult Function(String field0) applicationRejected,
  }) {
    return infoChanged(field0);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(List<FriendInfo> field0)? added,
    TResult? Function(String field0)? deleted,
    TResult? Function(List<FriendInfo> field0)? infoChanged,
    TResult? Function(String field0)? blackAdded,
    TResult? Function(String field0)? blackDeleted,
    TResult? Function(String field0)? applicationAdded,
    TResult? Function(String field0)? applicationAccepted,
    TResult? Function(String field0)? applicationRejected,
  }) {
    return infoChanged?.call(field0);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(List<FriendInfo> field0)? added,
    TResult Function(String field0)? deleted,
    TResult Function(List<FriendInfo> field0)? infoChanged,
    TResult Function(String field0)? blackAdded,
    TResult Function(String field0)? blackDeleted,
    TResult Function(String field0)? applicationAdded,
    TResult Function(String field0)? applicationAccepted,
    TResult Function(String field0)? applicationRejected,
    required TResult orElse(),
  }) {
    if (infoChanged != null) {
      return infoChanged(field0);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(FriendEvent_Added value) added,
    required TResult Function(FriendEvent_Deleted value) deleted,
    required TResult Function(FriendEvent_InfoChanged value) infoChanged,
    required TResult Function(FriendEvent_BlackAdded value) blackAdded,
    required TResult Function(FriendEvent_BlackDeleted value) blackDeleted,
    required TResult Function(FriendEvent_ApplicationAdded value)
    applicationAdded,
    required TResult Function(FriendEvent_ApplicationAccepted value)
    applicationAccepted,
    required TResult Function(FriendEvent_ApplicationRejected value)
    applicationRejected,
  }) {
    return infoChanged(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(FriendEvent_Added value)? added,
    TResult? Function(FriendEvent_Deleted value)? deleted,
    TResult? Function(FriendEvent_InfoChanged value)? infoChanged,
    TResult? Function(FriendEvent_BlackAdded value)? blackAdded,
    TResult? Function(FriendEvent_BlackDeleted value)? blackDeleted,
    TResult? Function(FriendEvent_ApplicationAdded value)? applicationAdded,
    TResult? Function(FriendEvent_ApplicationAccepted value)?
    applicationAccepted,
    TResult? Function(FriendEvent_ApplicationRejected value)?
    applicationRejected,
  }) {
    return infoChanged?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(FriendEvent_Added value)? added,
    TResult Function(FriendEvent_Deleted value)? deleted,
    TResult Function(FriendEvent_InfoChanged value)? infoChanged,
    TResult Function(FriendEvent_BlackAdded value)? blackAdded,
    TResult Function(FriendEvent_BlackDeleted value)? blackDeleted,
    TResult Function(FriendEvent_ApplicationAdded value)? applicationAdded,
    TResult Function(FriendEvent_ApplicationAccepted value)?
    applicationAccepted,
    TResult Function(FriendEvent_ApplicationRejected value)?
    applicationRejected,
    required TResult orElse(),
  }) {
    if (infoChanged != null) {
      return infoChanged(this);
    }
    return orElse();
  }
}

abstract class FriendEvent_InfoChanged extends FriendEvent {
  const factory FriendEvent_InfoChanged(final List<FriendInfo> field0) =
      _$FriendEvent_InfoChangedImpl;
  const FriendEvent_InfoChanged._() : super._();

  @override
  List<FriendInfo> get field0;

  /// Create a copy of FriendEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$FriendEvent_InfoChangedImplCopyWith<_$FriendEvent_InfoChangedImpl>
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$FriendEvent_BlackAddedImplCopyWith<$Res> {
  factory _$$FriendEvent_BlackAddedImplCopyWith(
    _$FriendEvent_BlackAddedImpl value,
    $Res Function(_$FriendEvent_BlackAddedImpl) then,
  ) = __$$FriendEvent_BlackAddedImplCopyWithImpl<$Res>;
  @useResult
  $Res call({String field0});
}

/// @nodoc
class __$$FriendEvent_BlackAddedImplCopyWithImpl<$Res>
    extends _$FriendEventCopyWithImpl<$Res, _$FriendEvent_BlackAddedImpl>
    implements _$$FriendEvent_BlackAddedImplCopyWith<$Res> {
  __$$FriendEvent_BlackAddedImplCopyWithImpl(
    _$FriendEvent_BlackAddedImpl _value,
    $Res Function(_$FriendEvent_BlackAddedImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of FriendEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? field0 = null}) {
    return _then(
      _$FriendEvent_BlackAddedImpl(
        null == field0
            ? _value.field0
            : field0 // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc

class _$FriendEvent_BlackAddedImpl extends FriendEvent_BlackAdded {
  const _$FriendEvent_BlackAddedImpl(this.field0) : super._();

  @override
  final String field0;

  @override
  String toString() {
    return 'FriendEvent.blackAdded(field0: $field0)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FriendEvent_BlackAddedImpl &&
            (identical(other.field0, field0) || other.field0 == field0));
  }

  @override
  int get hashCode => Object.hash(runtimeType, field0);

  /// Create a copy of FriendEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$FriendEvent_BlackAddedImplCopyWith<_$FriendEvent_BlackAddedImpl>
  get copyWith =>
      __$$FriendEvent_BlackAddedImplCopyWithImpl<_$FriendEvent_BlackAddedImpl>(
        this,
        _$identity,
      );

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(List<FriendInfo> field0) added,
    required TResult Function(String field0) deleted,
    required TResult Function(List<FriendInfo> field0) infoChanged,
    required TResult Function(String field0) blackAdded,
    required TResult Function(String field0) blackDeleted,
    required TResult Function(String field0) applicationAdded,
    required TResult Function(String field0) applicationAccepted,
    required TResult Function(String field0) applicationRejected,
  }) {
    return blackAdded(field0);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(List<FriendInfo> field0)? added,
    TResult? Function(String field0)? deleted,
    TResult? Function(List<FriendInfo> field0)? infoChanged,
    TResult? Function(String field0)? blackAdded,
    TResult? Function(String field0)? blackDeleted,
    TResult? Function(String field0)? applicationAdded,
    TResult? Function(String field0)? applicationAccepted,
    TResult? Function(String field0)? applicationRejected,
  }) {
    return blackAdded?.call(field0);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(List<FriendInfo> field0)? added,
    TResult Function(String field0)? deleted,
    TResult Function(List<FriendInfo> field0)? infoChanged,
    TResult Function(String field0)? blackAdded,
    TResult Function(String field0)? blackDeleted,
    TResult Function(String field0)? applicationAdded,
    TResult Function(String field0)? applicationAccepted,
    TResult Function(String field0)? applicationRejected,
    required TResult orElse(),
  }) {
    if (blackAdded != null) {
      return blackAdded(field0);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(FriendEvent_Added value) added,
    required TResult Function(FriendEvent_Deleted value) deleted,
    required TResult Function(FriendEvent_InfoChanged value) infoChanged,
    required TResult Function(FriendEvent_BlackAdded value) blackAdded,
    required TResult Function(FriendEvent_BlackDeleted value) blackDeleted,
    required TResult Function(FriendEvent_ApplicationAdded value)
    applicationAdded,
    required TResult Function(FriendEvent_ApplicationAccepted value)
    applicationAccepted,
    required TResult Function(FriendEvent_ApplicationRejected value)
    applicationRejected,
  }) {
    return blackAdded(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(FriendEvent_Added value)? added,
    TResult? Function(FriendEvent_Deleted value)? deleted,
    TResult? Function(FriendEvent_InfoChanged value)? infoChanged,
    TResult? Function(FriendEvent_BlackAdded value)? blackAdded,
    TResult? Function(FriendEvent_BlackDeleted value)? blackDeleted,
    TResult? Function(FriendEvent_ApplicationAdded value)? applicationAdded,
    TResult? Function(FriendEvent_ApplicationAccepted value)?
    applicationAccepted,
    TResult? Function(FriendEvent_ApplicationRejected value)?
    applicationRejected,
  }) {
    return blackAdded?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(FriendEvent_Added value)? added,
    TResult Function(FriendEvent_Deleted value)? deleted,
    TResult Function(FriendEvent_InfoChanged value)? infoChanged,
    TResult Function(FriendEvent_BlackAdded value)? blackAdded,
    TResult Function(FriendEvent_BlackDeleted value)? blackDeleted,
    TResult Function(FriendEvent_ApplicationAdded value)? applicationAdded,
    TResult Function(FriendEvent_ApplicationAccepted value)?
    applicationAccepted,
    TResult Function(FriendEvent_ApplicationRejected value)?
    applicationRejected,
    required TResult orElse(),
  }) {
    if (blackAdded != null) {
      return blackAdded(this);
    }
    return orElse();
  }
}

abstract class FriendEvent_BlackAdded extends FriendEvent {
  const factory FriendEvent_BlackAdded(final String field0) =
      _$FriendEvent_BlackAddedImpl;
  const FriendEvent_BlackAdded._() : super._();

  @override
  String get field0;

  /// Create a copy of FriendEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$FriendEvent_BlackAddedImplCopyWith<_$FriendEvent_BlackAddedImpl>
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$FriendEvent_BlackDeletedImplCopyWith<$Res> {
  factory _$$FriendEvent_BlackDeletedImplCopyWith(
    _$FriendEvent_BlackDeletedImpl value,
    $Res Function(_$FriendEvent_BlackDeletedImpl) then,
  ) = __$$FriendEvent_BlackDeletedImplCopyWithImpl<$Res>;
  @useResult
  $Res call({String field0});
}

/// @nodoc
class __$$FriendEvent_BlackDeletedImplCopyWithImpl<$Res>
    extends _$FriendEventCopyWithImpl<$Res, _$FriendEvent_BlackDeletedImpl>
    implements _$$FriendEvent_BlackDeletedImplCopyWith<$Res> {
  __$$FriendEvent_BlackDeletedImplCopyWithImpl(
    _$FriendEvent_BlackDeletedImpl _value,
    $Res Function(_$FriendEvent_BlackDeletedImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of FriendEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? field0 = null}) {
    return _then(
      _$FriendEvent_BlackDeletedImpl(
        null == field0
            ? _value.field0
            : field0 // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc

class _$FriendEvent_BlackDeletedImpl extends FriendEvent_BlackDeleted {
  const _$FriendEvent_BlackDeletedImpl(this.field0) : super._();

  @override
  final String field0;

  @override
  String toString() {
    return 'FriendEvent.blackDeleted(field0: $field0)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FriendEvent_BlackDeletedImpl &&
            (identical(other.field0, field0) || other.field0 == field0));
  }

  @override
  int get hashCode => Object.hash(runtimeType, field0);

  /// Create a copy of FriendEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$FriendEvent_BlackDeletedImplCopyWith<_$FriendEvent_BlackDeletedImpl>
  get copyWith =>
      __$$FriendEvent_BlackDeletedImplCopyWithImpl<
        _$FriendEvent_BlackDeletedImpl
      >(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(List<FriendInfo> field0) added,
    required TResult Function(String field0) deleted,
    required TResult Function(List<FriendInfo> field0) infoChanged,
    required TResult Function(String field0) blackAdded,
    required TResult Function(String field0) blackDeleted,
    required TResult Function(String field0) applicationAdded,
    required TResult Function(String field0) applicationAccepted,
    required TResult Function(String field0) applicationRejected,
  }) {
    return blackDeleted(field0);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(List<FriendInfo> field0)? added,
    TResult? Function(String field0)? deleted,
    TResult? Function(List<FriendInfo> field0)? infoChanged,
    TResult? Function(String field0)? blackAdded,
    TResult? Function(String field0)? blackDeleted,
    TResult? Function(String field0)? applicationAdded,
    TResult? Function(String field0)? applicationAccepted,
    TResult? Function(String field0)? applicationRejected,
  }) {
    return blackDeleted?.call(field0);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(List<FriendInfo> field0)? added,
    TResult Function(String field0)? deleted,
    TResult Function(List<FriendInfo> field0)? infoChanged,
    TResult Function(String field0)? blackAdded,
    TResult Function(String field0)? blackDeleted,
    TResult Function(String field0)? applicationAdded,
    TResult Function(String field0)? applicationAccepted,
    TResult Function(String field0)? applicationRejected,
    required TResult orElse(),
  }) {
    if (blackDeleted != null) {
      return blackDeleted(field0);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(FriendEvent_Added value) added,
    required TResult Function(FriendEvent_Deleted value) deleted,
    required TResult Function(FriendEvent_InfoChanged value) infoChanged,
    required TResult Function(FriendEvent_BlackAdded value) blackAdded,
    required TResult Function(FriendEvent_BlackDeleted value) blackDeleted,
    required TResult Function(FriendEvent_ApplicationAdded value)
    applicationAdded,
    required TResult Function(FriendEvent_ApplicationAccepted value)
    applicationAccepted,
    required TResult Function(FriendEvent_ApplicationRejected value)
    applicationRejected,
  }) {
    return blackDeleted(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(FriendEvent_Added value)? added,
    TResult? Function(FriendEvent_Deleted value)? deleted,
    TResult? Function(FriendEvent_InfoChanged value)? infoChanged,
    TResult? Function(FriendEvent_BlackAdded value)? blackAdded,
    TResult? Function(FriendEvent_BlackDeleted value)? blackDeleted,
    TResult? Function(FriendEvent_ApplicationAdded value)? applicationAdded,
    TResult? Function(FriendEvent_ApplicationAccepted value)?
    applicationAccepted,
    TResult? Function(FriendEvent_ApplicationRejected value)?
    applicationRejected,
  }) {
    return blackDeleted?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(FriendEvent_Added value)? added,
    TResult Function(FriendEvent_Deleted value)? deleted,
    TResult Function(FriendEvent_InfoChanged value)? infoChanged,
    TResult Function(FriendEvent_BlackAdded value)? blackAdded,
    TResult Function(FriendEvent_BlackDeleted value)? blackDeleted,
    TResult Function(FriendEvent_ApplicationAdded value)? applicationAdded,
    TResult Function(FriendEvent_ApplicationAccepted value)?
    applicationAccepted,
    TResult Function(FriendEvent_ApplicationRejected value)?
    applicationRejected,
    required TResult orElse(),
  }) {
    if (blackDeleted != null) {
      return blackDeleted(this);
    }
    return orElse();
  }
}

abstract class FriendEvent_BlackDeleted extends FriendEvent {
  const factory FriendEvent_BlackDeleted(final String field0) =
      _$FriendEvent_BlackDeletedImpl;
  const FriendEvent_BlackDeleted._() : super._();

  @override
  String get field0;

  /// Create a copy of FriendEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$FriendEvent_BlackDeletedImplCopyWith<_$FriendEvent_BlackDeletedImpl>
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$FriendEvent_ApplicationAddedImplCopyWith<$Res> {
  factory _$$FriendEvent_ApplicationAddedImplCopyWith(
    _$FriendEvent_ApplicationAddedImpl value,
    $Res Function(_$FriendEvent_ApplicationAddedImpl) then,
  ) = __$$FriendEvent_ApplicationAddedImplCopyWithImpl<$Res>;
  @useResult
  $Res call({String field0});
}

/// @nodoc
class __$$FriendEvent_ApplicationAddedImplCopyWithImpl<$Res>
    extends _$FriendEventCopyWithImpl<$Res, _$FriendEvent_ApplicationAddedImpl>
    implements _$$FriendEvent_ApplicationAddedImplCopyWith<$Res> {
  __$$FriendEvent_ApplicationAddedImplCopyWithImpl(
    _$FriendEvent_ApplicationAddedImpl _value,
    $Res Function(_$FriendEvent_ApplicationAddedImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of FriendEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? field0 = null}) {
    return _then(
      _$FriendEvent_ApplicationAddedImpl(
        null == field0
            ? _value.field0
            : field0 // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc

class _$FriendEvent_ApplicationAddedImpl extends FriendEvent_ApplicationAdded {
  const _$FriendEvent_ApplicationAddedImpl(this.field0) : super._();

  @override
  final String field0;

  @override
  String toString() {
    return 'FriendEvent.applicationAdded(field0: $field0)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FriendEvent_ApplicationAddedImpl &&
            (identical(other.field0, field0) || other.field0 == field0));
  }

  @override
  int get hashCode => Object.hash(runtimeType, field0);

  /// Create a copy of FriendEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$FriendEvent_ApplicationAddedImplCopyWith<
    _$FriendEvent_ApplicationAddedImpl
  >
  get copyWith =>
      __$$FriendEvent_ApplicationAddedImplCopyWithImpl<
        _$FriendEvent_ApplicationAddedImpl
      >(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(List<FriendInfo> field0) added,
    required TResult Function(String field0) deleted,
    required TResult Function(List<FriendInfo> field0) infoChanged,
    required TResult Function(String field0) blackAdded,
    required TResult Function(String field0) blackDeleted,
    required TResult Function(String field0) applicationAdded,
    required TResult Function(String field0) applicationAccepted,
    required TResult Function(String field0) applicationRejected,
  }) {
    return applicationAdded(field0);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(List<FriendInfo> field0)? added,
    TResult? Function(String field0)? deleted,
    TResult? Function(List<FriendInfo> field0)? infoChanged,
    TResult? Function(String field0)? blackAdded,
    TResult? Function(String field0)? blackDeleted,
    TResult? Function(String field0)? applicationAdded,
    TResult? Function(String field0)? applicationAccepted,
    TResult? Function(String field0)? applicationRejected,
  }) {
    return applicationAdded?.call(field0);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(List<FriendInfo> field0)? added,
    TResult Function(String field0)? deleted,
    TResult Function(List<FriendInfo> field0)? infoChanged,
    TResult Function(String field0)? blackAdded,
    TResult Function(String field0)? blackDeleted,
    TResult Function(String field0)? applicationAdded,
    TResult Function(String field0)? applicationAccepted,
    TResult Function(String field0)? applicationRejected,
    required TResult orElse(),
  }) {
    if (applicationAdded != null) {
      return applicationAdded(field0);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(FriendEvent_Added value) added,
    required TResult Function(FriendEvent_Deleted value) deleted,
    required TResult Function(FriendEvent_InfoChanged value) infoChanged,
    required TResult Function(FriendEvent_BlackAdded value) blackAdded,
    required TResult Function(FriendEvent_BlackDeleted value) blackDeleted,
    required TResult Function(FriendEvent_ApplicationAdded value)
    applicationAdded,
    required TResult Function(FriendEvent_ApplicationAccepted value)
    applicationAccepted,
    required TResult Function(FriendEvent_ApplicationRejected value)
    applicationRejected,
  }) {
    return applicationAdded(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(FriendEvent_Added value)? added,
    TResult? Function(FriendEvent_Deleted value)? deleted,
    TResult? Function(FriendEvent_InfoChanged value)? infoChanged,
    TResult? Function(FriendEvent_BlackAdded value)? blackAdded,
    TResult? Function(FriendEvent_BlackDeleted value)? blackDeleted,
    TResult? Function(FriendEvent_ApplicationAdded value)? applicationAdded,
    TResult? Function(FriendEvent_ApplicationAccepted value)?
    applicationAccepted,
    TResult? Function(FriendEvent_ApplicationRejected value)?
    applicationRejected,
  }) {
    return applicationAdded?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(FriendEvent_Added value)? added,
    TResult Function(FriendEvent_Deleted value)? deleted,
    TResult Function(FriendEvent_InfoChanged value)? infoChanged,
    TResult Function(FriendEvent_BlackAdded value)? blackAdded,
    TResult Function(FriendEvent_BlackDeleted value)? blackDeleted,
    TResult Function(FriendEvent_ApplicationAdded value)? applicationAdded,
    TResult Function(FriendEvent_ApplicationAccepted value)?
    applicationAccepted,
    TResult Function(FriendEvent_ApplicationRejected value)?
    applicationRejected,
    required TResult orElse(),
  }) {
    if (applicationAdded != null) {
      return applicationAdded(this);
    }
    return orElse();
  }
}

abstract class FriendEvent_ApplicationAdded extends FriendEvent {
  const factory FriendEvent_ApplicationAdded(final String field0) =
      _$FriendEvent_ApplicationAddedImpl;
  const FriendEvent_ApplicationAdded._() : super._();

  @override
  String get field0;

  /// Create a copy of FriendEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$FriendEvent_ApplicationAddedImplCopyWith<
    _$FriendEvent_ApplicationAddedImpl
  >
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$FriendEvent_ApplicationAcceptedImplCopyWith<$Res> {
  factory _$$FriendEvent_ApplicationAcceptedImplCopyWith(
    _$FriendEvent_ApplicationAcceptedImpl value,
    $Res Function(_$FriendEvent_ApplicationAcceptedImpl) then,
  ) = __$$FriendEvent_ApplicationAcceptedImplCopyWithImpl<$Res>;
  @useResult
  $Res call({String field0});
}

/// @nodoc
class __$$FriendEvent_ApplicationAcceptedImplCopyWithImpl<$Res>
    extends
        _$FriendEventCopyWithImpl<$Res, _$FriendEvent_ApplicationAcceptedImpl>
    implements _$$FriendEvent_ApplicationAcceptedImplCopyWith<$Res> {
  __$$FriendEvent_ApplicationAcceptedImplCopyWithImpl(
    _$FriendEvent_ApplicationAcceptedImpl _value,
    $Res Function(_$FriendEvent_ApplicationAcceptedImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of FriendEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? field0 = null}) {
    return _then(
      _$FriendEvent_ApplicationAcceptedImpl(
        null == field0
            ? _value.field0
            : field0 // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc

class _$FriendEvent_ApplicationAcceptedImpl
    extends FriendEvent_ApplicationAccepted {
  const _$FriendEvent_ApplicationAcceptedImpl(this.field0) : super._();

  @override
  final String field0;

  @override
  String toString() {
    return 'FriendEvent.applicationAccepted(field0: $field0)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FriendEvent_ApplicationAcceptedImpl &&
            (identical(other.field0, field0) || other.field0 == field0));
  }

  @override
  int get hashCode => Object.hash(runtimeType, field0);

  /// Create a copy of FriendEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$FriendEvent_ApplicationAcceptedImplCopyWith<
    _$FriendEvent_ApplicationAcceptedImpl
  >
  get copyWith =>
      __$$FriendEvent_ApplicationAcceptedImplCopyWithImpl<
        _$FriendEvent_ApplicationAcceptedImpl
      >(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(List<FriendInfo> field0) added,
    required TResult Function(String field0) deleted,
    required TResult Function(List<FriendInfo> field0) infoChanged,
    required TResult Function(String field0) blackAdded,
    required TResult Function(String field0) blackDeleted,
    required TResult Function(String field0) applicationAdded,
    required TResult Function(String field0) applicationAccepted,
    required TResult Function(String field0) applicationRejected,
  }) {
    return applicationAccepted(field0);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(List<FriendInfo> field0)? added,
    TResult? Function(String field0)? deleted,
    TResult? Function(List<FriendInfo> field0)? infoChanged,
    TResult? Function(String field0)? blackAdded,
    TResult? Function(String field0)? blackDeleted,
    TResult? Function(String field0)? applicationAdded,
    TResult? Function(String field0)? applicationAccepted,
    TResult? Function(String field0)? applicationRejected,
  }) {
    return applicationAccepted?.call(field0);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(List<FriendInfo> field0)? added,
    TResult Function(String field0)? deleted,
    TResult Function(List<FriendInfo> field0)? infoChanged,
    TResult Function(String field0)? blackAdded,
    TResult Function(String field0)? blackDeleted,
    TResult Function(String field0)? applicationAdded,
    TResult Function(String field0)? applicationAccepted,
    TResult Function(String field0)? applicationRejected,
    required TResult orElse(),
  }) {
    if (applicationAccepted != null) {
      return applicationAccepted(field0);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(FriendEvent_Added value) added,
    required TResult Function(FriendEvent_Deleted value) deleted,
    required TResult Function(FriendEvent_InfoChanged value) infoChanged,
    required TResult Function(FriendEvent_BlackAdded value) blackAdded,
    required TResult Function(FriendEvent_BlackDeleted value) blackDeleted,
    required TResult Function(FriendEvent_ApplicationAdded value)
    applicationAdded,
    required TResult Function(FriendEvent_ApplicationAccepted value)
    applicationAccepted,
    required TResult Function(FriendEvent_ApplicationRejected value)
    applicationRejected,
  }) {
    return applicationAccepted(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(FriendEvent_Added value)? added,
    TResult? Function(FriendEvent_Deleted value)? deleted,
    TResult? Function(FriendEvent_InfoChanged value)? infoChanged,
    TResult? Function(FriendEvent_BlackAdded value)? blackAdded,
    TResult? Function(FriendEvent_BlackDeleted value)? blackDeleted,
    TResult? Function(FriendEvent_ApplicationAdded value)? applicationAdded,
    TResult? Function(FriendEvent_ApplicationAccepted value)?
    applicationAccepted,
    TResult? Function(FriendEvent_ApplicationRejected value)?
    applicationRejected,
  }) {
    return applicationAccepted?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(FriendEvent_Added value)? added,
    TResult Function(FriendEvent_Deleted value)? deleted,
    TResult Function(FriendEvent_InfoChanged value)? infoChanged,
    TResult Function(FriendEvent_BlackAdded value)? blackAdded,
    TResult Function(FriendEvent_BlackDeleted value)? blackDeleted,
    TResult Function(FriendEvent_ApplicationAdded value)? applicationAdded,
    TResult Function(FriendEvent_ApplicationAccepted value)?
    applicationAccepted,
    TResult Function(FriendEvent_ApplicationRejected value)?
    applicationRejected,
    required TResult orElse(),
  }) {
    if (applicationAccepted != null) {
      return applicationAccepted(this);
    }
    return orElse();
  }
}

abstract class FriendEvent_ApplicationAccepted extends FriendEvent {
  const factory FriendEvent_ApplicationAccepted(final String field0) =
      _$FriendEvent_ApplicationAcceptedImpl;
  const FriendEvent_ApplicationAccepted._() : super._();

  @override
  String get field0;

  /// Create a copy of FriendEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$FriendEvent_ApplicationAcceptedImplCopyWith<
    _$FriendEvent_ApplicationAcceptedImpl
  >
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$FriendEvent_ApplicationRejectedImplCopyWith<$Res> {
  factory _$$FriendEvent_ApplicationRejectedImplCopyWith(
    _$FriendEvent_ApplicationRejectedImpl value,
    $Res Function(_$FriendEvent_ApplicationRejectedImpl) then,
  ) = __$$FriendEvent_ApplicationRejectedImplCopyWithImpl<$Res>;
  @useResult
  $Res call({String field0});
}

/// @nodoc
class __$$FriendEvent_ApplicationRejectedImplCopyWithImpl<$Res>
    extends
        _$FriendEventCopyWithImpl<$Res, _$FriendEvent_ApplicationRejectedImpl>
    implements _$$FriendEvent_ApplicationRejectedImplCopyWith<$Res> {
  __$$FriendEvent_ApplicationRejectedImplCopyWithImpl(
    _$FriendEvent_ApplicationRejectedImpl _value,
    $Res Function(_$FriendEvent_ApplicationRejectedImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of FriendEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? field0 = null}) {
    return _then(
      _$FriendEvent_ApplicationRejectedImpl(
        null == field0
            ? _value.field0
            : field0 // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc

class _$FriendEvent_ApplicationRejectedImpl
    extends FriendEvent_ApplicationRejected {
  const _$FriendEvent_ApplicationRejectedImpl(this.field0) : super._();

  @override
  final String field0;

  @override
  String toString() {
    return 'FriendEvent.applicationRejected(field0: $field0)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FriendEvent_ApplicationRejectedImpl &&
            (identical(other.field0, field0) || other.field0 == field0));
  }

  @override
  int get hashCode => Object.hash(runtimeType, field0);

  /// Create a copy of FriendEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$FriendEvent_ApplicationRejectedImplCopyWith<
    _$FriendEvent_ApplicationRejectedImpl
  >
  get copyWith =>
      __$$FriendEvent_ApplicationRejectedImplCopyWithImpl<
        _$FriendEvent_ApplicationRejectedImpl
      >(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(List<FriendInfo> field0) added,
    required TResult Function(String field0) deleted,
    required TResult Function(List<FriendInfo> field0) infoChanged,
    required TResult Function(String field0) blackAdded,
    required TResult Function(String field0) blackDeleted,
    required TResult Function(String field0) applicationAdded,
    required TResult Function(String field0) applicationAccepted,
    required TResult Function(String field0) applicationRejected,
  }) {
    return applicationRejected(field0);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(List<FriendInfo> field0)? added,
    TResult? Function(String field0)? deleted,
    TResult? Function(List<FriendInfo> field0)? infoChanged,
    TResult? Function(String field0)? blackAdded,
    TResult? Function(String field0)? blackDeleted,
    TResult? Function(String field0)? applicationAdded,
    TResult? Function(String field0)? applicationAccepted,
    TResult? Function(String field0)? applicationRejected,
  }) {
    return applicationRejected?.call(field0);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(List<FriendInfo> field0)? added,
    TResult Function(String field0)? deleted,
    TResult Function(List<FriendInfo> field0)? infoChanged,
    TResult Function(String field0)? blackAdded,
    TResult Function(String field0)? blackDeleted,
    TResult Function(String field0)? applicationAdded,
    TResult Function(String field0)? applicationAccepted,
    TResult Function(String field0)? applicationRejected,
    required TResult orElse(),
  }) {
    if (applicationRejected != null) {
      return applicationRejected(field0);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(FriendEvent_Added value) added,
    required TResult Function(FriendEvent_Deleted value) deleted,
    required TResult Function(FriendEvent_InfoChanged value) infoChanged,
    required TResult Function(FriendEvent_BlackAdded value) blackAdded,
    required TResult Function(FriendEvent_BlackDeleted value) blackDeleted,
    required TResult Function(FriendEvent_ApplicationAdded value)
    applicationAdded,
    required TResult Function(FriendEvent_ApplicationAccepted value)
    applicationAccepted,
    required TResult Function(FriendEvent_ApplicationRejected value)
    applicationRejected,
  }) {
    return applicationRejected(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(FriendEvent_Added value)? added,
    TResult? Function(FriendEvent_Deleted value)? deleted,
    TResult? Function(FriendEvent_InfoChanged value)? infoChanged,
    TResult? Function(FriendEvent_BlackAdded value)? blackAdded,
    TResult? Function(FriendEvent_BlackDeleted value)? blackDeleted,
    TResult? Function(FriendEvent_ApplicationAdded value)? applicationAdded,
    TResult? Function(FriendEvent_ApplicationAccepted value)?
    applicationAccepted,
    TResult? Function(FriendEvent_ApplicationRejected value)?
    applicationRejected,
  }) {
    return applicationRejected?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(FriendEvent_Added value)? added,
    TResult Function(FriendEvent_Deleted value)? deleted,
    TResult Function(FriendEvent_InfoChanged value)? infoChanged,
    TResult Function(FriendEvent_BlackAdded value)? blackAdded,
    TResult Function(FriendEvent_BlackDeleted value)? blackDeleted,
    TResult Function(FriendEvent_ApplicationAdded value)? applicationAdded,
    TResult Function(FriendEvent_ApplicationAccepted value)?
    applicationAccepted,
    TResult Function(FriendEvent_ApplicationRejected value)?
    applicationRejected,
    required TResult orElse(),
  }) {
    if (applicationRejected != null) {
      return applicationRejected(this);
    }
    return orElse();
  }
}

abstract class FriendEvent_ApplicationRejected extends FriendEvent {
  const factory FriendEvent_ApplicationRejected(final String field0) =
      _$FriendEvent_ApplicationRejectedImpl;
  const FriendEvent_ApplicationRejected._() : super._();

  @override
  String get field0;

  /// Create a copy of FriendEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$FriendEvent_ApplicationRejectedImplCopyWith<
    _$FriendEvent_ApplicationRejectedImpl
  >
  get copyWith => throw _privateConstructorUsedError;
}
