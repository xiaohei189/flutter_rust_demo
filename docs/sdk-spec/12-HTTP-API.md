# HTTP API 路由完整参考

> 来源：Go SDK `pkg/api/api.go`
> 用途：Rust SDK HTTP 客户端实现的路由对齐参考

---

## 概述

Go SDK 中所有 HTTP API 路由定义在 `pkg/api/api.go` 中，使用泛型 `newApi[Req, Resp]` 封装请求/响应类型。Rust SDK 需要在 `rust/src/infra/http/routes.rs` 中实现等价的路由定义。

### API 路由格式

所有路由以 `/{module}/{action}` 格式组织，由 HTTP 客户端拼接 baseURL 后发送请求。

### 通用请求/响应类型映射

| Go Protocol 包 | Rust 等价路径 | 说明 |
|----------------|--------------|------|
| `auth.*` | `openim_protocol::auth::*` | 认证相关 |
| `user.*` | `openim_protocol::user::*` | 用户相关 |
| `relation.*` | `openim_protocol::relation::*` | 好友/关系相关 |
| `group.*` | `openim_protocol::group::*` | 群组相关 |
| `conversation.*` | `openim_protocol::conversation::*` | 会话相关 |
| `msg.*` | `openim_protocol::msg::*` | 消息相关 |
| `third.*` | `openim_protocol::third::*` | 第三方服务 |
| `jssdk.*` | `openim_protocol::jssdk::*` | JS SDK 专用 |

---

## 1. Auth 模块 (3 个路由)

### 1.1 解析 Token

| 属性 | 值 |
|------|-----|
| **路由** | `/auth/parse_token` |
| **请求类型** | `auth::ParseTokenReq` |
| **响应类型** | `auth::ParseTokenResp` |
| **描述** | 解析 JWT Token，返回用户信息和过期时间 |

### 1.2 获取管理员 Token

| 属性 | 值 |
|------|-----|
| **路由** | `/auth/get_admin_token` |
| **请求类型** | `auth::GetAdminTokenReq` |
| **响应类型** | `auth::GetAdminTokenResp` |
| **描述** | 获取管理员权限的 Token（用于管理接口） |

### 1.3 获取用户 Token

| 属性 | 值 |
|------|-----|
| **路由** | `/auth/get_user_token` |
| **请求类型** | `auth::GetUserTokenReq` |
| **响应类型** | `auth::GetUserTokenResp` |
| **描述** | 获取用户登录 Token（注册/登录后调用） |

---

## 2. User 模块 (5 个路由)

### 2.1 获取指定用户信息

| 属性 | 值 |
|------|-----|
| **路由** | `/user/get_users_info` |
| **请求类型** | `user::GetDesignateUsersReq` |
| **响应类型** | `user::GetDesignateUsersResp` |
| **描述** | 批量获取指定用户的信息 |

### 2.2 更新用户信息

| 属性 | 值 |
|------|-----|
| **路由** | `/user/update_user_info` |
| **请求类型** | `user::UpdateUserInfoReq` |
| **响应类型** | `user::UpdateUserInfoResp` |
| **描述** | 更新当前用户的基本信息 |

### 2.3 更新用户信息（扩展）

| 属性 | 值 |
|------|-----|
| **路由** | `/user/update_user_info_ex` |
| **请求类型** | `user::UpdateUserInfoExReq` |
| **响应类型** | `user::UpdateUserInfoExResp` |
| **描述** | 更新当前用户信息（支持更多字段） |

### 2.4 用户注册

| 属性 | 值 |
|------|-----|
| **路由** | `/user/user_register` |
| **请求类型** | `user::UserRegisterReq` |
| **响应类型** | `user::UserRegisterResp` |
| **描述** | 新用户注册（首次登录时调用） |

### 2.5 获取用户客户端配置

| 属性 | 值 |
|------|-----|
| **路由** | `/user/get_user_client_config` |
| **请求类型** | `user::GetUserClientConfigReq` |
| **响应类型** | `user::GetUserClientConfigResp` |
| **描述** | 获取用户客户端配置（如全局消息接收选项） |

