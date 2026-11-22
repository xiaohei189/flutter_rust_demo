// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'group.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$GroupEvent {

 Object get field0;



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GroupEvent&&const DeepCollectionEquality().equals(other.field0, field0));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(field0));

@override
String toString() {
  return 'GroupEvent(field0: $field0)';
}


}

/// @nodoc
class $GroupEventCopyWith<$Res>  {
$GroupEventCopyWith(GroupEvent _, $Res Function(GroupEvent) __);
}


/// Adds pattern-matching-related methods to [GroupEvent].
extension GroupEventPatterns on GroupEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( GroupEvent_JoinedGroupAdded value)?  joinedGroupAdded,TResult Function( GroupEvent_JoinedGroupDeleted value)?  joinedGroupDeleted,TResult Function( GroupEvent_GroupInfoChanged value)?  groupInfoChanged,TResult Function( GroupEvent_MemberAdded value)?  memberAdded,TResult Function( GroupEvent_MemberDeleted value)?  memberDeleted,TResult Function( GroupEvent_MemberInfoChanged value)?  memberInfoChanged,TResult Function( GroupEvent_GroupReadReceipt value)?  groupReadReceipt,TResult Function( GroupEvent_ApplicationAdded value)?  applicationAdded,TResult Function( GroupEvent_ApplicationDeleted value)?  applicationDeleted,TResult Function( GroupEvent_ApplicationApproved value)?  applicationApproved,TResult Function( GroupEvent_ApplicationRejected value)?  applicationRejected,TResult Function( GroupEvent_Dismissed value)?  dismissed,required TResult orElse(),}){
final _that = this;
switch (_that) {
case GroupEvent_JoinedGroupAdded() when joinedGroupAdded != null:
return joinedGroupAdded(_that);case GroupEvent_JoinedGroupDeleted() when joinedGroupDeleted != null:
return joinedGroupDeleted(_that);case GroupEvent_GroupInfoChanged() when groupInfoChanged != null:
return groupInfoChanged(_that);case GroupEvent_MemberAdded() when memberAdded != null:
return memberAdded(_that);case GroupEvent_MemberDeleted() when memberDeleted != null:
return memberDeleted(_that);case GroupEvent_MemberInfoChanged() when memberInfoChanged != null:
return memberInfoChanged(_that);case GroupEvent_GroupReadReceipt() when groupReadReceipt != null:
return groupReadReceipt(_that);case GroupEvent_ApplicationAdded() when applicationAdded != null:
return applicationAdded(_that);case GroupEvent_ApplicationDeleted() when applicationDeleted != null:
return applicationDeleted(_that);case GroupEvent_ApplicationApproved() when applicationApproved != null:
return applicationApproved(_that);case GroupEvent_ApplicationRejected() when applicationRejected != null:
return applicationRejected(_that);case GroupEvent_Dismissed() when dismissed != null:
return dismissed(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( GroupEvent_JoinedGroupAdded value)  joinedGroupAdded,required TResult Function( GroupEvent_JoinedGroupDeleted value)  joinedGroupDeleted,required TResult Function( GroupEvent_GroupInfoChanged value)  groupInfoChanged,required TResult Function( GroupEvent_MemberAdded value)  memberAdded,required TResult Function( GroupEvent_MemberDeleted value)  memberDeleted,required TResult Function( GroupEvent_MemberInfoChanged value)  memberInfoChanged,required TResult Function( GroupEvent_GroupReadReceipt value)  groupReadReceipt,required TResult Function( GroupEvent_ApplicationAdded value)  applicationAdded,required TResult Function( GroupEvent_ApplicationDeleted value)  applicationDeleted,required TResult Function( GroupEvent_ApplicationApproved value)  applicationApproved,required TResult Function( GroupEvent_ApplicationRejected value)  applicationRejected,required TResult Function( GroupEvent_Dismissed value)  dismissed,}){
final _that = this;
switch (_that) {
case GroupEvent_JoinedGroupAdded():
return joinedGroupAdded(_that);case GroupEvent_JoinedGroupDeleted():
return joinedGroupDeleted(_that);case GroupEvent_GroupInfoChanged():
return groupInfoChanged(_that);case GroupEvent_MemberAdded():
return memberAdded(_that);case GroupEvent_MemberDeleted():
return memberDeleted(_that);case GroupEvent_MemberInfoChanged():
return memberInfoChanged(_that);case GroupEvent_GroupReadReceipt():
return groupReadReceipt(_that);case GroupEvent_ApplicationAdded():
return applicationAdded(_that);case GroupEvent_ApplicationDeleted():
return applicationDeleted(_that);case GroupEvent_ApplicationApproved():
return applicationApproved(_that);case GroupEvent_ApplicationRejected():
return applicationRejected(_that);case GroupEvent_Dismissed():
return dismissed(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( GroupEvent_JoinedGroupAdded value)?  joinedGroupAdded,TResult? Function( GroupEvent_JoinedGroupDeleted value)?  joinedGroupDeleted,TResult? Function( GroupEvent_GroupInfoChanged value)?  groupInfoChanged,TResult? Function( GroupEvent_MemberAdded value)?  memberAdded,TResult? Function( GroupEvent_MemberDeleted value)?  memberDeleted,TResult? Function( GroupEvent_MemberInfoChanged value)?  memberInfoChanged,TResult? Function( GroupEvent_GroupReadReceipt value)?  groupReadReceipt,TResult? Function( GroupEvent_ApplicationAdded value)?  applicationAdded,TResult? Function( GroupEvent_ApplicationDeleted value)?  applicationDeleted,TResult? Function( GroupEvent_ApplicationApproved value)?  applicationApproved,TResult? Function( GroupEvent_ApplicationRejected value)?  applicationRejected,TResult? Function( GroupEvent_Dismissed value)?  dismissed,}){
final _that = this;
switch (_that) {
case GroupEvent_JoinedGroupAdded() when joinedGroupAdded != null:
return joinedGroupAdded(_that);case GroupEvent_JoinedGroupDeleted() when joinedGroupDeleted != null:
return joinedGroupDeleted(_that);case GroupEvent_GroupInfoChanged() when groupInfoChanged != null:
return groupInfoChanged(_that);case GroupEvent_MemberAdded() when memberAdded != null:
return memberAdded(_that);case GroupEvent_MemberDeleted() when memberDeleted != null:
return memberDeleted(_that);case GroupEvent_MemberInfoChanged() when memberInfoChanged != null:
return memberInfoChanged(_that);case GroupEvent_GroupReadReceipt() when groupReadReceipt != null:
return groupReadReceipt(_that);case GroupEvent_ApplicationAdded() when applicationAdded != null:
return applicationAdded(_that);case GroupEvent_ApplicationDeleted() when applicationDeleted != null:
return applicationDeleted(_that);case GroupEvent_ApplicationApproved() when applicationApproved != null:
return applicationApproved(_that);case GroupEvent_ApplicationRejected() when applicationRejected != null:
return applicationRejected(_that);case GroupEvent_Dismissed() when dismissed != null:
return dismissed(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( GroupInfo field0)?  joinedGroupAdded,TResult Function( GroupInfo field0)?  joinedGroupDeleted,TResult Function( GroupInfo field0)?  groupInfoChanged,TResult Function( GroupMember field0)?  memberAdded,TResult Function( GroupMember field0)?  memberDeleted,TResult Function( GroupMember field0)?  memberInfoChanged,TResult Function( List<GroupReadReceipt> field0)?  groupReadReceipt,TResult Function( String field0)?  applicationAdded,TResult Function( String field0)?  applicationDeleted,TResult Function( String field0)?  applicationApproved,TResult Function( String field0)?  applicationRejected,TResult Function( GroupInfo field0)?  dismissed,required TResult orElse(),}) {final _that = this;
switch (_that) {
case GroupEvent_JoinedGroupAdded() when joinedGroupAdded != null:
return joinedGroupAdded(_that.field0);case GroupEvent_JoinedGroupDeleted() when joinedGroupDeleted != null:
return joinedGroupDeleted(_that.field0);case GroupEvent_GroupInfoChanged() when groupInfoChanged != null:
return groupInfoChanged(_that.field0);case GroupEvent_MemberAdded() when memberAdded != null:
return memberAdded(_that.field0);case GroupEvent_MemberDeleted() when memberDeleted != null:
return memberDeleted(_that.field0);case GroupEvent_MemberInfoChanged() when memberInfoChanged != null:
return memberInfoChanged(_that.field0);case GroupEvent_GroupReadReceipt() when groupReadReceipt != null:
return groupReadReceipt(_that.field0);case GroupEvent_ApplicationAdded() when applicationAdded != null:
return applicationAdded(_that.field0);case GroupEvent_ApplicationDeleted() when applicationDeleted != null:
return applicationDeleted(_that.field0);case GroupEvent_ApplicationApproved() when applicationApproved != null:
return applicationApproved(_that.field0);case GroupEvent_ApplicationRejected() when applicationRejected != null:
return applicationRejected(_that.field0);case GroupEvent_Dismissed() when dismissed != null:
return dismissed(_that.field0);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( GroupInfo field0)  joinedGroupAdded,required TResult Function( GroupInfo field0)  joinedGroupDeleted,required TResult Function( GroupInfo field0)  groupInfoChanged,required TResult Function( GroupMember field0)  memberAdded,required TResult Function( GroupMember field0)  memberDeleted,required TResult Function( GroupMember field0)  memberInfoChanged,required TResult Function( List<GroupReadReceipt> field0)  groupReadReceipt,required TResult Function( String field0)  applicationAdded,required TResult Function( String field0)  applicationDeleted,required TResult Function( String field0)  applicationApproved,required TResult Function( String field0)  applicationRejected,required TResult Function( GroupInfo field0)  dismissed,}) {final _that = this;
switch (_that) {
case GroupEvent_JoinedGroupAdded():
return joinedGroupAdded(_that.field0);case GroupEvent_JoinedGroupDeleted():
return joinedGroupDeleted(_that.field0);case GroupEvent_GroupInfoChanged():
return groupInfoChanged(_that.field0);case GroupEvent_MemberAdded():
return memberAdded(_that.field0);case GroupEvent_MemberDeleted():
return memberDeleted(_that.field0);case GroupEvent_MemberInfoChanged():
return memberInfoChanged(_that.field0);case GroupEvent_GroupReadReceipt():
return groupReadReceipt(_that.field0);case GroupEvent_ApplicationAdded():
return applicationAdded(_that.field0);case GroupEvent_ApplicationDeleted():
return applicationDeleted(_that.field0);case GroupEvent_ApplicationApproved():
return applicationApproved(_that.field0);case GroupEvent_ApplicationRejected():
return applicationRejected(_that.field0);case GroupEvent_Dismissed():
return dismissed(_that.field0);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( GroupInfo field0)?  joinedGroupAdded,TResult? Function( GroupInfo field0)?  joinedGroupDeleted,TResult? Function( GroupInfo field0)?  groupInfoChanged,TResult? Function( GroupMember field0)?  memberAdded,TResult? Function( GroupMember field0)?  memberDeleted,TResult? Function( GroupMember field0)?  memberInfoChanged,TResult? Function( List<GroupReadReceipt> field0)?  groupReadReceipt,TResult? Function( String field0)?  applicationAdded,TResult? Function( String field0)?  applicationDeleted,TResult? Function( String field0)?  applicationApproved,TResult? Function( String field0)?  applicationRejected,TResult? Function( GroupInfo field0)?  dismissed,}) {final _that = this;
switch (_that) {
case GroupEvent_JoinedGroupAdded() when joinedGroupAdded != null:
return joinedGroupAdded(_that.field0);case GroupEvent_JoinedGroupDeleted() when joinedGroupDeleted != null:
return joinedGroupDeleted(_that.field0);case GroupEvent_GroupInfoChanged() when groupInfoChanged != null:
return groupInfoChanged(_that.field0);case GroupEvent_MemberAdded() when memberAdded != null:
return memberAdded(_that.field0);case GroupEvent_MemberDeleted() when memberDeleted != null:
return memberDeleted(_that.field0);case GroupEvent_MemberInfoChanged() when memberInfoChanged != null:
return memberInfoChanged(_that.field0);case GroupEvent_GroupReadReceipt() when groupReadReceipt != null:
return groupReadReceipt(_that.field0);case GroupEvent_ApplicationAdded() when applicationAdded != null:
return applicationAdded(_that.field0);case GroupEvent_ApplicationDeleted() when applicationDeleted != null:
return applicationDeleted(_that.field0);case GroupEvent_ApplicationApproved() when applicationApproved != null:
return applicationApproved(_that.field0);case GroupEvent_ApplicationRejected() when applicationRejected != null:
return applicationRejected(_that.field0);case GroupEvent_Dismissed() when dismissed != null:
return dismissed(_that.field0);case _:
  return null;

}
}

}

/// @nodoc


class GroupEvent_JoinedGroupAdded extends GroupEvent {
  const GroupEvent_JoinedGroupAdded(this.field0): super._();
  

@override final  GroupInfo field0;

/// Create a copy of GroupEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GroupEvent_JoinedGroupAddedCopyWith<GroupEvent_JoinedGroupAdded> get copyWith => _$GroupEvent_JoinedGroupAddedCopyWithImpl<GroupEvent_JoinedGroupAdded>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GroupEvent_JoinedGroupAdded&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'GroupEvent.joinedGroupAdded(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $GroupEvent_JoinedGroupAddedCopyWith<$Res> implements $GroupEventCopyWith<$Res> {
  factory $GroupEvent_JoinedGroupAddedCopyWith(GroupEvent_JoinedGroupAdded value, $Res Function(GroupEvent_JoinedGroupAdded) _then) = _$GroupEvent_JoinedGroupAddedCopyWithImpl;
@useResult
$Res call({
 GroupInfo field0
});




}
/// @nodoc
class _$GroupEvent_JoinedGroupAddedCopyWithImpl<$Res>
    implements $GroupEvent_JoinedGroupAddedCopyWith<$Res> {
  _$GroupEvent_JoinedGroupAddedCopyWithImpl(this._self, this._then);

  final GroupEvent_JoinedGroupAdded _self;
  final $Res Function(GroupEvent_JoinedGroupAdded) _then;

/// Create a copy of GroupEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(GroupEvent_JoinedGroupAdded(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as GroupInfo,
  ));
}


}

