-- 上传记录（与 Go local_uploads 一致）
CREATE TABLE IF NOT EXISTS local_uploads (
    part_hash   TEXT PRIMARY KEY,
    upload_id   TEXT NOT NULL DEFAULT '',
    upload_info TEXT NOT NULL DEFAULT '',
    expire_time INTEGER NOT NULL DEFAULT 0,
    create_time INTEGER NOT NULL DEFAULT 0
);
