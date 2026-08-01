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
mixin _$GroupEvent {
  Object get field0 => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(GroupInfo field0) joinedGroupAdded,
    required TResult Function(GroupInfo field0) joinedGroupDeleted,
    required TResult Function(GroupInfo field0) groupInfoChanged,
    required TResult Function(String field0) memberAdded,
    required TResult Function(String field0) memberDeleted,
    required TResult Function(List<GroupReadReceipt> field0) groupReadReceipt,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(GroupInfo field0)? joinedGroupAdded,
    TResult? Function(GroupInfo field0)? joinedGroupDeleted,
    TResult? Function(GroupInfo field0)? groupInfoChanged,
    TResult? Function(String field0)? memberAdded,
    TResult? Function(String field0)? memberDeleted,
    TResult? Function(List<GroupReadReceipt> field0)? groupReadReceipt,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(GroupInfo field0)? joinedGroupAdded,
    TResult Function(GroupInfo field0)? joinedGroupDeleted,
    TResult Function(GroupInfo field0)? groupInfoChanged,
    TResult Function(String field0)? memberAdded,
    TResult Function(String field0)? memberDeleted,
    TResult Function(List<GroupReadReceipt> field0)? groupReadReceipt,
    required TResult orElse(),
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(GroupEvent_JoinedGroupAdded value)
    joinedGroupAdded,
    required TResult Function(GroupEvent_JoinedGroupDeleted value)
    joinedGroupDeleted,
    required TResult Function(GroupEvent_GroupInfoChanged value)
    groupInfoChanged,
    required TResult Function(GroupEvent_MemberAdded value) memberAdded,
    required TResult Function(GroupEvent_MemberDeleted value) memberDeleted,
    required TResult Function(GroupEvent_GroupReadReceipt value)
    groupReadReceipt,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(GroupEvent_JoinedGroupAdded value)? joinedGroupAdded,
    TResult? Function(GroupEvent_JoinedGroupDeleted value)? joinedGroupDeleted,
    TResult? Function(GroupEvent_GroupInfoChanged value)? groupInfoChanged,
    TResult? Function(GroupEvent_MemberAdded value)? memberAdded,
    TResult? Function(GroupEvent_MemberDeleted value)? memberDeleted,
    TResult? Function(GroupEvent_GroupReadReceipt value)? groupReadReceipt,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(GroupEvent_JoinedGroupAdded value)? joinedGroupAdded,
    TResult Function(GroupEvent_JoinedGroupDeleted value)? joinedGroupDeleted,
    TResult Function(GroupEvent_GroupInfoChanged value)? groupInfoChanged,
    TResult Function(GroupEvent_MemberAdded value)? memberAdded,
    TResult Function(GroupEvent_MemberDeleted value)? memberDeleted,
    TResult Function(GroupEvent_GroupReadReceipt value)? groupReadReceipt,
    required TResult orElse(),
  }) => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $GroupEventCopyWith<$Res> {
  factory $GroupEventCopyWith(
    GroupEvent value,
    $Res Function(GroupEvent) then,
  ) = _$GroupEventCopyWithImpl<$Res, GroupEvent>;
}