---

## 3. Friend/Relation 模块 (16 个路由)

### 3.1 申请添加好友

| 属性 | 值 |
|------|-----|
| **路由** | `/friend/add_friend` |
| **请求类型** | `relation::ApplyToAddFriendReq` |
| **响应类型** | `relation::ApplyToAddFriendResp` |
| **描述** | 向指定用户发送好友申请 |

### 3.2 删除好友

| 属性 | 值 |
|------|-----|
| **路由** | `/friend/delete_friend` |
| **请求类型** | `relation::DeleteFriendReq` |
| **响应类型** | `relation::DeleteFriendResp` |
| **描述** | 删除指定好友关系 |

### 3.3 获取收到的好友申请列表

| 属性 | 值 |
|------|-----|
| **路由** | `/friend/get_friend_apply_list` |
| **请求类型** | `relation::GetPaginationFriendsApplyToReq` |
| **响应类型** | `relation::GetPaginationFriendsApplyToResp` |
| **描述** | 分页获取别人发给自己的好友申请 |

### 3.4 获取自己发出的好友申请列表

| 属性 | 值 |
|------|-----|
| **路由** | `/friend/get_self_friend_apply_list` |
| **请求类型** | `relation::GetPaginationFriendsApplyFromReq` |
| **响应类型** | `relation::GetPaginationFriendsApplyFromResp` |
| **描述** | 分页获取自己发出的好友申请 |

### 3.5 获取好友列表

| 属性 | 值 |
|------|-----|
| **路由** | `/friend/get_friend_list` |
| **请求类型** | `relation::GetPaginationFriendsReq` |
| **响应类型** | `relation::GetPaginationFriendsResp` |
| **描述** | 分页获取好友列表 |

### 3.6 响应好友申请

| 属性 | 值 |
|------|-----|
| **路由** | `/friend/add_friend_response` |
| **请求类型** | `relation::RespondFriendApplyReq` |
| **响应类型** | `relation::RespondFriendApplyResp` |
| **描述** | 同意或拒绝好友申请 |

### 3.7 更新好友信息

| 属性 | 值 |
|------|-----|
| **路由** | `/friend/update_friends` |
| **请求类型** | `relation::UpdateFriendsReq` |
| **响应类型** | `relation::UpdateFriendsResp` |
| **描述** | 批量更新好友备注等信息 |

### 3.8 获取增量好友数据

| 属性 | 值 |
|------|-----|
| **路由** | `/friend/get_incremental_friends` |
| **请求类型** | `relation::GetIncrementalFriendsReq` |
| **响应类型** | `relation::GetIncrementalFriendsResp` |
| **描述** | 基于版本号获取好友增量变更（用于增量同步） |

### 3.9 获取全部好友用户 ID

| 属性 | 值 |
|------|-----|
| **路由** | `/friend/get_full_friend_user_ids` |
| **请求类型** | `relation::GetFullFriendUserIDsReq` |
| **响应类型** | `relation::GetFullFriendUserIDsResp` |
| **描述** | 获取所有好友的用户 ID 列表（用于全量同步） |

### 3.10 添加黑名单

| 属性 | 值 |
|------|-----|
| **路由** | `/friend/add_black` |
| **请求类型** | `relation::AddBlackReq` |
| **响应类型** | `relation::AddBlackResp` |
| **描述** | 将指定用户加入黑名单 |

### 3.11 移除黑名单

| 属性 | 值 |
|------|-----|
| **路由** | `/friend/remove_black` |
| **请求类型** | `relation::RemoveBlackReq` |
| **响应类型** | `relation::RemoveBlackResp` |
| **描述** | 将指定用户从黑名单中移除 |

### 3.12 获取黑名单列表

| 属性 | 值 |
|------|-----|
| **路由** | `/friend/get_black_list` |
| **请求类型** | `relation::GetPaginationBlacksReq` |
| **响应类型** | `relation::GetPaginationBlacksResp` |
| **描述** | 分页获取黑名单列表 |

### 3.13 获取指定好友信息

