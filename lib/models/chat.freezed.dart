// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'chat.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

Chat _$ChatFromJson(Map<String, dynamic> json) {
  return _Chat.fromJson(json);
}

/// @nodoc
mixin _$Chat {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String? get avatar => throw _privateConstructorUsedError;
  bool get isGroup => throw _privateConstructorUsedError;
  int get unreadCount => throw _privateConstructorUsedError;
  String get lastMessage => throw _privateConstructorUsedError;
  DateTime get lastMessageTime => throw _privateConstructorUsedError;
  List<String>? get memberIds => throw _privateConstructorUsedError;
  String? get groupId => throw _privateConstructorUsedError;

  /// Serializes this Chat to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Chat
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ChatCopyWith<Chat> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ChatCopyWith<$Res> {
  factory $ChatCopyWith(Chat value, $Res Function(Chat) then) =
      _$ChatCopyWithImpl<$Res, Chat>;
  @useResult
  $Res call({
    String id,
    String name,
    String? avatar,
    bool isGroup,
    int unreadCount,
    String lastMessage,
    DateTime lastMessageTime,
    List<String>? memberIds,
    String? groupId,
  });
}

/// @nodoc
class _$ChatCopyWithImpl<$Res, $Val extends Chat>
    implements $ChatCopyWith<$Res> {
  _$ChatCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Chat
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? avatar = freezed,
    Object? isGroup = null,
    Object? unreadCount = null,
    Object? lastMessage = null,
    Object? lastMessageTime = null,
    Object? memberIds = freezed,
    Object? groupId = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            avatar: freezed == avatar
                ? _value.avatar
                : avatar // ignore: cast_nullable_to_non_nullable
                      as String?,
            isGroup: null == isGroup
                ? _value.isGroup
                : isGroup // ignore: cast_nullable_to_non_nullable
                      as bool,
            unreadCount: null == unreadCount
                ? _value.unreadCount
                : unreadCount // ignore: cast_nullable_to_non_nullable
                      as int,
            lastMessage: null == lastMessage
                ? _value.lastMessage
                : lastMessage // ignore: cast_nullable_to_non_nullable
                      as String,
            lastMessageTime: null == lastMessageTime
                ? _value.lastMessageTime
                : lastMessageTime // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            memberIds: freezed == memberIds
                ? _value.memberIds
                : memberIds // ignore: cast_nullable_to_non_nullable
                      as List<String>?,
            groupId: freezed == groupId
                ? _value.groupId
                : groupId // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ChatImplCopyWith<$Res> implements $ChatCopyWith<$Res> {
  factory _$$ChatImplCopyWith(
    _$ChatImpl value,
    $Res Function(_$ChatImpl) then,
  ) = __$$ChatImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String name,
    String? avatar,
    bool isGroup,
    int unreadCount,
    String lastMessage,
    DateTime lastMessageTime,
    List<String>? memberIds,
    String? groupId,
  });
}

/// @nodoc
class __$$ChatImplCopyWithImpl<$Res>
    extends _$ChatCopyWithImpl<$Res, _$ChatImpl>
    implements _$$ChatImplCopyWith<$Res> {
  __$$ChatImplCopyWithImpl(_$ChatImpl _value, $Res Function(_$ChatImpl) _then)
    : super(_value, _then);

  /// Create a copy of Chat
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? avatar = freezed,
    Object? isGroup = null,
    Object? unreadCount = null,
    Object? lastMessage = null,
    Object? lastMessageTime = null,
    Object? memberIds = freezed,
    Object? groupId = freezed,
  }) {
    return _then(
      _$ChatImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        avatar: freezed == avatar
            ? _value.avatar
            : avatar // ignore: cast_nullable_to_non_nullable
                  as String?,
        isGroup: null == isGroup
            ? _value.isGroup
            : isGroup // ignore: cast_nullable_to_non_nullable
                  as bool,
        unreadCount: null == unreadCount
            ? _value.unreadCount
            : unreadCount // ignore: cast_nullable_to_non_nullable
                  as int,
        lastMessage: null == lastMessage
            ? _value.lastMessage
            : lastMessage // ignore: cast_nullable_to_non_nullable
                  as String,
        lastMessageTime: null == lastMessageTime
            ? _value.lastMessageTime
            : lastMessageTime // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        memberIds: freezed == memberIds
            ? _value._memberIds
            : memberIds // ignore: cast_nullable_to_non_nullable
                  as List<String>?,
        groupId: freezed == groupId
            ? _value.groupId
            : groupId // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ChatImpl implements _Chat {
  const _$ChatImpl({
    required this.id,
    required this.name,
    this.avatar,
    required this.isGroup,
    required this.unreadCount,
    required this.lastMessage,
    required this.lastMessageTime,
    final List<String>? memberIds,
    this.groupId,
  }) : _memberIds = memberIds;

  factory _$ChatImpl.fromJson(Map<String, dynamic> json) =>
      _$$ChatImplFromJson(json);

  @override
  final String id;
  @override
  final String name;
  @override
  final String? avatar;
  @override
  final bool isGroup;
  @override
  final int unreadCount;
  @override
  final String lastMessage;
  @override
  final DateTime lastMessageTime;
  final List<String>? _memberIds;
  @override
  List<String>? get memberIds {
    final value = _memberIds;
    if (value == null) return null;
    if (_memberIds is EqualUnmodifiableListView) return _memberIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  @override
  final String? groupId;

  @override
  String toString() {
    return 'Chat(id: $id, name: $name, avatar: $avatar, isGroup: $isGroup, unreadCount: $unreadCount, lastMessage: $lastMessage, lastMessageTime: $lastMessageTime, memberIds: $memberIds, groupId: $groupId)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ChatImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.avatar, avatar) || other.avatar == avatar) &&
            (identical(other.isGroup, isGroup) || other.isGroup == isGroup) &&
            (identical(other.unreadCount, unreadCount) ||
                other.unreadCount == unreadCount) &&
            (identical(other.lastMessage, lastMessage) ||
                other.lastMessage == lastMessage) &&
            (identical(other.lastMessageTime, lastMessageTime) ||
                other.lastMessageTime == lastMessageTime) &&
            const DeepCollectionEquality().equals(
              other._memberIds,
              _memberIds,
            ) &&
            (identical(other.groupId, groupId) || other.groupId == groupId));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    name,
    avatar,
    isGroup,
    unreadCount,
    lastMessage,
    lastMessageTime,
    const DeepCollectionEquality().hash(_memberIds),
    groupId,
  );

  /// Create a copy of Chat
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ChatImplCopyWith<_$ChatImpl> get copyWith =>
      __$$ChatImplCopyWithImpl<_$ChatImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ChatImplToJson(this);
  }
}

abstract class _Chat implements Chat {
  const factory _Chat({
    required final String id,
    required final String name,
    final String? avatar,
    required final bool isGroup,
    required final int unreadCount,
    required final String lastMessage,
    required final DateTime lastMessageTime,
    final List<String>? memberIds,
    final String? groupId,
  }) = _$ChatImpl;

  factory _Chat.fromJson(Map<String, dynamic> json) = _$ChatImpl.fromJson;

  @override
  String get id;
  @override
  String get name;
  @override
  String? get avatar;
  @override
  bool get isGroup;
  @override
  int get unreadCount;
  @override
  String get lastMessage;
  @override
  DateTime get lastMessageTime;
  @override
  List<String>? get memberIds;
  @override
  String? get groupId;

  /// Create a copy of Chat
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ChatImplCopyWith<_$ChatImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
