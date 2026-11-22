CREATE TABLE IF NOT EXISTS local_sending_messages (
    conversation_id TEXT NOT NULL,
    client_msg_id   TEXT NOT NULL,
    ex              TEXT NOT NULL DEFAULT '',
    PRIMARY KEY (conversation_id, client_msg_id)
);