/// @nodoc


class GroupEvent_JoinedGroupDeleted extends GroupEvent {
  const GroupEvent_JoinedGroupDeleted(this.field0): super._();
  

@override final  GroupInfo field0;

/// Create a copy of GroupEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GroupEvent_JoinedGroupDeletedCopyWith<GroupEvent_JoinedGroupDeleted> get copyWith => _$GroupEvent_JoinedGroupDeletedCopyWithImpl<GroupEvent_JoinedGroupDeleted>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GroupEvent_JoinedGroupDeleted&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'GroupEvent.joinedGroupDeleted(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $GroupEvent_JoinedGroupDeletedCopyWith<$Res> implements $GroupEventCopyWith<$Res> {
  factory $GroupEvent_JoinedGroupDeletedCopyWith(GroupEvent_JoinedGroupDeleted value, $Res Function(GroupEvent_JoinedGroupDeleted) _then) = _$GroupEvent_JoinedGroupDeletedCopyWithImpl;
@useResult
$Res call({
 GroupInfo field0
});




}
/// @nodoc
class _$GroupEvent_JoinedGroupDeletedCopyWithImpl<$Res>
    implements $GroupEvent_JoinedGroupDeletedCopyWith<$Res> {
  _$GroupEvent_JoinedGroupDeletedCopyWithImpl(this._self, this._then);

  final GroupEvent_JoinedGroupDeleted _self;
  final $Res Function(GroupEvent_JoinedGroupDeleted) _then;

/// Create a copy of GroupEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(GroupEvent_JoinedGroupDeleted(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as GroupInfo,
  ));
}


}

