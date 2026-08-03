-- 添加 sync_flag 字段到 local_app_sdk_version，用于追踪重装多阶段同步状态
-- 参考 Go SDK pkg/db/model_struct/data_model_struct.go LocalAppSDKVersion
-- sync_flag: 0=未同步(NO_SYNC), 1=同步中(SYNC_START), 2=同步完成(SYNC_END)
ALTER TABLE local_app_sdk_version ADD COLUMN sync_flag INTEGER NOT NULL DEFAULT 0;
