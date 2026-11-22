// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'friend.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$FriendEvent {

 Object get field0;



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FriendEvent&&const DeepCollectionEquality().equals(other.field0, field0));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(field0));

@override
String toString() {
  return 'FriendEvent(field0: $field0)';
}


}

/// @nodoc
class $FriendEventCopyWith<$Res>  {
$FriendEventCopyWith(FriendEvent _, $Res Function(FriendEvent) __);
}


/// Adds pattern-matching-related methods to [FriendEvent].
extension FriendEventPatterns on FriendEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( FriendEvent_Added value)?  added,TResult Function( FriendEvent_Deleted value)?  deleted,TResult Function( FriendEvent_InfoChanged value)?  infoChanged,TResult Function( FriendEvent_BlackAdded value)?  blackAdded,TResult Function( FriendEvent_BlackDeleted value)?  blackDeleted,TResult Function( FriendEvent_ApplicationAdded value)?  applicationAdded,TResult Function( FriendEvent_ApplicationDeleted value)?  applicationDeleted,TResult Function( FriendEvent_ApplicationAccepted value)?  applicationAccepted,TResult Function( FriendEvent_ApplicationRejected value)?  applicationRejected,required TResult orElse(),}){
final _that = this;
switch (_that) {
case FriendEvent_Added() when added != null:
return added(_that);case FriendEvent_Deleted() when deleted != null:
return deleted(_that);case FriendEvent_InfoChanged() when infoChanged != null:
return infoChanged(_that);case FriendEvent_BlackAdded() when blackAdded != null:
return blackAdded(_that);case FriendEvent_BlackDeleted() when blackDeleted != null:
return blackDeleted(_that);case FriendEvent_ApplicationAdded() when applicationAdded != null:
return applicationAdded(_that);case FriendEvent_ApplicationDeleted() when applicationDeleted != null:
return applicationDeleted(_that);case FriendEvent_ApplicationAccepted() when applicationAccepted != null:
return applicationAccepted(_that);case FriendEvent_ApplicationRejected() when applicationRejected != null:
return applicationRejected(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( FriendEvent_Added value)  added,required TResult Function( FriendEvent_Deleted value)  deleted,required TResult Function( FriendEvent_InfoChanged value)  infoChanged,required TResult Function( FriendEvent_BlackAdded value)  blackAdded,required TResult Function( FriendEvent_BlackDeleted value)  blackDeleted,required TResult Function( FriendEvent_ApplicationAdded value)  applicationAdded,required TResult Function( FriendEvent_ApplicationDeleted value)  applicationDeleted,required TResult Function( FriendEvent_ApplicationAccepted value)  applicationAccepted,required TResult Function( FriendEvent_ApplicationRejected value)  applicationRejected,}){
final _that = this;
switch (_that) {
case FriendEvent_Added():
return added(_that);case FriendEvent_Deleted():
return deleted(_that);case FriendEvent_InfoChanged():
return infoChanged(_that);case FriendEvent_BlackAdded():
return blackAdded(_that);case FriendEvent_BlackDeleted():
return blackDeleted(_that);case FriendEvent_ApplicationAdded():
return applicationAdded(_that);case FriendEvent_ApplicationDeleted():
return applicationDeleted(_that);case FriendEvent_ApplicationAccepted():
return applicationAccepted(_that);case FriendEvent_ApplicationRejected():
return applicationRejected(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( FriendEvent_Added value)?  added,TResult? Function( FriendEvent_Deleted value)?  deleted,TResult? Function( FriendEvent_InfoChanged value)?  infoChanged,TResult? Function( FriendEvent_BlackAdded value)?  blackAdded,TResult? Function( FriendEvent_BlackDeleted value)?  blackDeleted,TResult? Function( FriendEvent_ApplicationAdded value)?  applicationAdded,TResult? Function( FriendEvent_ApplicationDeleted value)?  applicationDeleted,TResult? Function( FriendEvent_ApplicationAccepted value)?  applicationAccepted,TResult? Function( FriendEvent_ApplicationRejected value)?  applicationRejected,}){
final _that = this;
switch (_that) {
case FriendEvent_Added() when added != null:
return added(_that);case FriendEvent_Deleted() when deleted != null:
return deleted(_that);case FriendEvent_InfoChanged() when infoChanged != null:
return infoChanged(_that);case FriendEvent_BlackAdded() when blackAdded != null:
return blackAdded(_that);case FriendEvent_BlackDeleted() when blackDeleted != null:
return blackDeleted(_that);case FriendEvent_ApplicationAdded() when applicationAdded != null:
return applicationAdded(_that);case FriendEvent_ApplicationDeleted() when applicationDeleted != null:
return applicationDeleted(_that);case FriendEvent_ApplicationAccepted() when applicationAccepted != null:
return applicationAccepted(_that);case FriendEvent_ApplicationRejected() when applicationRejected != null:
return applicationRejected(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( List<FriendInfo> field0)?  added,TResult Function( String field0)?  deleted,TResult Function( List<FriendInfo> field0)?  infoChanged,TResult Function( String field0)?  blackAdded,TResult Function( String field0)?  blackDeleted,TResult Function( String field0)?  applicationAdded,TResult Function( String field0)?  applicationDeleted,TResult Function( String field0)?  applicationAccepted,TResult Function( String field0)?  applicationRejected,required TResult orElse(),}) {final _that = this;
switch (_that) {
case FriendEvent_Added() when added != null:
return added(_that.field0);case FriendEvent_Deleted() when deleted != null:
return deleted(_that.field0);case FriendEvent_InfoChanged() when infoChanged != null:
return infoChanged(_that.field0);case FriendEvent_BlackAdded() when blackAdded != null:
return blackAdded(_that.field0);case FriendEvent_BlackDeleted() when blackDeleted != null:
return blackDeleted(_that.field0);case FriendEvent_ApplicationAdded() when applicationAdded != null:
return applicationAdded(_that.field0);case FriendEvent_ApplicationDeleted() when applicationDeleted != null:
return applicationDeleted(_that.field0);case FriendEvent_ApplicationAccepted() when applicationAccepted != null:
return applicationAccepted(_that.field0);case FriendEvent_ApplicationRejected() when applicationRejected != null:
return applicationRejected(_that.field0);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( List<FriendInfo> field0)  added,required TResult Function( String field0)  deleted,required TResult Function( List<FriendInfo> field0)  infoChanged,required TResult Function( String field0)  blackAdded,required TResult Function( String field0)  blackDeleted,required TResult Function( String field0)  applicationAdded,required TResult Function( String field0)  applicationDeleted,required TResult Function( String field0)  applicationAccepted,required TResult Function( String field0)  applicationRejected,}) {final _that = this;
switch (_that) {
case FriendEvent_Added():
return added(_that.field0);case FriendEvent_Deleted():
return deleted(_that.field0);case FriendEvent_InfoChanged():
return infoChanged(_that.field0);case FriendEvent_BlackAdded():
return blackAdded(_that.field0);case FriendEvent_BlackDeleted():
return blackDeleted(_that.field0);case FriendEvent_ApplicationAdded():
return applicationAdded(_that.field0);case FriendEvent_ApplicationDeleted():
return applicationDeleted(_that.field0);case FriendEvent_ApplicationAccepted():
return applicationAccepted(_that.field0);case FriendEvent_ApplicationRejected():
return applicationRejected(_that.field0);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( List<FriendInfo> field0)?  added,TResult? Function( String field0)?  deleted,TResult? Function( List<FriendInfo> field0)?  infoChanged,TResult? Function( String field0)?  blackAdded,TResult? Function( String field0)?  blackDeleted,TResult? Function( String field0)?  applicationAdded,TResult? Function( String field0)?  applicationDeleted,TResult? Function( String field0)?  applicationAccepted,TResult? Function( String field0)?  applicationRejected,}) {final _that = this;
switch (_that) {
case FriendEvent_Added() when added != null:
return added(_that.field0);case FriendEvent_Deleted() when deleted != null:
return deleted(_that.field0);case FriendEvent_InfoChanged() when infoChanged != null:
return infoChanged(_that.field0);case FriendEvent_BlackAdded() when blackAdded != null:
return blackAdded(_that.field0);case FriendEvent_BlackDeleted() when blackDeleted != null:
return blackDeleted(_that.field0);case FriendEvent_ApplicationAdded() when applicationAdded != null:
return applicationAdded(_that.field0);case FriendEvent_ApplicationDeleted() when applicationDeleted != null:
return applicationDeleted(_that.field0);case FriendEvent_ApplicationAccepted() when applicationAccepted != null:
return applicationAccepted(_that.field0);case FriendEvent_ApplicationRejected() when applicationRejected != null:
return applicationRejected(_that.field0);case _:
  return null;

}
}

}

/// @nodoc


class FriendEvent_Added extends FriendEvent {
  const FriendEvent_Added(final  List<FriendInfo> field0): _field0 = field0,super._();
  

 final  List<FriendInfo> _field0;
@override List<FriendInfo> get field0 {
  if (_field0 is EqualUnmodifiableListView) return _field0;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_field0);
}


/// Create a copy of FriendEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FriendEvent_AddedCopyWith<FriendEvent_Added> get copyWith => _$FriendEvent_AddedCopyWithImpl<FriendEvent_Added>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FriendEvent_Added&&const DeepCollectionEquality().equals(other._field0, _field0));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_field0));

@override
String toString() {
  return 'FriendEvent.added(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $FriendEvent_AddedCopyWith<$Res> implements $FriendEventCopyWith<$Res> {
  factory $FriendEvent_AddedCopyWith(FriendEvent_Added value, $Res Function(FriendEvent_Added) _then) = _$FriendEvent_AddedCopyWithImpl;
@useResult
$Res call({
 List<FriendInfo> field0
});




}
/// @nodoc
class _$FriendEvent_AddedCopyWithImpl<$Res>
    implements $FriendEvent_AddedCopyWith<$Res> {
  _$FriendEvent_AddedCopyWithImpl(this._self, this._then);

  final FriendEvent_Added _self;
  final $Res Function(FriendEvent_Added) _then;

/// Create a copy of FriendEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(FriendEvent_Added(
null == field0 ? _self._field0 : field0 // ignore: cast_nullable_to_non_nullable
as List<FriendInfo>,
  ));
}


}