/// @nodoc


class GroupEvent_GroupInfoChanged extends GroupEvent {
  const GroupEvent_GroupInfoChanged(this.field0): super._();
  

@override final  GroupInfo field0;

/// Create a copy of GroupEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GroupEvent_GroupInfoChangedCopyWith<GroupEvent_GroupInfoChanged> get copyWith => _$GroupEvent_GroupInfoChangedCopyWithImpl<GroupEvent_GroupInfoChanged>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GroupEvent_GroupInfoChanged&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'GroupEvent.groupInfoChanged(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $GroupEvent_GroupInfoChangedCopyWith<$Res> implements $GroupEventCopyWith<$Res> {
  factory $GroupEvent_GroupInfoChangedCopyWith(GroupEvent_GroupInfoChanged value, $Res Function(GroupEvent_GroupInfoChanged) _then) = _$GroupEvent_GroupInfoChangedCopyWithImpl;
@useResult
$Res call({
 GroupInfo field0
});




}
/// @nodoc
class _$GroupEvent_GroupInfoChangedCopyWithImpl<$Res>
    implements $GroupEvent_GroupInfoChangedCopyWith<$Res> {
  _$GroupEvent_GroupInfoChangedCopyWithImpl(this._self, this._then);

  final GroupEvent_GroupInfoChanged _self;
  final $Res Function(GroupEvent_GroupInfoChanged) _then;

/// Create a copy of GroupEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(GroupEvent_GroupInfoChanged(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as GroupInfo,
  ));
}


}

