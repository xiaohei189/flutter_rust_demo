do_msg_new 的分类依据（insert/update/self/others）主要看消息来源、自发/他发、seq 是否已落库，以及是否是历史/会话更新开关：
去重：先用 is_duplicate_message 按 client_msg_id 过滤重复。
按会话聚合：遍历 push 的 msgs/notification_msgs，按 conversation_id 收集。
分类循环内的判断：
is_history：options["history"]，历史补拉。
is_unread_count：options["unreadCount"]，是否计入未读。
is_conversation_update：options["conversationUpdate"]，是否需要更新/创建会话摘要。
is_sender_conversation_update：options["senderConversationUpdate"]，发送端是否也更新会话。
删除：status == MSG_STATUS_HAS_DELETED，直接转成 db 模型推入 insert_message（等价覆盖为删除状态），继续下一条。
自发/他发：is_from_me = (msg.send_id == self.config.user_id)，分两套逻辑。
自发：
若库里已存在且 seq == 0（本地占位未落服务端 seq），判定为需要更新：放入 update_message；若非会话更新则把状态设为 FILTERED。
若库里不存在或已有 seq，按常规新增放入 insert_message。
若 is_history，额外放入 self_insert_message（历史补拉）。
会话更新：is_conversation_update 且 is_sender_conversation_update 时，把新会话放入 conversation_set，并把 msg_struct 推入 new_messages 用于通知监听。
他发：
若库里已有同 client_msg_id，直接按收到的内容覆盖插入（insert_message）。
若库里没有：
组装 LocalConversation（单聊填 user_id，群聊填 group_id，通知类型填 send_id）。
若 is_unread_count 为真，未读数置 1。
若 is_conversation_update，把会话放入 conversation_set，并把 msg_struct 推入 new_messages。
若 is_history，放入 others_insert_message（历史补拉）。
汇总：
all_insert = insert_message + self_insert_message + others_insert_message → insert_msg（按会话批量插入）。
update_msg → 逐条调用 update_message。
new_messages → 序列化后异步回调 on_recv_new_message。
conversation_set（会话更新）用于上层会话变更逻辑（此文件内只收集）。
简而言之：删除直接写库；自发消息看是否已有占位、是否历史；他发消息看库内是否存在、是否历史；会话更新通过 options 触发；未读计数也来自 options；insert/update 的分界线在“是否已有记录且 seq==0”与“是否需要覆盖/新增”。