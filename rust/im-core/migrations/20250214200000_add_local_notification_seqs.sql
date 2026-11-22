-- 与 Go 一致：local_notification_seqs 表，存储各会话通知消息已同步到的 seq
-- 参考 openim-sdk-core/pkg/db/model_struct/data_model_struct.go NotificationSeqs
CREATE TABLE IF NOT EXISTS local_notification_seqs (
    conversation_id TEXT PRIMARY KEY,
    seq             INTEGER NOT NULL DEFAULT 0
);