/// @nodoc


class GroupEvent_MemberAdded extends GroupEvent {
  const GroupEvent_MemberAdded(this.field0): super._();
  

@override final  GroupMember field0;

/// Create a copy of GroupEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GroupEvent_MemberAddedCopyWith<GroupEvent_MemberAdded> get copyWith => _$GroupEvent_MemberAddedCopyWithImpl<GroupEvent_MemberAdded>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GroupEvent_MemberAdded&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'GroupEvent.memberAdded(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $GroupEvent_MemberAddedCopyWith<$Res> implements $GroupEventCopyWith<$Res> {
  factory $GroupEvent_MemberAddedCopyWith(GroupEvent_MemberAdded value, $Res Function(GroupEvent_MemberAdded) _then) = _$GroupEvent_MemberAddedCopyWithImpl;
@useResult
$Res call({
 GroupMember field0
});




}
/// @nodoc
class _$GroupEvent_MemberAddedCopyWithImpl<$Res>
    implements $GroupEvent_MemberAddedCopyWith<$Res> {
  _$GroupEvent_MemberAddedCopyWithImpl(this._self, this._then);

  final GroupEvent_MemberAdded _self;
  final $Res Function(GroupEvent_MemberAdded) _then;

/// Create a copy of GroupEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(GroupEvent_MemberAdded(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as GroupMember,
  ));
}


}