/// @nodoc
class _$GroupEventCopyWithImpl<$Res, $Val extends GroupEvent>
    implements $GroupEventCopyWith<$Res> {
  _$GroupEventCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of GroupEvent
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc
abstract class _$$GroupEvent_JoinedGroupAddedImplCopyWith<$Res> {
  factory _$$GroupEvent_JoinedGroupAddedImplCopyWith(
    _$GroupEvent_JoinedGroupAddedImpl value,
    $Res Function(_$GroupEvent_JoinedGroupAddedImpl) then,
  ) = __$$GroupEvent_JoinedGroupAddedImplCopyWithImpl<$Res>;
  @useResult
  $Res call({GroupInfo field0});
}

/// @nodoc
class __$$GroupEvent_JoinedGroupAddedImplCopyWithImpl<$Res>
    extends _$GroupEventCopyWithImpl<$Res, _$GroupEvent_JoinedGroupAddedImpl>
    implements _$$GroupEvent_JoinedGroupAddedImplCopyWith<$Res> {
  __$$GroupEvent_JoinedGroupAddedImplCopyWithImpl(
    _$GroupEvent_JoinedGroupAddedImpl _value,
    $Res Function(_$GroupEvent_JoinedGroupAddedImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of GroupEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? field0 = null}) {
    return _then(
      _$GroupEvent_JoinedGroupAddedImpl(
        null == field0
            ? _value.field0
            : field0 // ignore: cast_nullable_to_non_nullable
                  as GroupInfo,
      ),
    );
  }
}

/// @nodoc

class _$GroupEvent_JoinedGroupAddedImpl extends GroupEvent_JoinedGroupAdded {
  const _$GroupEvent_JoinedGroupAddedImpl(this.field0) : super._();

  @override
  final GroupInfo field0;

  @override
  String toString() {
    return 'GroupEvent.joinedGroupAdded(field0: $field0)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$GroupEvent_JoinedGroupAddedImpl &&
            (identical(other.field0, field0) || other.field0 == field0));
  }

  @override
  int get hashCode => Object.hash(runtimeType, field0);

  /// Create a copy of GroupEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$GroupEvent_JoinedGroupAddedImplCopyWith<_$GroupEvent_JoinedGroupAddedImpl>
  get copyWith =>
      __$$GroupEvent_JoinedGroupAddedImplCopyWithImpl<
        _$GroupEvent_JoinedGroupAddedImpl
      >(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(GroupInfo field0) joinedGroupAdded,
    required TResult Function(GroupInfo field0) joinedGroupDeleted,
    required TResult Function(GroupInfo field0) groupInfoChanged,
    required TResult Function(String field0) memberAdded,
    required TResult Function(String field0) memberDeleted,
    required TResult Function(List<GroupReadReceipt> field0) groupReadReceipt,
  }) {
    return joinedGroupAdded(field0);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(GroupInfo field0)? joinedGroupAdded,
    TResult? Function(GroupInfo field0)? joinedGroupDeleted,
    TResult? Function(GroupInfo field0)? groupInfoChanged,
    TResult? Function(String field0)? memberAdded,
    TResult? Function(String field0)? memberDeleted,
    TResult? Function(List<GroupReadReceipt> field0)? groupReadReceipt,
  }) {
    return joinedGroupAdded?.call(field0);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(GroupInfo field0)? joinedGroupAdded,
    TResult Function(GroupInfo field0)? joinedGroupDeleted,
    TResult Function(GroupInfo field0)? groupInfoChanged,
    TResult Function(String field0)? memberAdded,
    TResult Function(String field0)? memberDeleted,
    TResult Function(List<GroupReadReceipt> field0)? groupReadReceipt,
    required TResult orElse(),
  }) {
    if (joinedGroupAdded != null) {
      return joinedGroupAdded(field0);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(GroupEvent_JoinedGroupAdded value)
    joinedGroupAdded,
    required TResult Function(GroupEvent_JoinedGroupDeleted value)
    joinedGroupDeleted,
    required TResult Function(GroupEvent_GroupInfoChanged value)
    groupInfoChanged,
    required TResult Function(GroupEvent_MemberAdded value) memberAdded,
    required TResult Function(GroupEvent_MemberDeleted value) memberDeleted,
    required TResult Function(GroupEvent_GroupReadReceipt value)
    groupReadReceipt,
  }) {
    return joinedGroupAdded(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(GroupEvent_JoinedGroupAdded value)? joinedGroupAdded,
    TResult? Function(GroupEvent_JoinedGroupDeleted value)? joinedGroupDeleted,
    TResult? Function(GroupEvent_GroupInfoChanged value)? groupInfoChanged,
    TResult? Function(GroupEvent_MemberAdded value)? memberAdded,
    TResult? Function(GroupEvent_MemberDeleted value)? memberDeleted,
    TResult? Function(GroupEvent_GroupReadReceipt value)? groupReadReceipt,
  }) {
    return joinedGroupAdded?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(GroupEvent_JoinedGroupAdded value)? joinedGroupAdded,
    TResult Function(GroupEvent_JoinedGroupDeleted value)? joinedGroupDeleted,
    TResult Function(GroupEvent_GroupInfoChanged value)? groupInfoChanged,
    TResult Function(GroupEvent_MemberAdded value)? memberAdded,
    TResult Function(GroupEvent_MemberDeleted value)? memberDeleted,
    TResult Function(GroupEvent_GroupReadReceipt value)? groupReadReceipt,
    required TResult orElse(),
  }) {
    if (joinedGroupAdded != null) {
      return joinedGroupAdded(this);
    }
    return orElse();
  }
}

abstract class GroupEvent_JoinedGroupAdded extends GroupEvent {
  const factory GroupEvent_JoinedGroupAdded(final GroupInfo field0) =
      _$GroupEvent_JoinedGroupAddedImpl;
  const GroupEvent_JoinedGroupAdded._() : super._();

  @override
  GroupInfo get field0;

