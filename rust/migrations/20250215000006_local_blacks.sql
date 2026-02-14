-- 黑名单（与 Go local_blacks 一致）
CREATE TABLE IF NOT EXISTS local_blacks (
    owner_user_id    TEXT NOT NULL,
    block_user_id    TEXT NOT NULL,
    nickname         TEXT NOT NULL DEFAULT '',
    face_url         TEXT NOT NULL DEFAULT '',
    create_time      INTEGER NOT NULL DEFAULT 0,
    add_source       INTEGER NOT NULL DEFAULT 0,
    operator_user_id TEXT NOT NULL DEFAULT '',
    ex               TEXT NOT NULL DEFAULT '',
    attached_info    TEXT NOT NULL DEFAULT '',
    PRIMARY KEY (owner_user_id, block_user_id)
);