| 属性 | 值 |
|------|-----|
| **路由** | `/friend/get_designated_friends` |
| **请求类型** | `relation::GetDesignatedFriendsReq` |
| **响应类型** | `relation::GetDesignatedFriendsResp` |
| **描述** | 获取指定好友的详细信息 |

### 3.14 获取指定好友申请

| 属性 | 值 |
|------|-----|
| **路由** | `/friend/get_designated_friend_apply` |
| **请求类型** | `relation::GetDesignatedFriendsApplyReq` |
| **响应类型** | `relation::GetDesignatedFriendsApplyResp` |
| **描述** | 获取指定的好友申请记录 |

### 3.15 导入好友

| 属性 | 值 |
|------|-----|
| **路由** | `/friend/import_friend` |
| **请求类型** | `relation::ImportFriendReq` |
| **响应类型** | `relation::ImportFriendResp` |
| **描述** | 批量导入好友（用于客户端迁移等场景） |

### 3.16 获取未处理申请数

| 属性 | 值 |
|------|-----|
| **路由** | `/friend/get_self_unhandled_apply_count` |
| **请求类型** | `relation::GetSelfUnhandledApplyCountReq` |
| **响应类型** | `relation::GetSelfUnhandledApplyCountResp` |
| **描述** | 获取自己收到的未处理好友申请数量 |

---

## 4. Group 模块 (24 个路由)

### 4.1 创建群组

| 属性 | 值 |
|------|-----|
| **路由** | `/group/create_group` |
| **请求类型** | `group::CreateGroupReq` |
| **响应类型** | `group::CreateGroupResp` |
| **描述** | 创建新群组并邀请初始成员 |

### 4.2 设置群组信息（扩展）

| 属性 | 值 |
|------|-----|
| **路由** | `/group/set_group_info_ex` |
| **请求类型** | `group::SetGroupInfoExReq` |
| **响应类型** | `group::SetGroupInfoExResp` |
| **描述** | 更新群组信息（名称、公告、头像等） |

### 4.3 加入群组

| 属性 | 值 |
|------|-----|
| **路由** | `/group/join_group` |
| **请求类型** | `group::JoinGroupReq` |
| **响应类型** | `group::JoinGroupResp` |
| **描述** | 申请加入群组 |

### 4.4 退出群组

| 属性 | 值 |
|------|-----|
| **路由** | `/group/quit_group` |
| **请求类型** | `group::QuitGroupReq` |
| **响应类型** | `group::QuitGroupResp` |
| **描述** | 主动退出群组 |

### 4.5 获取群组信息

| 属性 | 值 |
|------|-----|
| **路由** | `/group/get_groups_info` |
| **请求类型** | `group::GetGroupsInfoReq` |
| **响应类型** | `group::GetGroupsInfoResp` |
| **描述** | 批量获取指定群组的信息 |

### 4.6 获取群组成员列表

| 属性 | 值 |
|------|-----|
| **路由** | `/group/get_group_member_list` |
| **请求类型** | `group::GetGroupMemberListReq` |
| **响应类型** | `group::GetGroupMemberListResp` |
| **描述** | 分页获取群组成员列表 |

### 4.7 获取指定群组成员信息

| 属性 | 值 |
|------|-----|
| **路由** | `/group/get_group_members_info` |
| **请求类型** | `group::GetGroupMembersInfoReq` |
| **响应类型** | `group::GetGroupMembersInfoResp` |
| **描述** | 获取指定群组成员的详细信息 |

### 4.8 邀请用户入群

| 属性 | 值 |
|------|-----|
| **路由** | `/group/invite_user_to_group` |
| **请求类型** | `group::InviteUserToGroupReq` |
| **响应类型** | `group::InviteUserToGroupResp` |
| **描述** | 邀请指定用户加入群组 |

### 4.9 获取已加入群组列表

| 属性 | 值 |
|------|-----|
| **路由** | `/group/get_joined_group_list` |
| **请求类型** | `group::GetJoinedGroupListReq` |
| **响应类型** | `group::GetJoinedGroupListResp` |
| **描述** | 分页获取当前用户已加入的群组列表 |

