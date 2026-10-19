import 'group_member.dart';

/// OpenIM「@所有人」标签（对齐 Rust `constant::AT_ALL_TAG`）。
///
/// 发送时把它放进 atUserList，服务端据此计算会话的 groupAtType，
/// 接收端才能看到「@我」提醒。
const String kAtAllTag = 'AtAllTag';

/// 「@所有人」在输入框与气泡里展示的文本。
const String kAtAllDisplayName = '所有人';

/// 构造「所有人」伪成员，供 @ 选择器与实时提示列表复用。
GroupMember atAllGroupMember(String groupId) => GroupMember(
  groupId: groupId,
  userId: kAtAllTag,
  nickname: kAtAllDisplayName,
  faceUrl: '',
  roleLevel: -1,
  joinSource: '',
);