  /// Create a copy of GroupEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$GroupEvent_JoinedGroupAddedImplCopyWith<_$GroupEvent_JoinedGroupAddedImpl>
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$GroupEvent_JoinedGroupDeletedImplCopyWith<$Res> {
  factory _$$GroupEvent_JoinedGroupDeletedImplCopyWith(
    _$GroupEvent_JoinedGroupDeletedImpl value,
    $Res Function(_$GroupEvent_JoinedGroupDeletedImpl) then,
  ) = __$$GroupEvent_JoinedGroupDeletedImplCopyWithImpl<$Res>;
  @useResult
  $Res call({GroupInfo field0});
}

/// @nodoc
class __$$GroupEvent_JoinedGroupDeletedImplCopyWithImpl<$Res>
    extends _$GroupEventCopyWithImpl<$Res, _$GroupEvent_JoinedGroupDeletedImpl>
    implements _$$GroupEvent_JoinedGroupDeletedImplCopyWith<$Res> {
  __$$GroupEvent_JoinedGroupDeletedImplCopyWithImpl(
    _$GroupEvent_JoinedGroupDeletedImpl _value,
    $Res Function(_$GroupEvent_JoinedGroupDeletedImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of GroupEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? field0 = null}) {
    return _then(
      _$GroupEvent_JoinedGroupDeletedImpl(
        null == field0
            ? _value.field0
            : field0 // ignore: cast_nullable_to_non_nullable
                  as GroupInfo,
      ),
    );
  }
}

/// @nodoc

class _$GroupEvent_JoinedGroupDeletedImpl
    extends GroupEvent_JoinedGroupDeleted {
  const _$GroupEvent_JoinedGroupDeletedImpl(this.field0) : super._();

  @override
  final GroupInfo field0;

  @override
  String toString() {
    return 'GroupEvent.joinedGroupDeleted(field0: $field0)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$GroupEvent_JoinedGroupDeletedImpl &&
            (identical(other.field0, field0) || other.field0 == field0));
  }

  @override
  int get hashCode => Object.hash(runtimeType, field0);

  /// Create a copy of GroupEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$GroupEvent_JoinedGroupDeletedImplCopyWith<
    _$GroupEvent_JoinedGroupDeletedImpl
  >
  get copyWith =>
      __$$GroupEvent_JoinedGroupDeletedImplCopyWithImpl<
        _$GroupEvent_JoinedGroupDeletedImpl
      >(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(GroupInfo field0) joinedGroupAdded,
    required TResult Function(GroupInfo field0) joinedGroupDeleted,
    required TResult Function(GroupInfo field0) groupInfoChanged,
    required TResult Function(String field0) memberAdded,
    required TResult Function(String field0) memberDeleted,
    required TResult Function(List<GroupReadReceipt> field0) groupReadReceipt,
  }) {
    return joinedGroupDeleted(field0);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(GroupInfo field0)? joinedGroupAdded,
    TResult? Function(GroupInfo field0)? joinedGroupDeleted,
    TResult? Function(GroupInfo field0)? groupInfoChanged,
    TResult? Function(String field0)? memberAdded,
    TResult? Function(String field0)? memberDeleted,
    TResult? Function(List<GroupReadReceipt> field0)? groupReadReceipt,
  }) {
    return joinedGroupDeleted?.call(field0);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(GroupInfo field0)? joinedGroupAdded,
    TResult Function(GroupInfo field0)? joinedGroupDeleted,
    TResult Function(GroupInfo field0)? groupInfoChanged,
    TResult Function(String field0)? memberAdded,
    TResult Function(String field0)? memberDeleted,
    TResult Function(List<GroupReadReceipt> field0)? groupReadReceipt,
    required TResult orElse(),
  }) {
    if (joinedGroupDeleted != null) {
      return joinedGroupDeleted(field0);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(GroupEvent_JoinedGroupAdded value)
    joinedGroupAdded,
    required TResult Function(GroupEvent_JoinedGroupDeleted value)
    joinedGroupDeleted,
    required TResult Function(GroupEvent_GroupInfoChanged value)
    groupInfoChanged,
    required TResult Function(GroupEvent_MemberAdded value) memberAdded,
    required TResult Function(GroupEvent_MemberDeleted value) memberDeleted,
    required TResult Function(GroupEvent_GroupReadReceipt value)
    groupReadReceipt,
  }) {
    return joinedGroupDeleted(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(GroupEvent_JoinedGroupAdded value)? joinedGroupAdded,
    TResult? Function(GroupEvent_JoinedGroupDeleted value)? joinedGroupDeleted,
    TResult? Function(GroupEvent_GroupInfoChanged value)? groupInfoChanged,
    TResult? Function(GroupEvent_MemberAdded value)? memberAdded,
    TResult? Function(GroupEvent_MemberDeleted value)? memberDeleted,
    TResult? Function(GroupEvent_GroupReadReceipt value)? groupReadReceipt,
  }) {
    return joinedGroupDeleted?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(GroupEvent_JoinedGroupAdded value)? joinedGroupAdded,
    TResult Function(GroupEvent_JoinedGroupDeleted value)? joinedGroupDeleted,
    TResult Function(GroupEvent_GroupInfoChanged value)? groupInfoChanged,
    TResult Function(GroupEvent_MemberAdded value)? memberAdded,
    TResult Function(GroupEvent_MemberDeleted value)? memberDeleted,
    TResult Function(GroupEvent_GroupReadReceipt value)? groupReadReceipt,
    required TResult orElse(),
  }) {
    if (joinedGroupDeleted != null) {
      return joinedGroupDeleted(this);
    }
    return orElse();
  }
}

