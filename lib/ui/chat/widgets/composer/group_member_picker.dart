import 'package:flutter/material.dart';

import '../../../../domain/models/group_member.dart';
import '../../../../domain/models/user.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/user_avatar.dart';

Future<GroupMember?> showGroupMemberPicker(
  BuildContext context,
  List<GroupMember> members,
) {
  return showModalBottomSheet<GroupMember>(
    context: context,
    backgroundColor: context.appColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Text(
              '@ 选择群成员',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: members.length,
              itemBuilder: (_, i) {
                final member = members[i];
                return ListTile(
                  leading: UserAvatar(
                    user: User(
                      id: member.userId,
                      name: member.nickname,
                      avatar: member.faceUrl.isNotEmpty ? member.faceUrl : null,
                    ),
                    radius: 18,
                  ),
                  title: Text(
                    member.nickname.isNotEmpty ? member.nickname : member.userId,
                  ),
                  onTap: () => Navigator.of(ctx).pop(member),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

void insertAtMention(
  TextEditingController controller,
  String displayName,
  String userId,
) {
  final text = controller.text;
  final suffix = text.isEmpty || text.endsWith(' ') ? '' : ' ';
  final inserted = '$text$suffix@$displayName ';
  controller.value = TextEditingValue(
    text: inserted,
    selection: TextSelection.collapsed(offset: inserted.length),
  );
}