/// @nodoc


class FriendEvent_Deleted extends FriendEvent {
  const FriendEvent_Deleted(this.field0): super._();
  

@override final  String field0;

/// Create a copy of FriendEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FriendEvent_DeletedCopyWith<FriendEvent_Deleted> get copyWith => _$FriendEvent_DeletedCopyWithImpl<FriendEvent_Deleted>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FriendEvent_Deleted&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'FriendEvent.deleted(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $FriendEvent_DeletedCopyWith<$Res> implements $FriendEventCopyWith<$Res> {
  factory $FriendEvent_DeletedCopyWith(FriendEvent_Deleted value, $Res Function(FriendEvent_Deleted) _then) = _$FriendEvent_DeletedCopyWithImpl;
@useResult
$Res call({
 String field0
});




}
/// @nodoc
class _$FriendEvent_DeletedCopyWithImpl<$Res>
    implements $FriendEvent_DeletedCopyWith<$Res> {
  _$FriendEvent_DeletedCopyWithImpl(this._self, this._then);

  final FriendEvent_Deleted _self;
  final $Res Function(FriendEvent_Deleted) _then;

/// Create a copy of FriendEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(FriendEvent_Deleted(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class FriendEvent_InfoChanged extends FriendEvent {
  const FriendEvent_InfoChanged(final  List<FriendInfo> field0): _field0 = field0,super._();
  

 final  List<FriendInfo> _field0;
@override List<FriendInfo> get field0 {
  if (_field0 is EqualUnmodifiableListView) return _field0;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_field0);
}