### 4.10 踢出群组成员

| 属性 | 值 |
|------|-----|
| **路由** | `/group/kick_group` |
| **请求类型** | `group::KickGroupMemberReq` |
| **响应类型** | `group::KickGroupMemberResp` |
| **描述** | 将指定成员踢出群组 |

### 4.11 转让群主

| 属性 | 值 |
|------|-----|
| **路由** | `/group/transfer_group` |
| **请求类型** | `group::TransferGroupOwnerReq` |
| **响应类型** | `group::TransferGroupOwnerResp` |
| **描述** | 将群主权限转让给其他成员 |

### 4.12 获取群组申请列表

| 属性 | 值 |
|------|-----|
| **路由** | `/group/get_recv_group_applicationList` |
| **请求类型** | `group::GetGroupApplicationListReq` |
| **响应类型** | `group::GetGroupApplicationListResp` |
| **描述** | 获取群组入群申请列表 |

### 4.13 获取自己发出的群组申请列表

| 属性 | 值 |
|------|-----|
| **路由** | `/group/get_user_req_group_applicationList` |
| **请求类型** | `group::GetUserReqApplicationListReq` |
| **响应类型** | `group::GetUserReqApplicationListResp` |
| **描述** | 获取自己发出的入群申请列表 |

### 4.14 获取未处理群组申请数

| 属性 | 值 |
|------|-----|
| **路由** | `/group/get_group_application_unhandled_count` |
| **请求类型** | `group::GetGroupApplicationUnhandledCountReq` |
| **响应类型** | `group::GetGroupApplicationUnhandledCountResp` |
| **描述** | 获取未处理的群组入群申请数量 |

### 4.15 响应群组申请

| 属性 | 值 |
|------|-----|
| **路由** | `/group/group_application_response` |
| **请求类型** | `group::GroupApplicationResponseReq` |
| **响应类型** | `group::GroupApplicationResponseResp` |
| **描述** | 同意或拒绝群组入群申请 |

### 4.16 解散群组

| 属性 | 值 |
|------|-----|
| **路由** | `/group/dismiss_group` |
| **请求类型** | `group::DismissGroupReq` |
| **响应类型** | `group::DismissGroupResp` |
| **描述** | 群主解散群组 |

### 4.17 禁言群组成员

| 属性 | 值 |
|------|-----|
| **路由** | `/group/mute_group_member` |
| **请求类型** | `group::MuteGroupMemberReq` |
| **响应类型** | `group::MuteGroupMemberResp` |
| **描述** | 禁言指定群组成员 |

### 4.18 取消禁言群组成员

| 属性 | 值 |
|------|-----|
| **路由** | `/group/cancel_mute_group_member` |
| **请求类型** | `group::CancelMuteGroupMemberReq` |
| **响应类型** | `group::CancelMuteGroupMemberResp` |
| **描述** | 取消禁言指定群组成员 |

### 4.19 全员禁言

| 属性 | 值 |
|------|-----|
| **路由** | `/group/mute_group` |
| **请求类型** | `group::MuteGroupReq` |
| **响应类型** | `group::MuteGroupResp` |
| **描述** | 对群组开启全员禁言 |

### 4.20 取消全员禁言

| 属性 | 值 |
|------|-----|
| **路由** | `/group/cancel_mute_group` |
| **请求类型** | `group::CancelMuteGroupReq` |
| **响应类型** | `group::CancelMuteGroupResp` |
| **描述** | 取消群组全员禁言 |

### 4.21 设置群组成员信息

| 属性 | 值 |
|------|-----|
| **路由** | `/group/set_group_member_info` |
| **请求类型** | `group::SetGroupMemberInfoReq` |
| **响应类型** | `group::SetGroupMemberInfoResp` |
| **描述** | 设置群组成员的昵称、头像等信息 |

### 4.22 获取增量已加入群组

