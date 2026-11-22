ALTER TABLE local_chat_logs ADD COLUMN topic_id TEXT NOT NULL DEFAULT '';

CREATE INDEX IF NOT EXISTS idx_local_chat_logs_conv_topic_seq
    ON local_chat_logs(conversation_id, topic_id, seq);
