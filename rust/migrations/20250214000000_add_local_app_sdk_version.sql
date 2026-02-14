-- 与 Go 一致：local_app_sdk_version 表，用于记录 SDK 版本及是否已完成重装同步
-- 参考 openim-sdk-core/pkg/db/model_struct/data_model_struct.go LocalAppSDKVersion
CREATE TABLE IF NOT EXISTS local_app_sdk_version (
    version   TEXT PRIMARY KEY,
    installed INTEGER NOT NULL DEFAULT 0
);
