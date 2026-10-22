import 'package:flutter/material.dart';

import '../../../../domain/models/group_member.dart';

/// @ 成员查询：根据光标位置解析关键字，并按昵称/ID 过滤成员。
class AtMemberQuery {
  const AtMemberQuery();
  String? resolve(
    String text,
    TextSelection selection, {
    required bool isGroupChat,
    required List<GroupMember>? atMembers,
  }) {
    if (!isGroupChat || atMembers == null || atMembers.isEmpty) return null;
    final caret = selection.isValid ? selection.baseOffset : text.length;
    final searchFrom = caret > 0 ? caret - 1 : 0;
    final lastAt = text.lastIndexOf('@', searchFrom);
    if (lastAt < 0) return null;
    final token = text.substring(lastAt + 1, caret);
    // 已经插入完整昵称（后面跟了空格/标点）后不再弹候选，
    // 否则工具栏选人后列表会立刻重新展开。
    if (RegExp(r'\s').hasMatch(token)) return null;
    return token.trim();
  }

  List<GroupMember> filter(String? keyword, List<GroupMember> members) {
    if (keyword == null) return const [];
    if (keyword.isEmpty) return members;
    final lower = keyword.toLowerCase();
    return members
        .where(
          (m) =>
              m.nickname.toLowerCase().contains(lower) ||
              m.userId.toLowerCase().contains(lower),
        )
        .toList();
  }

  int normalizedIndex(int index, int length) =>
      length == 0 ? 0 : index % length;
}
