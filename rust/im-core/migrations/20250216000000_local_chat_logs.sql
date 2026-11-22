-- 单表存储所有会话消息，与 Go LocalChatLog 列一致，主键 (conversation_id, client_msg_id)
CREATE TABLE IF NOT EXISTS local_chat_logs (
    conversation_id     TEXT NOT NULL,
    client_msg_id       TEXT NOT NULL,
    server_msg_id       TEXT NOT NULL DEFAULT '',
    send_id             TEXT NOT NULL DEFAULT '',
    recv_id             TEXT NOT NULL DEFAULT '',
    sender_platform_id  INTEGER NOT NULL DEFAULT 0,
    sender_nick_name     TEXT NOT NULL DEFAULT '',
    sender_face_url     TEXT NOT NULL DEFAULT '',
    session_type        INTEGER NOT NULL DEFAULT 0,
    msg_from            INTEGER NOT NULL DEFAULT 0,
    content_type        INTEGER NOT NULL DEFAULT 0,
    content             TEXT NOT NULL DEFAULT '',
    is_read             INTEGER NOT NULL DEFAULT 0,
    status              INTEGER NOT NULL DEFAULT 0,
    seq                 INTEGER NOT NULL DEFAULT 0,
    send_time           INTEGER NOT NULL DEFAULT 0,
    create_time         INTEGER NOT NULL DEFAULT 0,
    attached_info       TEXT NOT NULL DEFAULT '',
    ex                  TEXT NOT NULL DEFAULT '',
    local_ex            TEXT NOT NULL DEFAULT '',
    group_id            TEXT NOT NULL DEFAULT '',
    PRIMARY KEY (conversation_id, client_msg_id)
);
CREATE INDEX IF NOT EXISTS idx_local_chat_logs_conv_seq ON local_chat_logs(conversation_id, seq);
CREATE INDEX IF NOT EXISTS idx_local_chat_logs_conv_send_time ON local_chat_logs(conversation_id, send_time);
CREATE INDEX IF NOT EXISTS idx_local_chat_logs_conv_content_type ON local_chat_logs(conversation_id, content_type);
