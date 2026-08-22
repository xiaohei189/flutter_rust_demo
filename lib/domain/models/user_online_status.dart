/// 用户在线状态领域模型。
///
/// 生成模型 [OnlineStatus] 仅在 Data 层出现，UI/应用层统一使用本模型。
class UserOnlineStatus {
  const UserOnlineStatus({
    required this.userId,
    required this.status,
    required this.platformIds,
  });

  /// 用户 ID
  final String userId;

  /// 在线状态（0:离线, 1:在线）
  final int status;

  /// 在线平台 ID 列表
  final List<int> platformIds;

  /// 是否在线
  bool get isOnline => status == 1;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserOnlineStatus &&
          runtimeType == other.runtimeType &&
          userId == other.userId &&
          status == other.status &&
          _listEquals(platformIds, other.platformIds);

  @override
  int get hashCode => userId.hashCode ^ status.hashCode ^ Object.hashAll(platformIds);

  static bool _listEquals(List<int> a, List<int> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}