/// @nodoc


class GroupEvent_MemberDeleted extends GroupEvent {
  const GroupEvent_MemberDeleted(this.field0): super._();
  

@override final  GroupMember field0;

/// Create a copy of GroupEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GroupEvent_MemberDeletedCopyWith<GroupEvent_MemberDeleted> get copyWith => _$GroupEvent_MemberDeletedCopyWithImpl<GroupEvent_MemberDeleted>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GroupEvent_MemberDeleted&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'GroupEvent.memberDeleted(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $GroupEvent_MemberDeletedCopyWith<$Res> implements $GroupEventCopyWith<$Res> {
  factory $GroupEvent_MemberDeletedCopyWith(GroupEvent_MemberDeleted value, $Res Function(GroupEvent_MemberDeleted) _then) = _$GroupEvent_MemberDeletedCopyWithImpl;
@useResult
$Res call({
 GroupMember field0
});




}
/// @nodoc
class _$GroupEvent_MemberDeletedCopyWithImpl<$Res>
    implements $GroupEvent_MemberDeletedCopyWith<$Res> {
  _$GroupEvent_MemberDeletedCopyWithImpl(this._self, this._then);

  final GroupEvent_MemberDeleted _self;
  final $Res Function(GroupEvent_MemberDeleted) _then;

/// Create a copy of GroupEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(GroupEvent_MemberDeleted(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as GroupMember,
  ));
}


}

/// @nodoc


class GroupEvent_MemberInfoChanged extends GroupEvent {
  const GroupEvent_MemberInfoChanged(this.field0): super._();
  

@override final  GroupMember field0;

/// Create a copy of GroupEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GroupEvent_MemberInfoChangedCopyWith<GroupEvent_MemberInfoChanged> get copyWith => _$GroupEvent_MemberInfoChangedCopyWithImpl<GroupEvent_MemberInfoChanged>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GroupEvent_MemberInfoChanged&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'GroupEvent.memberInfoChanged(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $GroupEvent_MemberInfoChangedCopyWith<$Res> implements $GroupEventCopyWith<$Res> {
  factory $GroupEvent_MemberInfoChangedCopyWith(GroupEvent_MemberInfoChanged value, $Res Function(GroupEvent_MemberInfoChanged) _then) = _$GroupEvent_MemberInfoChangedCopyWithImpl;
@useResult
$Res call({
 GroupMember field0
});




}
/// @nodoc
class _$GroupEvent_MemberInfoChangedCopyWithImpl<$Res>
    implements $GroupEvent_MemberInfoChangedCopyWith<$Res> {
  _$GroupEvent_MemberInfoChangedCopyWithImpl(this._self, this._then);

  final GroupEvent_MemberInfoChanged _self;
  final $Res Function(GroupEvent_MemberInfoChanged) _then;

/// Create a copy of GroupEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(GroupEvent_MemberInfoChanged(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as GroupMember,
  ));
}


}

