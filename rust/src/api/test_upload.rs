//! 测试用文件上传 - 直接使用本地文件测试

use crate::api::bridge_client::get_current_client;
use flutter_rust_bridge::frb;

/// 测试上传文件（使用本地路径，不经过完整的上传流程）
/// 仅用于测试文件上传是否正常工作
#[frb]
pub async fn test_upload_file(file_path: String, file_name: String) -> Result<String, String> {
    use std::fs;
    use std::path::Path;

    // 检查文件是否存在
    if !Path::new(&file_path).exists() {
        return Err(format!("文件不存在: {}", file_path));
    }

    // 读取文件内容
    let data = fs::read(&file_path).map_err(|e| format!("读取文件失败: {}", e))?;
    tracing::info!("[test_upload] 文件大小: {} bytes", data.len());

    // 获取客户端并调用上传
    let client_arc = get_current_client().await.map_err(|e| e.to_string())?;
    let client = client_arc.read().await;

    // 调用实际的上传方法
    client.upload_file(&file_path, &file_name).await.map_err(|e| e.to_string())
}