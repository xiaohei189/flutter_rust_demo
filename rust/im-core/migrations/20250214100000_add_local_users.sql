-- 与 Go 一致：local_users 表，存储本地用户信息（含当前登录用户）
-- 参考 openim-sdk-core/pkg/db/model_struct/data_model_struct.go LocalUser
CREATE TABLE IF NOT EXISTS local_users (
    user_id             TEXT PRIMARY KEY,
    name                TEXT NOT NULL DEFAULT '',
    face_url            TEXT NOT NULL DEFAULT '',
    create_time         INTEGER NOT NULL DEFAULT 0,
    app_manger_level    INTEGER NOT NULL DEFAULT 0,
    ex                  TEXT NOT NULL DEFAULT '',
    attached_info       TEXT NOT NULL DEFAULT '',
    global_recv_msg_opt INTEGER NOT NULL DEFAULT 0
);
