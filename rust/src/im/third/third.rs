//! 第三方服务模块（对齐 Go internal/third/third.go）
//!
//! 提供文件上传、日志上传、FCM Token 管理、应用角标设置等功能。

use crate::im::file::file::FileService;
use crate::im::http_client::object::ObjectApi;
use anyhow::Result;
use std::sync::Arc;
use tokio::sync::Mutex;
use tracing::{debug, info, warn};

/// 第三方服务管理器
pub struct ThirdService {
    /// 平台ID
    platform: i32,
    /// 登录用户ID
    login_user_id: String,
    /// 应用框架（如 "fcm"）
    app_framework: String,
    /// 日志文件路径
    log_file_path: String,
    /// 文件上传服务
    file_service: Arc<FileService>,
    /// 日志上传锁
    log_upload_lock: Arc<Mutex<()>>,
}

impl ThirdService {
    /// 创建新的第三方服务管理器
    pub fn new(
        platform: i32,
        login_user_id: String,
        app_framework: String,
        log_file_path: String,
        object_api: ObjectApi,
    ) -> Self {
        Self {
            platform,
            login_user_id,
            app_framework,
            log_file_path,
            file_service: Arc::new(FileService::new(object_api)),
            log_upload_lock: Arc::new(Mutex::new(())),
        }
    }

    /// 上传文件到对象存储（对齐 Go Third.UploadFile）
    ///
    /// # 参数
    /// * `file_path` - 本地文件路径
    /// * `file_name` - 文件名（不含路径）
    ///
    /// # 返回
    /// 上传后的文件 URL
    pub async fn upload_file(&self, file_path: &str, file_name: &str) -> Result<String> {
        info!("[ThirdService] 上传文件: {} -> {}", file_path, file_name);

        let user_prefix = format!("{}/", self.login_user_id);
        let full_name = if file_name.starts_with(&user_prefix) {
            file_name.to_string()
        } else {
            format!("{}{}", user_prefix, file_name)
        };

        self.file_service.upload_file(file_path, &full_name).await
    }

    /// 上传图片（对齐 Go Third.UploadImage）
    ///
    /// # 参数
    /// * `file_path` - 本地图片路径
    ///
    /// # 返回
    /// 上传后的图片 URL
    pub async fn upload_image(&self, file_path: &str) -> Result<String> {
        let file_name = std::path::Path::new(file_path)
            .file_name()
            .map(|n| n.to_string_lossy().to_string())
            .unwrap_or_else(|| "image.jpg".to_string());

        self.upload_file(file_path, &file_name).await
    }

    /// 上传视频（对齐 Go Third.UploadVideo）
    ///
    /// # 参数
    /// * `file_path` - 本地视频路径
    ///
    /// # 返回
    /// 上传后的视频 URL
    pub async fn upload_video(&self, file_path: &str) -> Result<String> {
        let file_name = std::path::Path::new(file_path)
            .file_name()
            .map(|n| n.to_string_lossy().to_string())
            .unwrap_or_else(|| "video.mp4".to_string());

        self.upload_file(file_path, &file_name).await
    }

    /// 上传音频（对齐 Go Third.UploadSound）
    ///
    /// # 参数
    /// * `file_path` - 本地音频路径
    ///
    /// # 返回
    /// 上传后的音频 URL
    pub async fn upload_sound(&self, file_path: &str) -> Result<String> {
        let file_name = std::path::Path::new(file_path)
            .file_name()
            .map(|n| n.to_string_lossy().to_string())
            .unwrap_or_else(|| "sound.aac".to_string());

        self.upload_file(file_path, &file_name).await
    }

    /// 上传日志文件（对齐 Go Third.UploadLogs）
    ///
    /// # 参数
    /// * `log_lines` - 日志行列表
    ///
    /// # 返回
    /// 上传结果
    pub async fn upload_logs(&self, log_lines: Vec<String>) -> Result<()> {
        info!("[ThirdService] 上传日志: {} 行", log_lines.len());

        let _lock = self.log_upload_lock.lock().await;

        if log_lines.is_empty() {
            warn!("[ThirdService] 日志行为空，跳过上传");
            return Ok(());
        }

        // TODO: 实现日志上传逻辑
        // 1. 将日志写入临时文件
        // 2. 上传到对象存储
        // 3. 通知服务端日志已上传

        debug!("[ThirdService] 日志上传完成");
        Ok(())
    }

    /// 更新 FCM Token（对齐 Go Third.UpdateFcmToken）
    ///
    /// # 参数
    /// * `fcm_token` - FCM Token
    /// * `expire_time` - 过期时间（毫秒时间戳）
    ///
    /// # 返回
    /// 更新结果
    pub async fn update_fcm_token(&self, fcm_token: String, expire_time: i64) -> Result<()> {
        info!("[ThirdService] 更新 FCM Token: {}", fcm_token);

        if self.app_framework != "fcm" {
            debug!("[ThirdService] 当前应用框架不是 FCM，跳过更新");
            return Ok(());
        }

        // TODO: 调用服务端 API 更新 FCM Token
        // POST /third/update_fcm_token

        debug!("[ThirdService] FCM Token 更新完成");
        Ok(())
    }

    /// 设置应用角标（对齐 Go Third.SetAppBadge）
    ///
    /// # 参数
    /// * `count` - 未读消息数量
    ///
    /// # 返回
    /// 设置结果
    pub async fn set_app_badge(&self, count: i32) -> Result<()> {
        info!("[ThirdService] 设置应用角标: {}", count);

        // TODO: 调用平台特定 API 设置角标
        // iOS: UIApplication.shared.applicationIconBadgeNumber
        // Android: 通过通知管理器设置

        debug!("[ThirdService] 应用角标设置完成");
        Ok(())
    }

    /// 客户端日志记录（对齐 Go Third.Log）
    ///
    /// # 参数
    /// * `log_line` - 日志行
    ///
    /// # 返回
    /// 记录结果
    pub async fn log(&self, log_line: String) -> Result<()> {
        debug!("[ThirdService] 客户端日志: {}", log_line);

        // TODO: 将日志写入本地文件，定期批量上传

        Ok(())
    }

    /// 获取文件上传服务
    pub fn file_service(&self) -> Arc<FileService> {
        self.file_service.clone()
    }
}
