import 'package:flutter/material.dart';

import '../../../../domain/models/group_member.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_image.dart';

/// 输入框上方的 @ 成员候选列表，随关键字过滤并高亮当前选中项。
class AtMemberSuggestions extends StatelessWidget {
  const AtMemberSuggestions({
    super.key,
    required this.members,
    required this.selectedIndex,
    required this.onSelect,
  });

  final List<GroupMember> members;
  final int selectedIndex;
  final ValueChanged<GroupMember> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Material(
      color: colors.surface,
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: colors.divider, width: 0.5)),
        ),
        child: members.isEmpty
            ? Center(
                child: Text(
                  '无匹配成员',
                  style: TextStyle(color: colors.textSecondary, fontSize: 13),
                ),
              )
            : ListView.builder(
                itemCount: members.length,
                itemBuilder: (_, i) {
                  final member = members[i];
                  return ListTile(
                    dense: true,
                    selected: i == selectedIndex,
                    selectedTileColor: colors.surfaceMuted,
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: colors.surfaceMuted,
                      child: member.faceUrl.isNotEmpty
                          ? ClipOval(
                              child: AppImage(
                                source: member.faceUrl,
                                width: 32,
                                height: 32,
                                fit: BoxFit.cover,
                              ),
                            )
                          : Icon(Icons.person, size: 18, color: colors.textSecondary),
                    ),
                    title: Text(
                      member.nickname.isNotEmpty ? member.nickname : member.userId,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      member.userId,
                      style: TextStyle(fontSize: 11, color: colors.textSecondary),
                    ),
                    onTap: () => onSelect(member),
                  );
                },
              ),
      ),
    );
  }
}