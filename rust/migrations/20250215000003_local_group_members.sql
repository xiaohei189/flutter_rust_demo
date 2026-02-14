CREATE TABLE IF NOT EXISTS local_group_members (
    group_id            TEXT NOT NULL,
    user_id             TEXT NOT NULL,
    nickname            TEXT NOT NULL DEFAULT '',
    user_group_face_url TEXT NOT NULL DEFAULT '',
    role_level          INTEGER NOT NULL DEFAULT 0,
    join_time           INTEGER NOT NULL DEFAULT 0,
    join_source         INTEGER NOT NULL DEFAULT 0,
    inviter_user_id     TEXT NOT NULL DEFAULT '',
    mute_end_time       INTEGER NOT NULL DEFAULT 0,
    operator_user_id    TEXT NOT NULL DEFAULT '',
    ex                  TEXT NOT NULL DEFAULT '',
    attached_info       TEXT NOT NULL DEFAULT '',
    PRIMARY KEY (group_id, user_id)
);