abstract class GroupEvent_JoinedGroupDeleted extends GroupEvent {
  const factory GroupEvent_JoinedGroupDeleted(final GroupInfo field0) =
      _$GroupEvent_JoinedGroupDeletedImpl;
  const GroupEvent_JoinedGroupDeleted._() : super._();

  @override
  GroupInfo get field0;

  /// Create a copy of GroupEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$GroupEvent_JoinedGroupDeletedImplCopyWith<
    _$GroupEvent_JoinedGroupDeletedImpl
  >
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$GroupEvent_GroupInfoChangedImplCopyWith<$Res> {
  factory _$$GroupEvent_GroupInfoChangedImplCopyWith(
    _$GroupEvent_GroupInfoChangedImpl value,
    $Res Function(_$GroupEvent_GroupInfoChangedImpl) then,
  ) = __$$GroupEvent_GroupInfoChangedImplCopyWithImpl<$Res>;
  @useResult
  $Res call({GroupInfo field0});
}

/// @nodoc
class __$$GroupEvent_GroupInfoChangedImplCopyWithImpl<$Res>
    extends _$GroupEventCopyWithImpl<$Res, _$GroupEvent_GroupInfoChangedImpl>
    implements _$$GroupEvent_GroupInfoChangedImplCopyWith<$Res> {
  __$$GroupEvent_GroupInfoChangedImplCopyWithImpl(
    _$GroupEvent_GroupInfoChangedImpl _value,
    $Res Function(_$GroupEvent_GroupInfoChangedImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of GroupEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? field0 = null}) {
    return _then(
      _$GroupEvent_GroupInfoChangedImpl(
        null == field0
            ? _value.field0
            : field0 // ignore: cast_nullable_to_non_nullable
                  as GroupInfo,
      ),
    );
  }
}

/// @nodoc

class _$GroupEvent_GroupInfoChangedImpl extends GroupEvent_GroupInfoChanged {
  const _$GroupEvent_GroupInfoChangedImpl(this.field0) : super._();

  @override
  final GroupInfo field0;

  @override
  String toString() {
    return 'GroupEvent.groupInfoChanged(field0: $field0)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$GroupEvent_GroupInfoChangedImpl &&
            (identical(other.field0, field0) || other.field0 == field0));
  }

  @override
  int get hashCode => Object.hash(runtimeType, field0);

  /// Create a copy of GroupEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$GroupEvent_GroupInfoChangedImplCopyWith<_$GroupEvent_GroupInfoChangedImpl>
  get copyWith =>
      __$$GroupEvent_GroupInfoChangedImplCopyWithImpl<
        _$GroupEvent_GroupInfoChangedImpl
      >(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(GroupInfo field0) joinedGroupAdded,
    required TResult Function(GroupInfo field0) joinedGroupDeleted,
    required TResult Function(GroupInfo field0) groupInfoChanged,
    required TResult Function(String field0) memberAdded,
    required TResult Function(String field0) memberDeleted,
    required TResult Function(List<GroupReadReceipt> field0) groupReadReceipt,
  }) {
    return groupInfoChanged(field0);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(GroupInfo field0)? joinedGroupAdded,
    TResult? Function(GroupInfo field0)? joinedGroupDeleted,
    TResult? Function(GroupInfo field0)? groupInfoChanged,
    TResult? Function(String field0)? memberAdded,
    TResult? Function(String field0)? memberDeleted,
    TResult? Function(List<GroupReadReceipt> field0)? groupReadReceipt,
  }) {
    return groupInfoChanged?.call(field0);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(GroupInfo field0)? joinedGroupAdded,
    TResult Function(GroupInfo field0)? joinedGroupDeleted,
    TResult Function(GroupInfo field0)? groupInfoChanged,
    TResult Function(String field0)? memberAdded,
    TResult Function(String field0)? memberDeleted,
    TResult Function(List<GroupReadReceipt> field0)? groupReadReceipt,
    required TResult orElse(),
  }) {
    if (groupInfoChanged != null) {
      return groupInfoChanged(field0);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(GroupEvent_JoinedGroupAdded value)
    joinedGroupAdded,
    required TResult Function(GroupEvent_JoinedGroupDeleted value)
    joinedGroupDeleted,
    required TResult Function(GroupEvent_GroupInfoChanged value)
    groupInfoChanged,
    required TResult Function(GroupEvent_MemberAdded value) memberAdded,
    required TResult Function(GroupEvent_MemberDeleted value) memberDeleted,
    required TResult Function(GroupEvent_GroupReadReceipt value)
    groupReadReceipt,
  }) {
    return groupInfoChanged(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(GroupEvent_JoinedGroupAdded value)? joinedGroupAdded,
    TResult? Function(GroupEvent_JoinedGroupDeleted value)? joinedGroupDeleted,
    TResult? Function(GroupEvent_GroupInfoChanged value)? groupInfoChanged,
    TResult? Function(GroupEvent_MemberAdded value)? memberAdded,
    TResult? Function(GroupEvent_MemberDeleted value)? memberDeleted,
    TResult? Function(GroupEvent_GroupReadReceipt value)? groupReadReceipt,
  }) {
    return groupInfoChanged?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(GroupEvent_JoinedGroupAdded value)? joinedGroupAdded,
    TResult Function(GroupEvent_JoinedGroupDeleted value)? joinedGroupDeleted,
    TResult Function(GroupEvent_GroupInfoChanged value)? groupInfoChanged,
    TResult Function(GroupEvent_MemberAdded value)? memberAdded,
    TResult Function(GroupEvent_MemberDeleted value)? memberDeleted,
    TResult Function(GroupEvent_GroupReadReceipt value)? groupReadReceipt,
    required TResult orElse(),
  }) {
    if (groupInfoChanged != null) {
      return groupInfoChanged(this);
    }
    return orElse();
  }
}