/// Create a copy of FriendEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FriendEvent_InfoChangedCopyWith<FriendEvent_InfoChanged> get copyWith => _$FriendEvent_InfoChangedCopyWithImpl<FriendEvent_InfoChanged>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FriendEvent_InfoChanged&&const DeepCollectionEquality().equals(other._field0, _field0));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_field0));

@override
String toString() {
  return 'FriendEvent.infoChanged(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $FriendEvent_InfoChangedCopyWith<$Res> implements $FriendEventCopyWith<$Res> {
  factory $FriendEvent_InfoChangedCopyWith(FriendEvent_InfoChanged value, $Res Function(FriendEvent_InfoChanged) _then) = _$FriendEvent_InfoChangedCopyWithImpl;
@useResult
$Res call({
 List<FriendInfo> field0
});




}
/// @nodoc
class _$FriendEvent_InfoChangedCopyWithImpl<$Res>
    implements $FriendEvent_InfoChangedCopyWith<$Res> {
  _$FriendEvent_InfoChangedCopyWithImpl(this._self, this._then);

  final FriendEvent_InfoChanged _self;
  final $Res Function(FriendEvent_InfoChanged) _then;

/// Create a copy of FriendEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(FriendEvent_InfoChanged(
null == field0 ? _self._field0 : field0 // ignore: cast_nullable_to_non_nullable
as List<FriendInfo>,
  ));
}


}

