import 'package:freezed_annotation/freezed_annotation.dart';

part 'group_application.freezed.dart';

@freezed
class GroupApplication with _$GroupApplication {
  const factory GroupApplication({
    required String groupId,
    required String userId,
    required String nickname,
    required String faceUrl,
    required String reason,
    required int handleResult,
    String? ex,
  }) = _GroupApplication;
}