| 属性 | 值 |
|------|-----|
| **路由** | `/group/get_incremental_join_groups` |
| **请求类型** | `group::GetIncrementalJoinGroupReq` |
| **响应类型** | `group::GetIncrementalJoinGroupResp` |
| **描述** | 基于版本号获取已加入群组的增量变更 |

### 4.23 批量获取增量群组成员

| 属性 | 值 |
|------|-----|
| **路由** | `/group/get_incremental_group_members_batch` |
| **请求类型** | `group::BatchGetIncrementalGroupMemberReq` |
| **响应类型** | `group::BatchGetIncrementalGroupMemberResp` |
| **描述** | 批量获取多个群组的成员增量变更 |

### 4.24 获取全部已加入群组 ID

| 属性 | 值 |
|------|-----|
| **路由** | `/group/get_full_join_group_ids` |
| **请求类型** | `group::GetFullJoinGroupIDsReq` |
| **响应类型** | `group::GetFullJoinGroupIDsResp` |
| **描述** | 获取所有已加入群组的 ID 列表 |

### 4.25 获取全部群组成员用户 ID

| 属性 | 值 |
|------|-----|
| **路由** | `/group/get_full_group_member_user_ids` |
| **请求类型** | `group::GetFullGroupMemberUserIDsReq` |
| **响应类型** | `group::GetFullGroupMemberUserIDsResp` |
| **描述** | 获取指定群组所有成员的用户 ID 列表 |

---

## 5. Conversation 模块 (7 个路由)

### 5.1 获取会话列表

| 属性 | 值 |
|------|-----|
| **路由** | `/conversation/get_conversations` |
| **请求类型** | `conversation::GetConversationsReq` |
| **响应类型** | `conversation::GetConversationsResp` |
| **描述** | 按会话 ID 列表获取会话信息 |

### 5.2 获取全部会话

| 属性 | 值 |
|------|-----|
| **路由** | `/conversation/get_all_conversations` |
| **请求类型** | `conversation::GetAllConversationsReq` |
| **响应类型** | `conversation::GetAllConversationsResp` |
| **描述** | 获取当前用户的所有会话 |

### 5.3 设置会话信息

| 属性 | 值 |
|------|-----|
| **路由** | `/conversation/set_conversations` |
| **请求类型** | `conversation::SetConversationsReq` |
| **响应类型** | `conversation::SetConversationsResp` |
| **描述** | 更新会话属性（置顶、免打扰等） |

### 5.4 获取增量会话

| 属性 | 值 |
|------|-----|
| **路由** | `/conversation/get_incremental_conversations` |
| **请求类型** | `conversation::GetIncrementalConversationReq` |
| **响应类型** | `conversation::GetIncrementalConversationResp` |
| **描述** | 基于版本号获取会话的增量变更 |

### 5.5 获取全部会话 ID

| 属性 | 值 |
|------|-----|
| **路由** | `/conversation/get_full_conversation_ids` |
| **请求类型** | `conversation::GetFullOwnerConversationIDsReq` |
| **响应类型** | `conversation::GetFullOwnerConversationIDsResp` |
| **描述** | 获取所有会话的 ID 列表 |

### 5.6 获取用户所属会话

| 属性 | 值 |
|------|-----|
| **路由** | `/conversation/get_owner_conversation` |
| **请求类型** | `conversation::GetOwnerConversationReq` |
| **响应类型** | `conversation::GetOwnerConversationResp` |
| **描述** | 获取指定用户拥有的会话列表 |

### 5.7 获取活跃会话

| 属性 | 值 |
|------|-----|
| **路由** | `/jssdk/get_active_conversations` |
| **请求类型** | `jssdk::GetActiveConversationsReq` |
| **响应类型** | `jssdk::GetActiveConversationsResp` |
| **描述** | 获取最近活跃的会话列表（分页） |

---

## 6. Msg 模块 (10 个路由)

### 6.1 发送消息

| 属性 | 值 |
|------|-----|
| **路由** | `/msg/send_msg` |
| **请求类型** | `msg::SendMsgReq` |
| **响应类型** | `msg::SendMsgResp` |
| **描述** | 发送消息（单聊/群聊/通知） |