abstract class GroupEvent_GroupInfoChanged extends GroupEvent {
  const factory GroupEvent_GroupInfoChanged(final GroupInfo field0) =
      _$GroupEvent_GroupInfoChangedImpl;
  const GroupEvent_GroupInfoChanged._() : super._();

  @override
  GroupInfo get field0;

  /// Create a copy of GroupEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$GroupEvent_GroupInfoChangedImplCopyWith<_$GroupEvent_GroupInfoChangedImpl>
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$GroupEvent_MemberAddedImplCopyWith<$Res> {
  factory _$$GroupEvent_MemberAddedImplCopyWith(
    _$GroupEvent_MemberAddedImpl value,
    $Res Function(_$GroupEvent_MemberAddedImpl) then,
  ) = __$$GroupEvent_MemberAddedImplCopyWithImpl<$Res>;
  @useResult
  $Res call({String field0});
}

/// @nodoc
class __$$GroupEvent_MemberAddedImplCopyWithImpl<$Res>
    extends _$GroupEventCopyWithImpl<$Res, _$GroupEvent_MemberAddedImpl>
    implements _$$GroupEvent_MemberAddedImplCopyWith<$Res> {
  __$$GroupEvent_MemberAddedImplCopyWithImpl(
    _$GroupEvent_MemberAddedImpl _value,
    $Res Function(_$GroupEvent_MemberAddedImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of GroupEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? field0 = null}) {
    return _then(
      _$GroupEvent_MemberAddedImpl(
        null == field0
            ? _value.field0
            : field0 // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc

class _$GroupEvent_MemberAddedImpl extends GroupEvent_MemberAdded {
  const _$GroupEvent_MemberAddedImpl(this.field0) : super._();

  @override
  final String field0;

  @override
  String toString() {
    return 'GroupEvent.memberAdded(field0: $field0)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$GroupEvent_MemberAddedImpl &&
            (identical(other.field0, field0) || other.field0 == field0));
  }

  @override
  int get hashCode => Object.hash(runtimeType, field0);

  /// Create a copy of GroupEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$GroupEvent_MemberAddedImplCopyWith<_$GroupEvent_MemberAddedImpl>
  get copyWith =>
      __$$GroupEvent_MemberAddedImplCopyWithImpl<_$GroupEvent_MemberAddedImpl>(
        this,
        _$identity,
      );

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(GroupInfo field0) joinedGroupAdded,
    required TResult Function(GroupInfo field0) joinedGroupDeleted,
    required TResult Function(GroupInfo field0) groupInfoChanged,
    required TResult Function(String field0) memberAdded,
    required TResult Function(String field0) memberDeleted,
    required TResult Function(List<GroupReadReceipt> field0) groupReadReceipt,
  }) {
    return memberAdded(field0);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(GroupInfo field0)? joinedGroupAdded,
    TResult? Function(GroupInfo field0)? joinedGroupDeleted,
    TResult? Function(GroupInfo field0)? groupInfoChanged,
    TResult? Function(String field0)? memberAdded,
    TResult? Function(String field0)? memberDeleted,
    TResult? Function(List<GroupReadReceipt> field0)? groupReadReceipt,
  }) {
    return memberAdded?.call(field0);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(GroupInfo field0)? joinedGroupAdded,
    TResult Function(GroupInfo field0)? joinedGroupDeleted,
    TResult Function(GroupInfo field0)? groupInfoChanged,
    TResult Function(String field0)? memberAdded,
    TResult Function(String field0)? memberDeleted,
    TResult Function(List<GroupReadReceipt> field0)? groupReadReceipt,
    required TResult orElse(),
  }) {
    if (memberAdded != null) {
      return memberAdded(field0);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(GroupEvent_JoinedGroupAdded value)
    joinedGroupAdded,
    required TResult Function(GroupEvent_JoinedGroupDeleted value)
    joinedGroupDeleted,
    required TResult Function(GroupEvent_GroupInfoChanged value)
    groupInfoChanged,
    required TResult Function(GroupEvent_MemberAdded value) memberAdded,
    required TResult Function(GroupEvent_MemberDeleted value) memberDeleted,
    required TResult Function(GroupEvent_GroupReadReceipt value)
    groupReadReceipt,
  }) {
    return memberAdded(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(GroupEvent_JoinedGroupAdded value)? joinedGroupAdded,
    TResult? Function(GroupEvent_JoinedGroupDeleted value)? joinedGroupDeleted,
    TResult? Function(GroupEvent_GroupInfoChanged value)? groupInfoChanged,
    TResult? Function(GroupEvent_MemberAdded value)? memberAdded,
    TResult? Function(GroupEvent_MemberDeleted value)? memberDeleted,
    TResult? Function(GroupEvent_GroupReadReceipt value)? groupReadReceipt,
  }) {
    return memberAdded?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(GroupEvent_JoinedGroupAdded value)? joinedGroupAdded,
    TResult Function(GroupEvent_JoinedGroupDeleted value)? joinedGroupDeleted,
    TResult Function(GroupEvent_GroupInfoChanged value)? groupInfoChanged,
    TResult Function(GroupEvent_MemberAdded value)? memberAdded,
    TResult Function(GroupEvent_MemberDeleted value)? memberDeleted,
    TResult Function(GroupEvent_GroupReadReceipt value)? groupReadReceipt,
    required TResult orElse(),
  }) {
    if (memberAdded != null) {
      return memberAdded(this);
    }
    return orElse();
  }
}

