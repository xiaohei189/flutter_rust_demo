//! 文件上传 API - 通过 IMClient 上传

use crate::api::bridge_client::get_current_client;
use flutter_rust_bridge::frb;
use std::sync::Arc;
use tokio::sync::RwLock;
use crate::im::client::client::IMClient;

/// 上传文件
///
/// # 参数
/// - `file_path`: 文件路径
/// - `file_name`: 文件名
///
/// # 返回值
/// - 成功: 返回文件的 URL
/// - 失败: 返回错误信息
#[frb]
pub async fn upload_file(file_path: String, file_name: String) -> Result<String, String> {
    let client_arc: Arc<RwLock<IMClient>> = get_current_client().await.map_err(|e| e.to_string())?;
    let client = client_arc.read().await;
    client.upload_file(&file_path, &file_name).await.map_err(|e| e.to_string())
}

/// 上传文件并返回进度
///
/// # 参数
/// - `file_path`: 文件路径
/// - `file_name`: 文件名
///
/// # 返回值
/// - 成功: 返回文件的 URL
/// - 失败: 返回错误信息
#[frb]
pub async fn upload_file_with_progress(file_path: String, file_name: String) -> Result<String, String> {
    upload_file(file_path, file_name).await
}