/// @nodoc


class FriendEvent_BlackAdded extends FriendEvent {
  const FriendEvent_BlackAdded(this.field0): super._();
  

@override final  String field0;

/// Create a copy of FriendEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FriendEvent_BlackAddedCopyWith<FriendEvent_BlackAdded> get copyWith => _$FriendEvent_BlackAddedCopyWithImpl<FriendEvent_BlackAdded>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FriendEvent_BlackAdded&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'FriendEvent.blackAdded(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $FriendEvent_BlackAddedCopyWith<$Res> implements $FriendEventCopyWith<$Res> {
  factory $FriendEvent_BlackAddedCopyWith(FriendEvent_BlackAdded value, $Res Function(FriendEvent_BlackAdded) _then) = _$FriendEvent_BlackAddedCopyWithImpl;
@useResult
$Res call({
 String field0
});




}
/// @nodoc
class _$FriendEvent_BlackAddedCopyWithImpl<$Res>
    implements $FriendEvent_BlackAddedCopyWith<$Res> {
  _$FriendEvent_BlackAddedCopyWithImpl(this._self, this._then);

  final FriendEvent_BlackAdded _self;
  final $Res Function(FriendEvent_BlackAdded) _then;

/// Create a copy of FriendEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(FriendEvent_BlackAdded(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class FriendEvent_BlackDeleted extends FriendEvent {
  const FriendEvent_BlackDeleted(this.field0): super._();
  

@override final  String field0;

/// Create a copy of FriendEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FriendEvent_BlackDeletedCopyWith<FriendEvent_BlackDeleted> get copyWith => _$FriendEvent_BlackDeletedCopyWithImpl<FriendEvent_BlackDeleted>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FriendEvent_BlackDeleted&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'FriendEvent.blackDeleted(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $FriendEvent_BlackDeletedCopyWith<$Res> implements $FriendEventCopyWith<$Res> {
  factory $FriendEvent_BlackDeletedCopyWith(FriendEvent_BlackDeleted value, $Res Function(FriendEvent_BlackDeleted) _then) = _$FriendEvent_BlackDeletedCopyWithImpl;
@useResult
$Res call({
 String field0
});




}
/// @nodoc
class _$FriendEvent_BlackDeletedCopyWithImpl<$Res>
    implements $FriendEvent_BlackDeletedCopyWith<$Res> {
  _$FriendEvent_BlackDeletedCopyWithImpl(this._self, this._then);

  final FriendEvent_BlackDeleted _self;
  final $Res Function(FriendEvent_BlackDeleted) _then;

/// Create a copy of FriendEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(FriendEvent_BlackDeleted(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class FriendEvent_ApplicationAdded extends FriendEvent {
  const FriendEvent_ApplicationAdded(this.field0): super._();
  

@override final  String field0;

/// Create a copy of FriendEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FriendEvent_ApplicationAddedCopyWith<FriendEvent_ApplicationAdded> get copyWith => _$FriendEvent_ApplicationAddedCopyWithImpl<FriendEvent_ApplicationAdded>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FriendEvent_ApplicationAdded&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'FriendEvent.applicationAdded(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $FriendEvent_ApplicationAddedCopyWith<$Res> implements $FriendEventCopyWith<$Res> {
  factory $FriendEvent_ApplicationAddedCopyWith(FriendEvent_ApplicationAdded value, $Res Function(FriendEvent_ApplicationAdded) _then) = _$FriendEvent_ApplicationAddedCopyWithImpl;
@useResult
$Res call({
 String field0
});




}
/// @nodoc
class _$FriendEvent_ApplicationAddedCopyWithImpl<$Res>
    implements $FriendEvent_ApplicationAddedCopyWith<$Res> {
  _$FriendEvent_ApplicationAddedCopyWithImpl(this._self, this._then);

  final FriendEvent_ApplicationAdded _self;
  final $Res Function(FriendEvent_ApplicationAdded) _then;

/// Create a copy of FriendEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(FriendEvent_ApplicationAdded(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class FriendEvent_ApplicationDeleted extends FriendEvent {
  const FriendEvent_ApplicationDeleted(this.field0): super._();
  

@override final  String field0;

/// Create a copy of FriendEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FriendEvent_ApplicationDeletedCopyWith<FriendEvent_ApplicationDeleted> get copyWith => _$FriendEvent_ApplicationDeletedCopyWithImpl<FriendEvent_ApplicationDeleted>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FriendEvent_ApplicationDeleted&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'FriendEvent.applicationDeleted(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $FriendEvent_ApplicationDeletedCopyWith<$Res> implements $FriendEventCopyWith<$Res> {
  factory $FriendEvent_ApplicationDeletedCopyWith(FriendEvent_ApplicationDeleted value, $Res Function(FriendEvent_ApplicationDeleted) _then) = _$FriendEvent_ApplicationDeletedCopyWithImpl;
@useResult
$Res call({
 String field0
});




}
/// @nodoc
class _$FriendEvent_ApplicationDeletedCopyWithImpl<$Res>
    implements $FriendEvent_ApplicationDeletedCopyWith<$Res> {
  _$FriendEvent_ApplicationDeletedCopyWithImpl(this._self, this._then);

  final FriendEvent_ApplicationDeleted _self;
  final $Res Function(FriendEvent_ApplicationDeleted) _then;

/// Create a copy of FriendEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(FriendEvent_ApplicationDeleted(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class FriendEvent_ApplicationAccepted extends FriendEvent {
  const FriendEvent_ApplicationAccepted(this.field0): super._();
  

@override final  String field0;

/// Create a copy of FriendEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FriendEvent_ApplicationAcceptedCopyWith<FriendEvent_ApplicationAccepted> get copyWith => _$FriendEvent_ApplicationAcceptedCopyWithImpl<FriendEvent_ApplicationAccepted>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FriendEvent_ApplicationAccepted&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'FriendEvent.applicationAccepted(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $FriendEvent_ApplicationAcceptedCopyWith<$Res> implements $FriendEventCopyWith<$Res> {
  factory $FriendEvent_ApplicationAcceptedCopyWith(FriendEvent_ApplicationAccepted value, $Res Function(FriendEvent_ApplicationAccepted) _then) = _$FriendEvent_ApplicationAcceptedCopyWithImpl;
@useResult
$Res call({
 String field0
});




}
/// @nodoc
class _$FriendEvent_ApplicationAcceptedCopyWithImpl<$Res>
    implements $FriendEvent_ApplicationAcceptedCopyWith<$Res> {
  _$FriendEvent_ApplicationAcceptedCopyWithImpl(this._self, this._then);

  final FriendEvent_ApplicationAccepted _self;
  final $Res Function(FriendEvent_ApplicationAccepted) _then;

/// Create a copy of FriendEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(FriendEvent_ApplicationAccepted(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class FriendEvent_ApplicationRejected extends FriendEvent {
  const FriendEvent_ApplicationRejected(this.field0): super._();
  

@override final  String field0;

/// Create a copy of FriendEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FriendEvent_ApplicationRejectedCopyWith<FriendEvent_ApplicationRejected> get copyWith => _$FriendEvent_ApplicationRejectedCopyWithImpl<FriendEvent_ApplicationRejected>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FriendEvent_ApplicationRejected&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'FriendEvent.applicationRejected(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $FriendEvent_ApplicationRejectedCopyWith<$Res> implements $FriendEventCopyWith<$Res> {
  factory $FriendEvent_ApplicationRejectedCopyWith(FriendEvent_ApplicationRejected value, $Res Function(FriendEvent_ApplicationRejected) _then) = _$FriendEvent_ApplicationRejectedCopyWithImpl;
@useResult
$Res call({
 String field0
});




}
/// @nodoc
class _$FriendEvent_ApplicationRejectedCopyWithImpl<$Res>
    implements $FriendEvent_ApplicationRejectedCopyWith<$Res> {
  _$FriendEvent_ApplicationRejectedCopyWithImpl(this._self, this._then);

  final FriendEvent_ApplicationRejected _self;
  final $Res Function(FriendEvent_ApplicationRejected) _then;

/// Create a copy of FriendEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(FriendEvent_ApplicationRejected(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