/// @nodoc


class GroupEvent_GroupReadReceipt extends GroupEvent {
  const GroupEvent_GroupReadReceipt(final  List<GroupReadReceipt> field0): _field0 = field0,super._();
  

 final  List<GroupReadReceipt> _field0;
@override List<GroupReadReceipt> get field0 {
  if (_field0 is EqualUnmodifiableListView) return _field0;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_field0);
}


/// Create a copy of GroupEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GroupEvent_GroupReadReceiptCopyWith<GroupEvent_GroupReadReceipt> get copyWith => _$GroupEvent_GroupReadReceiptCopyWithImpl<GroupEvent_GroupReadReceipt>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GroupEvent_GroupReadReceipt&&const DeepCollectionEquality().equals(other._field0, _field0));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_field0));

@override
String toString() {
  return 'GroupEvent.groupReadReceipt(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $GroupEvent_GroupReadReceiptCopyWith<$Res> implements $GroupEventCopyWith<$Res> {
  factory $GroupEvent_GroupReadReceiptCopyWith(GroupEvent_GroupReadReceipt value, $Res Function(GroupEvent_GroupReadReceipt) _then) = _$GroupEvent_GroupReadReceiptCopyWithImpl;
@useResult
$Res call({
 List<GroupReadReceipt> field0
});




}
/// @nodoc
class _$GroupEvent_GroupReadReceiptCopyWithImpl<$Res>
    implements $GroupEvent_GroupReadReceiptCopyWith<$Res> {
  _$GroupEvent_GroupReadReceiptCopyWithImpl(this._self, this._then);

  final GroupEvent_GroupReadReceipt _self;
  final $Res Function(GroupEvent_GroupReadReceipt) _then;

/// Create a copy of GroupEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(GroupEvent_GroupReadReceipt(
null == field0 ? _self._field0 : field0 // ignore: cast_nullable_to_non_nullable
as List<GroupReadReceipt>,
  ));
}


}

/// @nodoc


