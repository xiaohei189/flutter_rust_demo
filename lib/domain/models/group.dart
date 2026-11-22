import 'package:freezed_annotation/freezed_annotation.dart';

import 'group_mode.dart';

part 'group.freezed.dart';

@freezed
abstract class Group with _$Group {
  const Group._();

  const factory Group({
    required String groupId,
    required String groupName,
    required String faceUrl,
    required String introduction,
    required String notification,
    required String ownerUserId,
    required int memberCount,
    required int status,
    @Default('') String ex,
    DateTime? createdTime,
  }) = _Group;

  GroupMode get mode => GroupMode.fromEx(ex);
}
