/// 群消息已读回执领域模型
class GroupReadReceipt {
  final String groupId;
  final String msgId;
  final List<String> hasReadUserIdList;
  final int hasReadCount;
  final int groupMemberCount;
  final int readTime;

  const GroupReadReceipt({
    required this.groupId,
    required this.msgId,
    required this.hasReadUserIdList,
    required this.hasReadCount,
    required this.groupMemberCount,
    required this.readTime,
  });
}