abstract class GroupEvent_MemberAdded extends GroupEvent {
  const factory GroupEvent_MemberAdded(final String field0) =
      _$GroupEvent_MemberAddedImpl;
  const GroupEvent_MemberAdded._() : super._();

  @override
  String get field0;

  /// Create a copy of GroupEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$GroupEvent_MemberAddedImplCopyWith<_$GroupEvent_MemberAddedImpl>
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$GroupEvent_MemberDeletedImplCopyWith<$Res> {
  factory _$$GroupEvent_MemberDeletedImplCopyWith(
    _$GroupEvent_MemberDeletedImpl value,
    $Res Function(_$GroupEvent_MemberDeletedImpl) then,
  ) = __$$GroupEvent_MemberDeletedImplCopyWithImpl<$Res>;
  @useResult
  $Res call({String field0});
}

/// @nodoc
class __$$GroupEvent_MemberDeletedImplCopyWithImpl<$Res>
    extends _$GroupEventCopyWithImpl<$Res, _$GroupEvent_MemberDeletedImpl>
    implements _$$GroupEvent_MemberDeletedImplCopyWith<$Res> {
  __$$GroupEvent_MemberDeletedImplCopyWithImpl(
    _$GroupEvent_MemberDeletedImpl _value,
    $Res Function(_$GroupEvent_MemberDeletedImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of GroupEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? field0 = null}) {
    return _then(
      _$GroupEvent_MemberDeletedImpl(
        null == field0
            ? _value.field0
            : field0 // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc

class _$GroupEvent_MemberDeletedImpl extends GroupEvent_MemberDeleted {
  const _$GroupEvent_MemberDeletedImpl(this.field0) : super._();

  @override
  final String field0;

  @override
  String toString() {
    return 'GroupEvent.memberDeleted(field0: $field0)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$GroupEvent_MemberDeletedImpl &&
            (identical(other.field0, field0) || other.field0 == field0));
  }

  @override
  int get hashCode => Object.hash(runtimeType, field0);

  /// Create a copy of GroupEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$GroupEvent_MemberDeletedImplCopyWith<_$GroupEvent_MemberDeletedImpl>
  get copyWith =>
      __$$GroupEvent_MemberDeletedImplCopyWithImpl<
        _$GroupEvent_MemberDeletedImpl
      >(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(GroupInfo field0) joinedGroupAdded,
    required TResult Function(GroupInfo field0) joinedGroupDeleted,
    required TResult Function(GroupInfo field0) groupInfoChanged,
    required TResult Function(String field0) memberAdded,
    required TResult Function(String field0) memberDeleted,
    required TResult Function(List<GroupReadReceipt> field0) groupReadReceipt,
  }) {
    return memberDeleted(field0);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(GroupInfo field0)? joinedGroupAdded,
    TResult? Function(GroupInfo field0)? joinedGroupDeleted,
    TResult? Function(GroupInfo field0)? groupInfoChanged,
    TResult? Function(String field0)? memberAdded,
    TResult? Function(String field0)? memberDeleted,
    TResult? Function(List<GroupReadReceipt> field0)? groupReadReceipt,
  }) {
    return memberDeleted?.call(field0);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(GroupInfo field0)? joinedGroupAdded,
    TResult Function(GroupInfo field0)? joinedGroupDeleted,
    TResult Function(GroupInfo field0)? groupInfoChanged,
    TResult Function(String field0)? memberAdded,
    TResult Function(String field0)? memberDeleted,
    TResult Function(List<GroupReadReceipt> field0)? groupReadReceipt,
    required TResult orElse(),
  }) {
    if (memberDeleted != null) {
      return memberDeleted(field0);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(GroupEvent_JoinedGroupAdded value)
    joinedGroupAdded,
    required TResult Function(GroupEvent_JoinedGroupDeleted value)
    joinedGroupDeleted,
    required TResult Function(GroupEvent_GroupInfoChanged value)
    groupInfoChanged,
    required TResult Function(GroupEvent_MemberAdded value) memberAdded,
    required TResult Function(GroupEvent_MemberDeleted value) memberDeleted,
    required TResult Function(GroupEvent_GroupReadReceipt value)
    groupReadReceipt,
  }) {
    return memberDeleted(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(GroupEvent_JoinedGroupAdded value)? joinedGroupAdded,
    TResult? Function(GroupEvent_JoinedGroupDeleted value)? joinedGroupDeleted,
    TResult? Function(GroupEvent_GroupInfoChanged value)? groupInfoChanged,
    TResult? Function(GroupEvent_MemberAdded value)? memberAdded,
    TResult? Function(GroupEvent_MemberDeleted value)? memberDeleted,
    TResult? Function(GroupEvent_GroupReadReceipt value)? groupReadReceipt,
  }) {
    return memberDeleted?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(GroupEvent_JoinedGroupAdded value)? joinedGroupAdded,
    TResult Function(GroupEvent_JoinedGroupDeleted value)? joinedGroupDeleted,
    TResult Function(GroupEvent_GroupInfoChanged value)? groupInfoChanged,
    TResult Function(GroupEvent_MemberAdded value)? memberAdded,
    TResult Function(GroupEvent_MemberDeleted value)? memberDeleted,
    TResult Function(GroupEvent_GroupReadReceipt value)? groupReadReceipt,
    required TResult orElse(),
  }) {
    if (memberDeleted != null) {
      return memberDeleted(this);
    }
    return orElse();
  }
}

