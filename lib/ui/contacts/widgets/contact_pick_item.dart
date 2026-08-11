/// 联系人选择结果项。
class ContactPickItem {
  final String id;
  final String name;
  final String avatarUrl;
  final bool isGroup;

  const ContactPickItem({
    required this.id,
    required this.name,
    required this.avatarUrl,
    required this.isGroup,
  });
}
