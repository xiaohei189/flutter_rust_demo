-- 消息表情回应扩展（与 Go LocalChatLogReactionExtensions 一致）
CREATE TABLE IF NOT EXISTS local_chat_log_reaction_extensions (
    client_msg_id             TEXT PRIMARY KEY,
    local_reaction_extensions  BLOB
);