abstract class GroupEvent_MemberDeleted extends GroupEvent {
  const factory GroupEvent_MemberDeleted(final String field0) =
      _$GroupEvent_MemberDeletedImpl;
  const GroupEvent_MemberDeleted._() : super._();

  @override
  String get field0;

  /// Create a copy of GroupEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$GroupEvent_MemberDeletedImplCopyWith<_$GroupEvent_MemberDeletedImpl>
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$GroupEvent_GroupReadReceiptImplCopyWith<$Res> {
  factory _$$GroupEvent_GroupReadReceiptImplCopyWith(
    _$GroupEvent_GroupReadReceiptImpl value,
    $Res Function(_$GroupEvent_GroupReadReceiptImpl) then,
  ) = __$$GroupEvent_GroupReadReceiptImplCopyWithImpl<$Res>;
  @useResult
  $Res call({List<GroupReadReceipt> field0});
}

/// @nodoc
class __$$GroupEvent_GroupReadReceiptImplCopyWithImpl<$Res>
    extends _$GroupEventCopyWithImpl<$Res, _$GroupEvent_GroupReadReceiptImpl>
    implements _$$GroupEvent_GroupReadReceiptImplCopyWith<$Res> {
  __$$GroupEvent_GroupReadReceiptImplCopyWithImpl(
    _$GroupEvent_GroupReadReceiptImpl _value,
    $Res Function(_$GroupEvent_GroupReadReceiptImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of GroupEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? field0 = null}) {
    return _then(
      _$GroupEvent_GroupReadReceiptImpl(
        null == field0
            ? _value._field0
            : field0 // ignore: cast_nullable_to_non_nullable
                  as List<GroupReadReceipt>,
      ),
    );
  }
}

/// @nodoc

class _$GroupEvent_GroupReadReceiptImpl extends GroupEvent_GroupReadReceipt {
  const _$GroupEvent_GroupReadReceiptImpl(final List<GroupReadReceipt> field0)
    : _field0 = field0,
      super._();

