// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'conversation.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ConversationEvent {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ConversationEvent);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'ConversationEvent()';
}


}

/// @nodoc
class $ConversationEventCopyWith<$Res>  {
$ConversationEventCopyWith(ConversationEvent _, $Res Function(ConversationEvent) __);
}


/// Adds pattern-matching-related methods to [ConversationEvent].
extension ConversationEventPatterns on ConversationEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( ConversationEvent_Changed value)?  changed,TResult Function( ConversationEvent_Deleted value)?  deleted,TResult Function( ConversationEvent_New value)?  new_,TResult Function( ConversationEvent_TotalUnreadCountChanged value)?  totalUnreadCountChanged,TResult Function( ConversationEvent_SyncStarted value)?  syncStarted,TResult Function( ConversationEvent_SyncFinished value)?  syncFinished,TResult Function( ConversationEvent_SyncFailed value)?  syncFailed,TResult Function( ConversationEvent_SyncProgress value)?  syncProgress,TResult Function( ConversationEvent_UserInputStatusChanged value)?  userInputStatusChanged,TResult Function( ConversationEvent_UpdateLatestMessageReadState value)?  updateLatestMessageReadState,required TResult orElse(),}){
final _that = this;
switch (_that) {
case ConversationEvent_Changed() when changed != null:
return changed(_that);case ConversationEvent_Deleted() when deleted != null:
return deleted(_that);case ConversationEvent_New() when new_ != null:
return new_(_that);case ConversationEvent_TotalUnreadCountChanged() when totalUnreadCountChanged != null:
return totalUnreadCountChanged(_that);case ConversationEvent_SyncStarted() when syncStarted != null:
return syncStarted(_that);case ConversationEvent_SyncFinished() when syncFinished != null:
return syncFinished(_that);case ConversationEvent_SyncFailed() when syncFailed != null:
return syncFailed(_that);case ConversationEvent_SyncProgress() when syncProgress != null:
return syncProgress(_that);case ConversationEvent_UserInputStatusChanged() when userInputStatusChanged != null:
return userInputStatusChanged(_that);case ConversationEvent_UpdateLatestMessageReadState() when updateLatestMessageReadState != null:
return updateLatestMessageReadState(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( ConversationEvent_Changed value)  changed,required TResult Function( ConversationEvent_Deleted value)  deleted,required TResult Function( ConversationEvent_New value)  new_,required TResult Function( ConversationEvent_TotalUnreadCountChanged value)  totalUnreadCountChanged,required TResult Function( ConversationEvent_SyncStarted value)  syncStarted,required TResult Function( ConversationEvent_SyncFinished value)  syncFinished,required TResult Function( ConversationEvent_SyncFailed value)  syncFailed,required TResult Function( ConversationEvent_SyncProgress value)  syncProgress,required TResult Function( ConversationEvent_UserInputStatusChanged value)  userInputStatusChanged,required TResult Function( ConversationEvent_UpdateLatestMessageReadState value)  updateLatestMessageReadState,}){
final _that = this;
switch (_that) {
case ConversationEvent_Changed():
return changed(_that);case ConversationEvent_Deleted():
return deleted(_that);case ConversationEvent_New():
return new_(_that);case ConversationEvent_TotalUnreadCountChanged():
return totalUnreadCountChanged(_that);case ConversationEvent_SyncStarted():
return syncStarted(_that);case ConversationEvent_SyncFinished():
return syncFinished(_that);case ConversationEvent_SyncFailed():
return syncFailed(_that);case ConversationEvent_SyncProgress():
return syncProgress(_that);case ConversationEvent_UserInputStatusChanged():
return userInputStatusChanged(_that);case ConversationEvent_UpdateLatestMessageReadState():
return updateLatestMessageReadState(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( ConversationEvent_Changed value)?  changed,TResult? Function( ConversationEvent_Deleted value)?  deleted,TResult? Function( ConversationEvent_New value)?  new_,TResult? Function( ConversationEvent_TotalUnreadCountChanged value)?  totalUnreadCountChanged,TResult? Function( ConversationEvent_SyncStarted value)?  syncStarted,TResult? Function( ConversationEvent_SyncFinished value)?  syncFinished,TResult? Function( ConversationEvent_SyncFailed value)?  syncFailed,TResult? Function( ConversationEvent_SyncProgress value)?  syncProgress,TResult? Function( ConversationEvent_UserInputStatusChanged value)?  userInputStatusChanged,TResult? Function( ConversationEvent_UpdateLatestMessageReadState value)?  updateLatestMessageReadState,}){
final _that = this;
switch (_that) {
case ConversationEvent_Changed() when changed != null:
return changed(_that);case ConversationEvent_Deleted() when deleted != null:
return deleted(_that);case ConversationEvent_New() when new_ != null:
return new_(_that);case ConversationEvent_TotalUnreadCountChanged() when totalUnreadCountChanged != null:
return totalUnreadCountChanged(_that);case ConversationEvent_SyncStarted() when syncStarted != null:
return syncStarted(_that);case ConversationEvent_SyncFinished() when syncFinished != null:
return syncFinished(_that);case ConversationEvent_SyncFailed() when syncFailed != null:
return syncFailed(_that);case ConversationEvent_SyncProgress() when syncProgress != null:
return syncProgress(_that);case ConversationEvent_UserInputStatusChanged() when userInputStatusChanged != null:
return userInputStatusChanged(_that);case ConversationEvent_UpdateLatestMessageReadState() when updateLatestMessageReadState != null:
return updateLatestMessageReadState(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( List<LocalConversation> field0)?  changed,TResult Function( List<String> field0)?  deleted,TResult Function( List<LocalConversation> field0)?  new_,TResult Function( int field0)?  totalUnreadCountChanged,TResult Function( bool field0)?  syncStarted,TResult Function( bool field0)?  syncFinished,TResult Function( bool reinstalled,  String error)?  syncFailed,TResult Function( int progress,  String message)?  syncProgress,TResult Function( String conversationId,  String userId,  Int32List platformIds)?  userInputStatusChanged,TResult Function( String conversationId)?  updateLatestMessageReadState,required TResult orElse(),}) {final _that = this;
switch (_that) {
case ConversationEvent_Changed() when changed != null:
return changed(_that.field0);case ConversationEvent_Deleted() when deleted != null:
return deleted(_that.field0);case ConversationEvent_New() when new_ != null:
return new_(_that.field0);case ConversationEvent_TotalUnreadCountChanged() when totalUnreadCountChanged != null:
return totalUnreadCountChanged(_that.field0);case ConversationEvent_SyncStarted() when syncStarted != null:
return syncStarted(_that.field0);case ConversationEvent_SyncFinished() when syncFinished != null:
return syncFinished(_that.field0);case ConversationEvent_SyncFailed() when syncFailed != null:
return syncFailed(_that.reinstalled,_that.error);case ConversationEvent_SyncProgress() when syncProgress != null:
return syncProgress(_that.progress,_that.message);case ConversationEvent_UserInputStatusChanged() when userInputStatusChanged != null:
return userInputStatusChanged(_that.conversationId,_that.userId,_that.platformIds);case ConversationEvent_UpdateLatestMessageReadState() when updateLatestMessageReadState != null:
return updateLatestMessageReadState(_that.conversationId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( List<LocalConversation> field0)  changed,required TResult Function( List<String> field0)  deleted,required TResult Function( List<LocalConversation> field0)  new_,required TResult Function( int field0)  totalUnreadCountChanged,required TResult Function( bool field0)  syncStarted,required TResult Function( bool field0)  syncFinished,required TResult Function( bool reinstalled,  String error)  syncFailed,required TResult Function( int progress,  String message)  syncProgress,required TResult Function( String conversationId,  String userId,  Int32List platformIds)  userInputStatusChanged,required TResult Function( String conversationId)  updateLatestMessageReadState,}) {final _that = this;
switch (_that) {
case ConversationEvent_Changed():
return changed(_that.field0);case ConversationEvent_Deleted():
return deleted(_that.field0);case ConversationEvent_New():
return new_(_that.field0);case ConversationEvent_TotalUnreadCountChanged():
return totalUnreadCountChanged(_that.field0);case ConversationEvent_SyncStarted():
return syncStarted(_that.field0);case ConversationEvent_SyncFinished():
return syncFinished(_that.field0);case ConversationEvent_SyncFailed():
return syncFailed(_that.reinstalled,_that.error);case ConversationEvent_SyncProgress():
return syncProgress(_that.progress,_that.message);case ConversationEvent_UserInputStatusChanged():
return userInputStatusChanged(_that.conversationId,_that.userId,_that.platformIds);case ConversationEvent_UpdateLatestMessageReadState():
return updateLatestMessageReadState(_that.conversationId);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( List<LocalConversation> field0)?  changed,TResult? Function( List<String> field0)?  deleted,TResult? Function( List<LocalConversation> field0)?  new_,TResult? Function( int field0)?  totalUnreadCountChanged,TResult? Function( bool field0)?  syncStarted,TResult? Function( bool field0)?  syncFinished,TResult? Function( bool reinstalled,  String error)?  syncFailed,TResult? Function( int progress,  String message)?  syncProgress,TResult? Function( String conversationId,  String userId,  Int32List platformIds)?  userInputStatusChanged,TResult? Function( String conversationId)?  updateLatestMessageReadState,}) {final _that = this;
switch (_that) {
case ConversationEvent_Changed() when changed != null:
return changed(_that.field0);case ConversationEvent_Deleted() when deleted != null:
return deleted(_that.field0);case ConversationEvent_New() when new_ != null:
return new_(_that.field0);case ConversationEvent_TotalUnreadCountChanged() when totalUnreadCountChanged != null:
return totalUnreadCountChanged(_that.field0);case ConversationEvent_SyncStarted() when syncStarted != null:
return syncStarted(_that.field0);case ConversationEvent_SyncFinished() when syncFinished != null:
return syncFinished(_that.field0);case ConversationEvent_SyncFailed() when syncFailed != null:
return syncFailed(_that.reinstalled,_that.error);case ConversationEvent_SyncProgress() when syncProgress != null:
return syncProgress(_that.progress,_that.message);case ConversationEvent_UserInputStatusChanged() when userInputStatusChanged != null:
return userInputStatusChanged(_that.conversationId,_that.userId,_that.platformIds);case ConversationEvent_UpdateLatestMessageReadState() when updateLatestMessageReadState != null:
return updateLatestMessageReadState(_that.conversationId);case _:
  return null;

}
}

}

/// @nodoc


class ConversationEvent_Changed extends ConversationEvent {
  const ConversationEvent_Changed(final  List<LocalConversation> field0): _field0 = field0,super._();
  

 final  List<LocalConversation> _field0;
 List<LocalConversation> get field0 {
  if (_field0 is EqualUnmodifiableListView) return _field0;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_field0);
}


/// Create a copy of ConversationEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ConversationEvent_ChangedCopyWith<ConversationEvent_Changed> get copyWith => _$ConversationEvent_ChangedCopyWithImpl<ConversationEvent_Changed>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ConversationEvent_Changed&&const DeepCollectionEquality().equals(other._field0, _field0));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_field0));

@override
String toString() {
  return 'ConversationEvent.changed(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $ConversationEvent_ChangedCopyWith<$Res> implements $ConversationEventCopyWith<$Res> {
  factory $ConversationEvent_ChangedCopyWith(ConversationEvent_Changed value, $Res Function(ConversationEvent_Changed) _then) = _$ConversationEvent_ChangedCopyWithImpl;
@useResult
$Res call({
 List<LocalConversation> field0
});




}
/// @nodoc
class _$ConversationEvent_ChangedCopyWithImpl<$Res>
    implements $ConversationEvent_ChangedCopyWith<$Res> {
  _$ConversationEvent_ChangedCopyWithImpl(this._self, this._then);

  final ConversationEvent_Changed _self;
  final $Res Function(ConversationEvent_Changed) _then;

/// Create a copy of ConversationEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(ConversationEvent_Changed(
null == field0 ? _self._field0 : field0 // ignore: cast_nullable_to_non_nullable
as List<LocalConversation>,
  ));
}


}