class GroupEvent_ApplicationAdded extends GroupEvent {
  const GroupEvent_ApplicationAdded(this.field0): super._();
  

@override final  String field0;

/// Create a copy of GroupEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GroupEvent_ApplicationAddedCopyWith<GroupEvent_ApplicationAdded> get copyWith => _$GroupEvent_ApplicationAddedCopyWithImpl<GroupEvent_ApplicationAdded>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GroupEvent_ApplicationAdded&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'GroupEvent.applicationAdded(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $GroupEvent_ApplicationAddedCopyWith<$Res> implements $GroupEventCopyWith<$Res> {
  factory $GroupEvent_ApplicationAddedCopyWith(GroupEvent_ApplicationAdded value, $Res Function(GroupEvent_ApplicationAdded) _then) = _$GroupEvent_ApplicationAddedCopyWithImpl;
@useResult
$Res call({
 String field0
});




}
/// @nodoc
class _$GroupEvent_ApplicationAddedCopyWithImpl<$Res>
    implements $GroupEvent_ApplicationAddedCopyWith<$Res> {
  _$GroupEvent_ApplicationAddedCopyWithImpl(this._self, this._then);

  final GroupEvent_ApplicationAdded _self;
  final $Res Function(GroupEvent_ApplicationAdded) _then;

/// Create a copy of GroupEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(GroupEvent_ApplicationAdded(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class GroupEvent_ApplicationDeleted extends GroupEvent {
  const GroupEvent_ApplicationDeleted(this.field0): super._();
  

@override final  String field0;

/// Create a copy of GroupEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GroupEvent_ApplicationDeletedCopyWith<GroupEvent_ApplicationDeleted> get copyWith => _$GroupEvent_ApplicationDeletedCopyWithImpl<GroupEvent_ApplicationDeleted>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GroupEvent_ApplicationDeleted&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'GroupEvent.applicationDeleted(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $GroupEvent_ApplicationDeletedCopyWith<$Res> implements $GroupEventCopyWith<$Res> {
  factory $GroupEvent_ApplicationDeletedCopyWith(GroupEvent_ApplicationDeleted value, $Res Function(GroupEvent_ApplicationDeleted) _then) = _$GroupEvent_ApplicationDeletedCopyWithImpl;
@useResult
$Res call({
 String field0
});




}
/// @nodoc
class _$GroupEvent_ApplicationDeletedCopyWithImpl<$Res>
    implements $GroupEvent_ApplicationDeletedCopyWith<$Res> {
  _$GroupEvent_ApplicationDeletedCopyWithImpl(this._self, this._then);

  final GroupEvent_ApplicationDeleted _self;
  final $Res Function(GroupEvent_ApplicationDeleted) _then;

/// Create a copy of GroupEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(GroupEvent_ApplicationDeleted(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class GroupEvent_ApplicationApproved extends GroupEvent {
  const GroupEvent_ApplicationApproved(this.field0): super._();
  

@override final  String field0;

/// Create a copy of GroupEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GroupEvent_ApplicationApprovedCopyWith<GroupEvent_ApplicationApproved> get copyWith => _$GroupEvent_ApplicationApprovedCopyWithImpl<GroupEvent_ApplicationApproved>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GroupEvent_ApplicationApproved&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'GroupEvent.applicationApproved(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $GroupEvent_ApplicationApprovedCopyWith<$Res> implements $GroupEventCopyWith<$Res> {
  factory $GroupEvent_ApplicationApprovedCopyWith(GroupEvent_ApplicationApproved value, $Res Function(GroupEvent_ApplicationApproved) _then) = _$GroupEvent_ApplicationApprovedCopyWithImpl;
@useResult
$Res call({
 String field0
});




}
/// @nodoc
class _$GroupEvent_ApplicationApprovedCopyWithImpl<$Res>
    implements $GroupEvent_ApplicationApprovedCopyWith<$Res> {
  _$GroupEvent_ApplicationApprovedCopyWithImpl(this._self, this._then);

  final GroupEvent_ApplicationApproved _self;
  final $Res Function(GroupEvent_ApplicationApproved) _then;

/// Create a copy of GroupEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(GroupEvent_ApplicationApproved(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class GroupEvent_ApplicationRejected extends GroupEvent {
  const GroupEvent_ApplicationRejected(this.field0): super._();
  

@override final  String field0;

/// Create a copy of GroupEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GroupEvent_ApplicationRejectedCopyWith<GroupEvent_ApplicationRejected> get copyWith => _$GroupEvent_ApplicationRejectedCopyWithImpl<GroupEvent_ApplicationRejected>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GroupEvent_ApplicationRejected&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'GroupEvent.applicationRejected(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $GroupEvent_ApplicationRejectedCopyWith<$Res> implements $GroupEventCopyWith<$Res> {
  factory $GroupEvent_ApplicationRejectedCopyWith(GroupEvent_ApplicationRejected value, $Res Function(GroupEvent_ApplicationRejected) _then) = _$GroupEvent_ApplicationRejectedCopyWithImpl;
@useResult
$Res call({
 String field0
});




}
/// @nodoc
class _$GroupEvent_ApplicationRejectedCopyWithImpl<$Res>
    implements $GroupEvent_ApplicationRejectedCopyWith<$Res> {
  _$GroupEvent_ApplicationRejectedCopyWithImpl(this._self, this._then);

  final GroupEvent_ApplicationRejected _self;
  final $Res Function(GroupEvent_ApplicationRejected) _then;

/// Create a copy of GroupEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(GroupEvent_ApplicationRejected(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class GroupEvent_Dismissed extends GroupEvent {
  const GroupEvent_Dismissed(this.field0): super._();
  

@override final  GroupInfo field0;

/// Create a copy of GroupEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GroupEvent_DismissedCopyWith<GroupEvent_Dismissed> get copyWith => _$GroupEvent_DismissedCopyWithImpl<GroupEvent_Dismissed>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GroupEvent_Dismissed&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'GroupEvent.dismissed(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $GroupEvent_DismissedCopyWith<$Res> implements $GroupEventCopyWith<$Res> {
  factory $GroupEvent_DismissedCopyWith(GroupEvent_Dismissed value, $Res Function(GroupEvent_Dismissed) _then) = _$GroupEvent_DismissedCopyWithImpl;
@useResult
$Res call({
 GroupInfo field0
});




}
/// @nodoc
class _$GroupEvent_DismissedCopyWithImpl<$Res>
    implements $GroupEvent_DismissedCopyWith<$Res> {
  _$GroupEvent_DismissedCopyWithImpl(this._self, this._then);

  final GroupEvent_Dismissed _self;
  final $Res Function(GroupEvent_Dismissed) _then;

/// Create a copy of GroupEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(GroupEvent_Dismissed(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as GroupInfo,
  ));
}


}

// dart format on
