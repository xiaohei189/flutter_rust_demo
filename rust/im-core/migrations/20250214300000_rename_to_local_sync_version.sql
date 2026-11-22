-- 与 Go 一致：表名 local_sync_version（Go model_struct.LocalVersionSync TableName）
-- 列与 Go 对齐：table_name, entity_id, version, version_id
CREATE TABLE IF NOT EXISTS local_sync_version (
    table_name TEXT NOT NULL,
    entity_id  TEXT NOT NULL,
    version    INTEGER NOT NULL DEFAULT 0,
    version_id TEXT NOT NULL DEFAULT '',
    PRIMARY KEY (table_name, entity_id)
);
