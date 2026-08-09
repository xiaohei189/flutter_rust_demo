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
mixin _$Friend {
  String get userId => throw _privateConstructorUsedError;
  String get nickname => throw _privateConstructorUsedError;
  String get faceUrl => throw _privateConstructorUsedError;
  int get gender => throw _privateConstructorUsedError;
  String get remark => throw _privateConstructorUsedError;
  String get addSource => throw _privateConstructorUsedError;
  String get ex => throw _privateConstructorUsedError;
  DateTime? get createdTime => throw _privateConstructorUsedError;

  /// Create a copy of Friend
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $FriendCopyWith<Friend> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $FriendCopyWith<$Res> {
  factory $FriendCopyWith(Friend value, $Res Function(Friend) then) =
      _$FriendCopyWithImpl<$Res, Friend>;
  @useResult
  $Res call({
    String userId,
    String nickname,
    String faceUrl,
    int gender,
    String remark,
    String addSource,
    String ex,
    DateTime? createdTime,
  });
}

/// @nodoc
class _$FriendCopyWithImpl<$Res, $Val extends Friend>
    implements $FriendCopyWith<$Res> {
  _$FriendCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Friend
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? userId = null,
    Object? nickname = null,
    Object? faceUrl = null,
    Object? gender = null,
    Object? remark = null,
    Object? addSource = null,
    Object? ex = null,
    Object? createdTime = freezed,
  }) {
    return _then(
      _value.copyWith(
            userId: null == userId
                ? _value.userId
                : userId // ignore: cast_nullable_to_non_nullable
                      as String,
            nickname: null == nickname
                ? _value.nickname
                : nickname // ignore: cast_nullable_to_non_nullable
                      as String,
            faceUrl: null == faceUrl
                ? _value.faceUrl
                : faceUrl // ignore: cast_nullable_to_non_nullable
                      as String,
            gender: null == gender
                ? _value.gender
                : gender // ignore: cast_nullable_to_non_nullable
                      as int,
            remark: null == remark
                ? _value.remark
                : remark // ignore: cast_nullable_to_non_nullable
                      as String,
            addSource: null == addSource
                ? _value.addSource
                : addSource // ignore: cast_nullable_to_non_nullable
                      as String,
            ex: null == ex
                ? _value.ex
                : ex // ignore: cast_nullable_to_non_nullable
                      as String,
            createdTime: freezed == createdTime
                ? _value.createdTime
                : createdTime // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$FriendImplCopyWith<$Res> implements $FriendCopyWith<$Res> {
  factory _$$FriendImplCopyWith(
    _$FriendImpl value,
    $Res Function(_$FriendImpl) then,
  ) = __$$FriendImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String userId,
    String nickname,
    String faceUrl,
    int gender,
    String remark,
    String addSource,
    String ex,
    DateTime? createdTime,
  });
}

/// @nodoc
class __$$FriendImplCopyWithImpl<$Res>
    extends _$FriendCopyWithImpl<$Res, _$FriendImpl>
    implements _$$FriendImplCopyWith<$Res> {
  __$$FriendImplCopyWithImpl(
    _$FriendImpl _value,
    $Res Function(_$FriendImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Friend
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? userId = null,
    Object? nickname = null,
    Object? faceUrl = null,
    Object? gender = null,
    Object? remark = null,
    Object? addSource = null,
    Object? ex = null,
    Object? createdTime = freezed,
  }) {
    return _then(
      _$FriendImpl(
        userId: null == userId
            ? _value.userId
            : userId // ignore: cast_nullable_to_non_nullable
                  as String,
        nickname: null == nickname
            ? _value.nickname
            : nickname // ignore: cast_nullable_to_non_nullable
                  as String,
        faceUrl: null == faceUrl
            ? _value.faceUrl
            : faceUrl // ignore: cast_nullable_to_non_nullable
                  as String,
        gender: null == gender
            ? _value.gender
            : gender // ignore: cast_nullable_to_non_nullable
                  as int,
        remark: null == remark
            ? _value.remark
            : remark // ignore: cast_nullable_to_non_nullable
                  as String,
        addSource: null == addSource
            ? _value.addSource
            : addSource // ignore: cast_nullable_to_non_nullable
                  as String,
        ex: null == ex
            ? _value.ex
            : ex // ignore: cast_nullable_to_non_nullable
                  as String,
        createdTime: freezed == createdTime
            ? _value.createdTime
            : createdTime // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
      ),
    );
  }
}

/// @nodoc

class _$FriendImpl implements _Friend {
  const _$FriendImpl({
    required this.userId,
    required this.nickname,
    required this.faceUrl,
    required this.gender,
    required this.remark,
    required this.addSource,
    required this.ex,
    this.createdTime,
  });

  @override
  final String userId;
  @override
  final String nickname;
  @override
  final String faceUrl;
  @override
  final int gender;
  @override
  final String remark;
  @override
  final String addSource;
  @override
  final String ex;
  @override
  final DateTime? createdTime;

  @override
  String toString() {
    return 'Friend(userId: $userId, nickname: $nickname, faceUrl: $faceUrl, gender: $gender, remark: $remark, addSource: $addSource, ex: $ex, createdTime: $createdTime)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FriendImpl &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.nickname, nickname) ||
                other.nickname == nickname) &&
            (identical(other.faceUrl, faceUrl) || other.faceUrl == faceUrl) &&
            (identical(other.gender, gender) || other.gender == gender) &&
            (identical(other.remark, remark) || other.remark == remark) &&
            (identical(other.addSource, addSource) ||
                other.addSource == addSource) &&
            (identical(other.ex, ex) || other.ex == ex) &&
            (identical(other.createdTime, createdTime) ||
                other.createdTime == createdTime));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    userId,
    nickname,
    faceUrl,
    gender,
    remark,
    addSource,
    ex,
    createdTime,
  );

  /// Create a copy of Friend
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$FriendImplCopyWith<_$FriendImpl> get copyWith =>
      __$$FriendImplCopyWithImpl<_$FriendImpl>(this, _$identity);
}

abstract class _Friend implements Friend {
  const factory _Friend({
    required final String userId,
    required final String nickname,
    required final String faceUrl,
    required final int gender,
    required final String remark,
    required final String addSource,
    required final String ex,
    final DateTime? createdTime,
  }) = _$FriendImpl;

  @override
  String get userId;
  @override
  String get nickname;
  @override
  String get faceUrl;
  @override
  int get gender;
  @override
  String get remark;
  @override
  String get addSource;
  @override
  String get ex;
  @override
  DateTime? get createdTime;

  /// Create a copy of Friend
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$FriendImplCopyWith<_$FriendImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