### 6.2 获取服务器时间

| 属性 | 值 |
|------|-----|
| **路由** | `/msg/get_server_time` |
| **请求类型** | `msg::GetServerTimeReq` |
| **响应类型** | `msg::GetServerTimeResp` |
| **描述** | 获取服务器当前时间（用于时间校准） |

### 6.3 撤回消息

| 属性 | 值 |
|------|-----|
| **路由** | `/msg/revoke_msg` |
| **请求类型** | `msg::RevokeMsgReq` |
| **响应类型** | `msg::RevokeMsgResp` |
| **描述** | 撤回已发送的消息 |

### 6.4 标记消息已读

| 属性 | 值 |
|------|-----|
| **路由** | `/msg/mark_msgs_as_read` |
| **请求类型** | `msg::MarkMsgsAsReadReq` |
| **响应类型** | `msg::MarkMsgsAsReadResp` |
| **描述** | 标记指定消息为已读 |

### 6.5 标记会话已读

| 属性 | 值 |
|------|-----|
| **路由** | `/msg/mark_conversation_as_read` |
| **请求类型** | `msg::MarkConversationAsReadReq` |
| **响应类型** | `msg::MarkConversationAsReadResp` |
| **描述** | 标记整个会话为已读 |

### 6.6 设置会话已读序列号

| 属性 | 值 |
|------|-----|
| **路由** | `/msg/set_conversation_has_read_seq` |
| **请求类型** | `msg::SetConversationHasReadSeqReq` |
| **响应类型** | `msg::SetConversationHasReadSeqResp` |
| **描述** | 设置会话的已读序列号（用于同步已读状态） |

### 6.7 获取会话已读和最大序列号

| 属性 | 值 |
|------|-----|
| **路由** | `/msg/get_conversations_has_read_and_max_seq` |
| **请求类型** | `msg::GetConversationsHasReadAndMaxSeqReq` |
| **响应类型** | `msg::GetConversationsHasReadAndMaxSeqResp` |
| **描述** | 获取会话的已读序列号和最大序列号 |

### 6.8 清除会话消息

| 属性 | 值 |
|------|-----|
| **路由** | `/msg/clear_conversation_msg` |
| **请求类型** | `msg::ClearConversationsMsgReq` |
| **响应类型** | `msg::ClearConversationsMsgResp` |
| **描述** | 清除指定会话的所有消息 |

### 6.9 清除所有消息

| 属性 | 值 |
|------|-----|
| **路由** | `/msg/user_clear_all_msg` |
| **请求类型** | `msg::UserClearAllMsgReq` |
| **响应类型** | `msg::UserClearAllMsgResp` |
| **描述** | 清除当前用户所有会话的消息 |

### 6.10 删除消息

| 属性 | 值 |
|------|-----|
| **路由** | `/msg/delete_msgs` |
| **请求类型** | `msg::DeleteMsgsReq` |
| **响应类型** | `msg::DeleteMsgsResp` |
| **描述** | 删除指定消息（服务端同步删除） |

---

## 7. Third 模块 (3 个路由)

### 7.1 更新 FCM Token

| 属性 | 值 |
|------|-----|
| **路由** | `/third/fcm_update_token` |
| **请求类型** | `third::FcmUpdateTokenReq` |
| **响应类型** | `third::FcmUpdateTokenResp` |
| **描述** | 更新 Firebase Cloud Messaging Token（推送用） |

### 7.2 设置应用角标

| 属性 | 值 |
|------|-----|
| **路由** | `/third/set_app_badge` |
| **请求类型** | `third::SetAppBadgeReq` |
| **响应类型** | `third::SetAppBadgeResp` |
| **描述** | 设置应用未读角标数 |

### 7.3 上传日志

| 属性 | 值 |
|------|-----|
| **路由** | `/third/logs/upload` |
| **请求类型** | `third::UploadLogsReq` |
| **响应类型** | `third::UploadLogsResp` |
| **描述** | 上传客户端日志文件 |

---

## 8. Object/Storage 模块 (5 个路由)