/// @nodoc


class ConversationEvent_Deleted extends ConversationEvent {
  const ConversationEvent_Deleted(final  List<String> field0): _field0 = field0,super._();
  

 final  List<String> _field0;
 List<String> get field0 {
  if (_field0 is EqualUnmodifiableListView) return _field0;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_field0);
}


/// Create a copy of ConversationEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ConversationEvent_DeletedCopyWith<ConversationEvent_Deleted> get copyWith => _$ConversationEvent_DeletedCopyWithImpl<ConversationEvent_Deleted>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ConversationEvent_Deleted&&const DeepCollectionEquality().equals(other._field0, _field0));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_field0));

@override
String toString() {
  return 'ConversationEvent.deleted(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $ConversationEvent_DeletedCopyWith<$Res> implements $ConversationEventCopyWith<$Res> {
  factory $ConversationEvent_DeletedCopyWith(ConversationEvent_Deleted value, $Res Function(ConversationEvent_Deleted) _then) = _$ConversationEvent_DeletedCopyWithImpl;
@useResult
$Res call({
 List<String> field0
});




}
/// @nodoc
class _$ConversationEvent_DeletedCopyWithImpl<$Res>
    implements $ConversationEvent_DeletedCopyWith<$Res> {
  _$ConversationEvent_DeletedCopyWithImpl(this._self, this._then);

  final ConversationEvent_Deleted _self;
  final $Res Function(ConversationEvent_Deleted) _then;

/// Create a copy of ConversationEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(ConversationEvent_Deleted(
null == field0 ? _self._field0 : field0 // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}

/// @nodoc


class ConversationEvent_New extends ConversationEvent {
  const ConversationEvent_New(final  List<LocalConversation> field0): _field0 = field0,super._();
  

 final  List<LocalConversation> _field0;
 List<LocalConversation> get field0 {
  if (_field0 is EqualUnmodifiableListView) return _field0;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_field0);
}


/// Create a copy of ConversationEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ConversationEvent_NewCopyWith<ConversationEvent_New> get copyWith => _$ConversationEvent_NewCopyWithImpl<ConversationEvent_New>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ConversationEvent_New&&const DeepCollectionEquality().equals(other._field0, _field0));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_field0));

@override
String toString() {
  return 'ConversationEvent.new_(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $ConversationEvent_NewCopyWith<$Res> implements $ConversationEventCopyWith<$Res> {
  factory $ConversationEvent_NewCopyWith(ConversationEvent_New value, $Res Function(ConversationEvent_New) _then) = _$ConversationEvent_NewCopyWithImpl;
@useResult
$Res call({
 List<LocalConversation> field0
});




}
/// @nodoc
class _$ConversationEvent_NewCopyWithImpl<$Res>
    implements $ConversationEvent_NewCopyWith<$Res> {
  _$ConversationEvent_NewCopyWithImpl(this._self, this._then);

  final ConversationEvent_New _self;
  final $Res Function(ConversationEvent_New) _then;

/// Create a copy of ConversationEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(ConversationEvent_New(
null == field0 ? _self._field0 : field0 // ignore: cast_nullable_to_non_nullable
as List<LocalConversation>,
  ));
}


}