  final List<GroupReadReceipt> _field0;
  @override
  List<GroupReadReceipt> get field0 {
    if (_field0 is EqualUnmodifiableListView) return _field0;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_field0);
  }

  @override
  String toString() {
    return 'GroupEvent.groupReadReceipt(field0: $field0)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$GroupEvent_GroupReadReceiptImpl &&
            const DeepCollectionEquality().equals(other._field0, _field0));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, const DeepCollectionEquality().hash(_field0));

  /// Create a copy of GroupEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$GroupEvent_GroupReadReceiptImplCopyWith<_$GroupEvent_GroupReadReceiptImpl>
  get copyWith =>
      __$$GroupEvent_GroupReadReceiptImplCopyWithImpl<
        _$GroupEvent_GroupReadReceiptImpl
      >(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(GroupInfo field0) joinedGroupAdded,
    required TResult Function(GroupInfo field0) joinedGroupDeleted,
    required TResult Function(GroupInfo field0) groupInfoChanged,
    required TResult Function(String field0) memberAdded,
    required TResult Function(String field0) memberDeleted,
    required TResult Function(List<GroupReadReceipt> field0) groupReadReceipt,
  }) {
    return groupReadReceipt(field0);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(GroupInfo field0)? joinedGroupAdded,
    TResult? Function(GroupInfo field0)? joinedGroupDeleted,
    TResult? Function(GroupInfo field0)? groupInfoChanged,
    TResult? Function(String field0)? memberAdded,
    TResult? Function(String field0)? memberDeleted,
    TResult? Function(List<GroupReadReceipt> field0)? groupReadReceipt,
  }) {
    return groupReadReceipt?.call(field0);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(GroupInfo field0)? joinedGroupAdded,
    TResult Function(GroupInfo field0)? joinedGroupDeleted,
    TResult Function(GroupInfo field0)? groupInfoChanged,
    TResult Function(String field0)? memberAdded,
    TResult Function(String field0)? memberDeleted,
    TResult Function(List<GroupReadReceipt> field0)? groupReadReceipt,
    required TResult orElse(),
  }) {
    if (groupReadReceipt != null) {
      return groupReadReceipt(field0);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(GroupEvent_JoinedGroupAdded value)
    joinedGroupAdded,
    required TResult Function(GroupEvent_JoinedGroupDeleted value)
    joinedGroupDeleted,
    required TResult Function(GroupEvent_GroupInfoChanged value)
    groupInfoChanged,
    required TResult Function(GroupEvent_MemberAdded value) memberAdded,
    required TResult Function(GroupEvent_MemberDeleted value) memberDeleted,
    required TResult Function(GroupEvent_GroupReadReceipt value)
    groupReadReceipt,
  }) {
    return groupReadReceipt(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(GroupEvent_JoinedGroupAdded value)? joinedGroupAdded,
    TResult? Function(GroupEvent_JoinedGroupDeleted value)? joinedGroupDeleted,
    TResult? Function(GroupEvent_GroupInfoChanged value)? groupInfoChanged,
    TResult? Function(GroupEvent_MemberAdded value)? memberAdded,
    TResult? Function(GroupEvent_MemberDeleted value)? memberDeleted,
    TResult? Function(GroupEvent_GroupReadReceipt value)? groupReadReceipt,
  }) {
    return groupReadReceipt?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(GroupEvent_JoinedGroupAdded value)? joinedGroupAdded,
    TResult Function(GroupEvent_JoinedGroupDeleted value)? joinedGroupDeleted,
    TResult Function(GroupEvent_GroupInfoChanged value)? groupInfoChanged,
    TResult Function(GroupEvent_MemberAdded value)? memberAdded,
    TResult Function(GroupEvent_MemberDeleted value)? memberDeleted,
    TResult Function(GroupEvent_GroupReadReceipt value)? groupReadReceipt,
    required TResult orElse(),
  }) {
    if (groupReadReceipt != null) {
      return groupReadReceipt(this);
    }
    return orElse();
  }
}

abstract class GroupEvent_GroupReadReceipt extends GroupEvent {
  const factory GroupEvent_GroupReadReceipt(
    final List<GroupReadReceipt> field0,
  ) = _$GroupEvent_GroupReadReceiptImpl;
  const GroupEvent_GroupReadReceipt._() : super._();

  @override
  List<GroupReadReceipt> get field0;

  /// Create a copy of GroupEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$GroupEvent_GroupReadReceiptImplCopyWith<_$GroupEvent_GroupReadReceiptImpl>
  get copyWith => throw _privateConstructorUsedError;
}