### 8.1 获取分片大小限制

| 属性 | 值 |
|------|-----|
| **路由** | `/object/part_limit` |
| **请求类型** | `third::PartLimitReq` |
| **响应类型** | `third::PartLimitResp` |
| **描述** | 获取对象存储分片上传的大小限制 |

### 8.2 初始化分片上传

| 属性 | 值 |
|------|-----|
| **路由** | `/object/initiate_multipart_upload` |
| **请求类型** | `third::InitiateMultipartUploadReq` |
| **响应类型** | `third::InitiateMultipartUploadResp` |
| **描述** | 初始化分片上传任务，返回 uploadID |

### 8.3 获取上传签名

| 属性 | 值 |
|------|-----|
| **路由** | `/object/auth_sign` |
| **请求类型** | `third::AuthSignReq` |
| **响应类型** | `third::AuthSignResp` |
| **描述** | 获取分片上传的认证签名 |

### 8.4 完成分片上传

| 属性 | 值 |
|------|-----|
| **路由** | `/object/complete_multipart_upload` |
| **请求类型** | `third::CompleteMultipartUploadReq` |
| **响应类型** | `third::CompleteMultipartUploadResp` |
| **描述** | 完成分片上传，合并所有分片 |

### 8.5 获取访问 URL

| 属性 | 值 |
|------|-----|
| **路由** | `/object/access_url` |
| **请求类型** | `third::AccessURLReq` |
| **响应类型** | `third::AccessURLResp` |
| **描述** | 获取已上传文件的访问 URL |

---

## 路由汇总统计

| 模块 | 路由数 | 说明 |
|------|--------|------|
| Auth | 3 | 认证与 Token 管理 |
| User | 5 | 用户信息管理 |
| Friend/Relation | 16 | 好友关系管理 |
| Group | 25 | 群组管理（含成员、申请等） |
| Conversation | 7 | 会话管理 |
| Msg | 10 | 消息管理 |
| Third | 3 | 第三方服务（推送、日志） |
| Object/Storage | 5 | 对象存储（文件上传） |
| **合计** | **74** | - |

---

## Rust 实现建议

### 1. 路由常量定义

```rust
// rust/src/infra/http/routes.rs

pub struct AuthRoutes;
impl AuthRoutes {
    pub const PARSE_TOKEN: &'static str = "/auth/parse_token";
    pub const GET_ADMIN_TOKEN: &'static str = "/auth/get_admin_token";
    pub const GET_USER_TOKEN: &'static str = "/auth/get_user_token";
}

pub struct UserRoutes;
impl UserRoutes {
    pub const GET_USERS_INFO: &'static str = "/user/get_users_info";
    pub const UPDATE_USER_INFO: &'static str = "/user/update_user_info";
    pub const UPDATE_USER_INFO_EX: &'static str = "/user/update_user_info_ex";
    pub const USER_REGISTER: &'static str = "/user/user_register";
    pub const GET_USER_CLIENT_CONFIG: &'static str = "/user/get_user_client_config";
}

// ... 其他模块类似
```

### 2. HTTP 客户端封装

建议使用 `reqwest` 作为 HTTP 客户端，封装统一的请求方法：

```rust
pub struct HttpClient {
    base_url: String,
    token: RwLock<String>,
    client: reqwest::Client,
}

impl HttpClient {
    pub async fn post<Req, Resp>(&self, route: &str, req: &Req) -> Result<Resp>
    where
        Req: Serialize,
        Resp: DeserializeOwned,
    {
        let url = format!("{}{}", self.base_url, route);
        let token = self.token.read().await.clone();
        let resp = self.client
            .post(&url)
            .bearer_auth(&token)
            .json(req)
            .send()
            .await?
            .json::<Resp>()
            .await?;
        Ok(resp)
    }
}
```

### 3. 请求/响应类型

所有请求/响应类型应与 `../protocol` 中的 proto 生成的 Rust 结构体对齐。如果 proto 中尚未生成 Rust 代码，需要手动定义等价结构体并使用 `serde` 序列化。