/// @nodoc


class ConversationEvent_TotalUnreadCountChanged extends ConversationEvent {
  const ConversationEvent_TotalUnreadCountChanged(this.field0): super._();
  

 final  int field0;

/// Create a copy of ConversationEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ConversationEvent_TotalUnreadCountChangedCopyWith<ConversationEvent_TotalUnreadCountChanged> get copyWith => _$ConversationEvent_TotalUnreadCountChangedCopyWithImpl<ConversationEvent_TotalUnreadCountChanged>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ConversationEvent_TotalUnreadCountChanged&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'ConversationEvent.totalUnreadCountChanged(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $ConversationEvent_TotalUnreadCountChangedCopyWith<$Res> implements $ConversationEventCopyWith<$Res> {
  factory $ConversationEvent_TotalUnreadCountChangedCopyWith(ConversationEvent_TotalUnreadCountChanged value, $Res Function(ConversationEvent_TotalUnreadCountChanged) _then) = _$ConversationEvent_TotalUnreadCountChangedCopyWithImpl;
@useResult
$Res call({
 int field0
});




}
/// @nodoc
class _$ConversationEvent_TotalUnreadCountChangedCopyWithImpl<$Res>
    implements $ConversationEvent_TotalUnreadCountChangedCopyWith<$Res> {
  _$ConversationEvent_TotalUnreadCountChangedCopyWithImpl(this._self, this._then);

  final ConversationEvent_TotalUnreadCountChanged _self;
  final $Res Function(ConversationEvent_TotalUnreadCountChanged) _then;

/// Create a copy of ConversationEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(ConversationEvent_TotalUnreadCountChanged(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class ConversationEvent_SyncStarted extends ConversationEvent {
  const ConversationEvent_SyncStarted(this.field0): super._();
  

 final  bool field0;

/// Create a copy of ConversationEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ConversationEvent_SyncStartedCopyWith<ConversationEvent_SyncStarted> get copyWith => _$ConversationEvent_SyncStartedCopyWithImpl<ConversationEvent_SyncStarted>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ConversationEvent_SyncStarted&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'ConversationEvent.syncStarted(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $ConversationEvent_SyncStartedCopyWith<$Res> implements $ConversationEventCopyWith<$Res> {
  factory $ConversationEvent_SyncStartedCopyWith(ConversationEvent_SyncStarted value, $Res Function(ConversationEvent_SyncStarted) _then) = _$ConversationEvent_SyncStartedCopyWithImpl;
@useResult
$Res call({
 bool field0
});




}
/// @nodoc
class _$ConversationEvent_SyncStartedCopyWithImpl<$Res>
    implements $ConversationEvent_SyncStartedCopyWith<$Res> {
  _$ConversationEvent_SyncStartedCopyWithImpl(this._self, this._then);

  final ConversationEvent_SyncStarted _self;
  final $Res Function(ConversationEvent_SyncStarted) _then;

/// Create a copy of ConversationEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(ConversationEvent_SyncStarted(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc


class ConversationEvent_SyncFinished extends ConversationEvent {
  const ConversationEvent_SyncFinished(this.field0): super._();
  

 final  bool field0;

/// Create a copy of ConversationEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ConversationEvent_SyncFinishedCopyWith<ConversationEvent_SyncFinished> get copyWith => _$ConversationEvent_SyncFinishedCopyWithImpl<ConversationEvent_SyncFinished>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ConversationEvent_SyncFinished&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'ConversationEvent.syncFinished(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $ConversationEvent_SyncFinishedCopyWith<$Res> implements $ConversationEventCopyWith<$Res> {
  factory $ConversationEvent_SyncFinishedCopyWith(ConversationEvent_SyncFinished value, $Res Function(ConversationEvent_SyncFinished) _then) = _$ConversationEvent_SyncFinishedCopyWithImpl;
@useResult
$Res call({
 bool field0
});




}
/// @nodoc
class _$ConversationEvent_SyncFinishedCopyWithImpl<$Res>
    implements $ConversationEvent_SyncFinishedCopyWith<$Res> {
  _$ConversationEvent_SyncFinishedCopyWithImpl(this._self, this._then);

  final ConversationEvent_SyncFinished _self;
  final $Res Function(ConversationEvent_SyncFinished) _then;

/// Create a copy of ConversationEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(ConversationEvent_SyncFinished(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc


class ConversationEvent_SyncFailed extends ConversationEvent {
  const ConversationEvent_SyncFailed({required this.reinstalled, required this.error}): super._();
  

 final  bool reinstalled;
 final  String error;

/// Create a copy of ConversationEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ConversationEvent_SyncFailedCopyWith<ConversationEvent_SyncFailed> get copyWith => _$ConversationEvent_SyncFailedCopyWithImpl<ConversationEvent_SyncFailed>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ConversationEvent_SyncFailed&&(identical(other.reinstalled, reinstalled) || other.reinstalled == reinstalled)&&(identical(other.error, error) || other.error == error));
}


@override
int get hashCode => Object.hash(runtimeType,reinstalled,error);

@override
String toString() {
  return 'ConversationEvent.syncFailed(reinstalled: $reinstalled, error: $error)';
}


}

/// @nodoc
abstract mixin class $ConversationEvent_SyncFailedCopyWith<$Res> implements $ConversationEventCopyWith<$Res> {
  factory $ConversationEvent_SyncFailedCopyWith(ConversationEvent_SyncFailed value, $Res Function(ConversationEvent_SyncFailed) _then) = _$ConversationEvent_SyncFailedCopyWithImpl;
@useResult
$Res call({
 bool reinstalled, String error
});




}
/// @nodoc
class _$ConversationEvent_SyncFailedCopyWithImpl<$Res>
    implements $ConversationEvent_SyncFailedCopyWith<$Res> {
  _$ConversationEvent_SyncFailedCopyWithImpl(this._self, this._then);

  final ConversationEvent_SyncFailed _self;
  final $Res Function(ConversationEvent_SyncFailed) _then;

/// Create a copy of ConversationEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? reinstalled = null,Object? error = null,}) {
  return _then(ConversationEvent_SyncFailed(
reinstalled: null == reinstalled ? _self.reinstalled : reinstalled // ignore: cast_nullable_to_non_nullable
as bool,error: null == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class ConversationEvent_SyncProgress extends ConversationEvent {
  const ConversationEvent_SyncProgress({required this.progress, required this.message}): super._();
  

 final  int progress;
 final  String message;

/// Create a copy of ConversationEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ConversationEvent_SyncProgressCopyWith<ConversationEvent_SyncProgress> get copyWith => _$ConversationEvent_SyncProgressCopyWithImpl<ConversationEvent_SyncProgress>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ConversationEvent_SyncProgress&&(identical(other.progress, progress) || other.progress == progress)&&(identical(other.message, message) || other.message == message));
}


@override
int get hashCode => Object.hash(runtimeType,progress,message);

@override
String toString() {
  return 'ConversationEvent.syncProgress(progress: $progress, message: $message)';
}


}

/// @nodoc
abstract mixin class $ConversationEvent_SyncProgressCopyWith<$Res> implements $ConversationEventCopyWith<$Res> {
  factory $ConversationEvent_SyncProgressCopyWith(ConversationEvent_SyncProgress value, $Res Function(ConversationEvent_SyncProgress) _then) = _$ConversationEvent_SyncProgressCopyWithImpl;
@useResult
$Res call({
 int progress, String message
});




}
/// @nodoc
class _$ConversationEvent_SyncProgressCopyWithImpl<$Res>
    implements $ConversationEvent_SyncProgressCopyWith<$Res> {
  _$ConversationEvent_SyncProgressCopyWithImpl(this._self, this._then);

  final ConversationEvent_SyncProgress _self;
  final $Res Function(ConversationEvent_SyncProgress) _then;

/// Create a copy of ConversationEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? progress = null,Object? message = null,}) {
  return _then(ConversationEvent_SyncProgress(
progress: null == progress ? _self.progress : progress // ignore: cast_nullable_to_non_nullable
as int,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class ConversationEvent_UserInputStatusChanged extends ConversationEvent {
  const ConversationEvent_UserInputStatusChanged({required this.conversationId, required this.userId, required this.platformIds}): super._();
  

 final  String conversationId;
 final  String userId;
 final  Int32List platformIds;

/// Create a copy of ConversationEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ConversationEvent_UserInputStatusChangedCopyWith<ConversationEvent_UserInputStatusChanged> get copyWith => _$ConversationEvent_UserInputStatusChangedCopyWithImpl<ConversationEvent_UserInputStatusChanged>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ConversationEvent_UserInputStatusChanged&&(identical(other.conversationId, conversationId) || other.conversationId == conversationId)&&(identical(other.userId, userId) || other.userId == userId)&&const DeepCollectionEquality().equals(other.platformIds, platformIds));
}


@override
int get hashCode => Object.hash(runtimeType,conversationId,userId,const DeepCollectionEquality().hash(platformIds));

@override
String toString() {
  return 'ConversationEvent.userInputStatusChanged(conversationId: $conversationId, userId: $userId, platformIds: $platformIds)';
}


}

/// @nodoc
abstract mixin class $ConversationEvent_UserInputStatusChangedCopyWith<$Res> implements $ConversationEventCopyWith<$Res> {
  factory $ConversationEvent_UserInputStatusChangedCopyWith(ConversationEvent_UserInputStatusChanged value, $Res Function(ConversationEvent_UserInputStatusChanged) _then) = _$ConversationEvent_UserInputStatusChangedCopyWithImpl;
@useResult
$Res call({
 String conversationId, String userId, Int32List platformIds
});




}
/// @nodoc
class _$ConversationEvent_UserInputStatusChangedCopyWithImpl<$Res>
    implements $ConversationEvent_UserInputStatusChangedCopyWith<$Res> {
  _$ConversationEvent_UserInputStatusChangedCopyWithImpl(this._self, this._then);

  final ConversationEvent_UserInputStatusChanged _self;
  final $Res Function(ConversationEvent_UserInputStatusChanged) _then;

/// Create a copy of ConversationEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? conversationId = null,Object? userId = null,Object? platformIds = null,}) {
  return _then(ConversationEvent_UserInputStatusChanged(
conversationId: null == conversationId ? _self.conversationId : conversationId // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,platformIds: null == platformIds ? _self.platformIds : platformIds // ignore: cast_nullable_to_non_nullable
as Int32List,
  ));
}


}

/// @nodoc


class ConversationEvent_UpdateLatestMessageReadState extends ConversationEvent {
  const ConversationEvent_UpdateLatestMessageReadState({required this.conversationId}): super._();
  

 final  String conversationId;

/// Create a copy of ConversationEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ConversationEvent_UpdateLatestMessageReadStateCopyWith<ConversationEvent_UpdateLatestMessageReadState> get copyWith => _$ConversationEvent_UpdateLatestMessageReadStateCopyWithImpl<ConversationEvent_UpdateLatestMessageReadState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ConversationEvent_UpdateLatestMessageReadState&&(identical(other.conversationId, conversationId) || other.conversationId == conversationId));
}


@override
int get hashCode => Object.hash(runtimeType,conversationId);

@override
String toString() {
  return 'ConversationEvent.updateLatestMessageReadState(conversationId: $conversationId)';
}


}

/// @nodoc
abstract mixin class $ConversationEvent_UpdateLatestMessageReadStateCopyWith<$Res> implements $ConversationEventCopyWith<$Res> {
  factory $ConversationEvent_UpdateLatestMessageReadStateCopyWith(ConversationEvent_UpdateLatestMessageReadState value, $Res Function(ConversationEvent_UpdateLatestMessageReadState) _then) = _$ConversationEvent_UpdateLatestMessageReadStateCopyWithImpl;
@useResult
$Res call({
 String conversationId
});




}
/// @nodoc
class _$ConversationEvent_UpdateLatestMessageReadStateCopyWithImpl<$Res>
    implements $ConversationEvent_UpdateLatestMessageReadStateCopyWith<$Res> {
  _$ConversationEvent_UpdateLatestMessageReadStateCopyWithImpl(this._self, this._then);

  final ConversationEvent_UpdateLatestMessageReadState _self;
  final $Res Function(ConversationEvent_UpdateLatestMessageReadState) _then;

/// Create a copy of ConversationEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? conversationId = null,}) {
  return _then(ConversationEvent_UpdateLatestMessageReadState(
conversationId: null == conversationId ? _self.conversationId : conversationId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
