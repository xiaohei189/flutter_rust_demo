import 'package:freezed_annotation/freezed_annotation.dart';

part 'group.freezed.dart';

@freezed
class Group with _$Group {
  const factory Group({
    required String groupId,
    required String groupName,
    required String faceUrl,
    required String introduction,
    required String notification,
    required String ownerUserId,
    required int memberCount,
    required int status,
    DateTime? createdTime,
  }) = _Group;
}
