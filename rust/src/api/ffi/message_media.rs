//! 媒体消息相关 FFI 桥接
//!
//! 图片/文件/语音/视频消息发送（含上传进度回调、URL 直发）及文件上传
//! 所有操作委托给 OpenIMClient

use crate::domain::constant::SessionType;
use crate::api::ffi::client::OpenIMBridgeClient;
use crate::api::ffi::global::client_holder;
use crate::domain::model::msg_struct::MsgStruct;

use crate::frb_generated::StreamSink;
use anyhow::Result;
use std::sync::Arc;

impl OpenIMBridgeClient {
    // ========== 媒体消息发送 ==========

    #[flutter_rust_bridge::frb]
    pub async fn send_image_message(&self, file_path: String, source_id: String, session_type: SessionType) -> Result<MsgStruct> {
        self.inner
            .send_image_message(&file_path, &source_id, session_type.into())
            .await
            .map(|msg| msg.into())
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn send_file_message(&self, file_path: String, source_id: String, session_type: SessionType) -> Result<MsgStruct> {
        self.inner
            .send_file_message(&file_path, &source_id, session_type.into())
            .await
            .map(|msg| msg.into())
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn send_sound_message(&self, file_path: String, source_id: String, session_type: SessionType, duration: i64) -> Result<MsgStruct> {
        self.inner
            .send_sound_message(&file_path, &source_id, session_type.into(), duration)
            .await
            .map(|msg| msg.into())
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    #[flutter_rust_bridge::frb]
    pub async fn send_video_message(&self, video_path: String, snapshot_path: String, source_id: String, session_type: SessionType, duration: i64) -> Result<MsgStruct> {
        self.inner
            .send_video_message(&video_path, &snapshot_path, &source_id, session_type.into(), duration)
            .await
            .map(|msg| msg.into())
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    // ========== 带进度回调的媒体消息发送 ==========

    /// 发送图片消息（带上传进度回调）
    #[flutter_rust_bridge::frb]
    pub async fn send_image_message_with_progress(&self, file_path: String, source_id: String, session_type: SessionType, sink: StreamSink<i32>) -> Result<MsgStruct> {
        let progress: crate::infra::file::upload::ProgressCallback = Arc::new(move |pct: u8| {
            let _ = sink.add(pct as i32);
        });
        self.inner
            .send_image_message_with_progress(&file_path, &source_id, session_type.into(), &progress)
            .await
            .map(|msg| msg.into())
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    /// 发送文件消息（带上传进度回调）
    #[flutter_rust_bridge::frb]
    pub async fn send_file_message_with_progress(&self, file_path: String, source_id: String, session_type: SessionType, sink: StreamSink<i32>) -> Result<MsgStruct> {
        let progress: crate::infra::file::upload::ProgressCallback = Arc::new(move |pct: u8| {
            let _ = sink.add(pct as i32);
        });
        self.inner
            .send_file_message_with_progress(&file_path, &source_id, session_type.into(), &progress)
            .await
            .map(|msg| msg.into())
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    /// 发送语音消息（带上传进度回调）
    #[flutter_rust_bridge::frb]
    pub async fn send_sound_message_with_progress(&self, file_path: String, source_id: String, session_type: SessionType, duration: i64, sink: StreamSink<i32>) -> Result<MsgStruct> {
        let progress: crate::infra::file::upload::ProgressCallback = Arc::new(move |pct: u8| {
            let _ = sink.add(pct as i32);
        });
        self.inner
            .send_sound_message_with_progress(&file_path, &source_id, session_type.into(), duration, &progress)
            .await
            .map(|msg| msg.into())
            .map_err(|e| anyhow::anyhow!("{}", e))
    }

    /// 发送视频消息（带上传进度回调，进度跟踪主视频文件）
    #[flutter_rust_bridge::frb]
    pub async fn send_video_message_with_progress(
        &self,
        video_path: String,
        snapshot_path: String,
        source_id: String,
        session_type: SessionType,
        duration: i64,
        sink: StreamSink<i32>,
    ) -> Result<MsgStruct> {
        let progress: crate::infra::file::upload::ProgressCallback = Arc::new(move |pct: u8| {
            let _ = sink.add(pct as i32);
        });
        self.inner
            .send_video_message_with_progress(&video_path, &snapshot_path, &source_id, session_type.into(), duration, &progress)
            .await
            .map(|msg| msg.into())
            .map_err(|e| anyhow::anyhow!("{}", e))
    }
}

// ============================================================================
// 文件上传
// ============================================================================

#[flutter_rust_bridge::frb]
pub async fn upload_file(file_path: String, file_name: String) -> Result<String> {
    let client = client_holder()?;
    let url = client.upload_file(&file_path, &file_name).await?;
    Ok(url)
}

#[flutter_rust_bridge::frb]
pub async fn upload_file_with_progress(file_path: String, file_name: String, sink: StreamSink<i32>) -> Result<String> {
    let client = client_holder()?;
    let progress: crate::infra::file::upload::ProgressCallback = Arc::new(move |pct: u8| {
        let _ = sink.add(pct as i32);
    });
    let url = client.upload_file_with_progress(&file_path, &file_name, &progress).await?;
    Ok(url)
}

// ============================================================================
// 从 URL 创建并发送媒体消息
// ============================================================================

/// 从 URL 发送图片消息
#[flutter_rust_bridge::frb]
pub async fn send_image_message_from_url(source_url: String, source_id: String, session_type: SessionType) -> Result<MsgStruct> {
    let client = client_holder()?;
    let result = client.send_image_message_from_url(&source_url, &source_id, session_type.into()).await?;
    Ok(result.into())
}

/// 从 URL 发送语音消息
#[flutter_rust_bridge::frb]
pub async fn send_sound_message_from_url(source_url: String, duration: i64, source_id: String, session_type: SessionType) -> Result<MsgStruct> {
    let client = client_holder()?;
    let result = client.send_sound_message_from_url(&source_url, duration, &source_id, session_type.into()).await?;
    Ok(result.into())
}

/// 从 URL 发送视频消息
#[flutter_rust_bridge::frb]
pub async fn send_video_message_from_url(source_url: String, duration: i64, snapshot_url: String, source_id: String, session_type: SessionType) -> Result<MsgStruct> {
    let client = client_holder()?;
    let result = client.send_video_message_from_url(&source_url, duration, &snapshot_url, &source_id, session_type.into()).await?;
    Ok(result.into())
}

/// 从 URL 发送文件消息
#[flutter_rust_bridge::frb]
pub async fn send_file_message_from_url(source_url: String, file_name: String, file_size: i64, source_id: String, session_type: SessionType) -> Result<MsgStruct> {
    let client = client_holder()?;
    let result = client.send_file_message_from_url(&source_url, &file_name, file_size, &source_id, session_type.into()).await?;
    Ok(result.into())
}
