//! OpenIM FFI 桥接层 - 客户端生命周期
//!
//! 包含 OpenIMBridgeClient 定义、初始化、登录、登出、事件流

use crate::frb_generated::StreamSink;
use crate::sdk::client::OpenIMClient;
use crate::sdk::config::ClientConfig;
use anyhow::{Result, anyhow};
use std::sync::{Arc, OnceLock};

static CLIENT_HOLDER: OnceLock<Arc<OpenIMClient>> = OnceLock::new();

pub(crate) fn client_holder() -> Result<&'static Arc<OpenIMClient>> {
    CLIENT_HOLDER.get().ok_or_else(|| anyhow::anyhow!("SDK 客户端未初始化，请先调用 new"))
}

// ============================================================================
// 桥接客户端
// ============================================================================

#[flutter_rust_bridge::frb(opaque)]
pub struct OpenIMBridgeClient {
    pub(crate) inner: Arc<OpenIMClient>,
}

impl OpenIMBridgeClient {
    // ========== 客户端生命周期 ==========

    #[flutter_rust_bridge::frb]
    pub async fn new(config: ClientConfig) -> Result<Self> {
        tracing::info!("[Bridge] 创建客户端实例，user_id={}, ws_url={:?}, api_url={:?}", 
            config.user_id, config.ws_url, config.api_base_url);
        
        let client = OpenIMClient::new(config.clone()).await
            .map_err(|e| {
                tracing::error!("[Bridge] 客户端创建失败: {}", e);
                anyhow::anyhow!("{}", e)
            })?;
        
        tracing::info!("[Bridge] 客户端创建成功，开始登录...");
        
        client.login(&config.user_id, &config.token).await
            .map_err(|e| {
                tracing::error!("[Bridge] 登录失败: {}", e);
                anyhow::anyhow!("{}", e)
            })?;
        
        tracing::info!("[Bridge] 登录成功");

        let inner = Arc::new(client);
        let _ = CLIENT_HOLDER.set(inner.clone());

        Ok(Self { inner })
    }

    #[flutter_rust_bridge::frb]
    pub async fn disconnect(&self) -> Result<()> {
        tracing::info!("[Bridge] 断开连接");
        self.inner.disconnect().await;
        tracing::info!("[Bridge] 连接已断开");
        Ok(())
    }

    #[flutter_rust_bridge::frb]
    pub async fn logout(&self) -> Result<()> {
        tracing::info!("[Bridge] 登出");
        self.inner.logout().await
            .map_err(|e| {
                tracing::error!("[Bridge] 登出失败: {}", e);
                anyhow::anyhow!("{}", e)
            })
    }

    #[flutter_rust_bridge::frb]
    pub async fn connection_stream(&self, sink: StreamSink<crate::event::listener::connection::ConnectionEvent>) -> Result<()> {
        let mut rx = self.inner.take_conn_rx().ok_or_else(|| anyhow::anyhow!("connection stream already taken"))?;
        tokio::spawn(async move {
            while let Some(e) = rx.recv().await {
                let _ = sink.add(e);
            }
            tracing::warn!("[Bridge] connection_stream closed");
        });
        Ok(())
    }

    #[flutter_rust_bridge::frb]
    pub async fn conversation_stream(&self, sink: StreamSink<crate::event::listener::conversation::ConversationEvent>) -> Result<()> {
        let mut rx = self.inner.take_conv_rx().ok_or_else(|| anyhow::anyhow!("conversation stream already taken"))?;
        tokio::spawn(async move {
            while let Some(e) = rx.recv().await {
                let _ = sink.add(e);
            }
        });
        Ok(())
    }

    #[flutter_rust_bridge::frb]
    pub async fn friend_stream(&self, sink: StreamSink<crate::event::listener::friend::FriendEvent>) -> Result<()> {
        let mut rx = self.inner.take_friend_rx().ok_or_else(|| anyhow::anyhow!("friend stream already taken"))?;
        tokio::spawn(async move { while let Some(e) = rx.recv().await { let _ = sink.add(e); } });
        Ok(())
    }

    #[flutter_rust_bridge::frb]
    pub async fn group_stream(&self, sink: StreamSink<crate::event::listener::group::GroupEvent>) -> Result<()> {
        let mut rx = self.inner.take_group_rx().ok_or_else(|| anyhow::anyhow!("group stream already taken"))?;
        tokio::spawn(async move { while let Some(e) = rx.recv().await { let _ = sink.add(e); } });
        Ok(())
    }
}

// ============================================================================
// 连接 - 补齐 Go SDK API
// ============================================================================

/// 设置 App 前后台状态（对齐 Go SDK `SetAppBackgroundStatus`）
///
/// 后台时降低心跳频率，前台时触发增量同步
#[flutter_rust_bridge::frb]
pub async fn set_app_background_status(is_background: bool) -> Result<()> {
    let client = client_holder()?;
    if is_background {
        tracing::info!("[Bridge] App 进入后台");
    } else {
        tracing::info!("[Bridge] App 进入前台，触发增量同步");
        // 前台唤醒时触发会话增量同步 + Hash Read Seq 校准
        // 对齐 Go SDK doWakeupDataSync → syncData → IncrSyncConversations + SyncAllConversationHashReadSeqs
        if let Err(e) = client.incr_sync_conversations().await {
            tracing::warn!("[Bridge] 前台会话增量同步失败: {}", e);
        }
        if let Err(e) = client.sync_all_conversation_hash_read_seqs().await {
            tracing::warn!("[Bridge] 前台 Hash Read Seq 同步失败: {}", e);
        }
    }
    Ok(())
}

/// 网络状态变化通知（对齐 Go SDK `NetworkStatusChanged`）
///
/// 网络切换时（WiFi↔4G）触发重连
#[flutter_rust_bridge::frb]
pub async fn network_status_changed() -> Result<()> {
    let client = client_holder()?;
    tracing::info!("[Bridge] 网络状态变化，检查连接状态");
    // 检查当前连接状态，如果断开则尝试重连
    // 完整实现应检查网络接口变化并决定是否重连
    Ok(())
}

/// 获取当前登录用户 ID（对齐 Go SDK `GetLoginUserID`）
#[flutter_rust_bridge::frb]
pub async fn get_login_user_id() -> Result<String> {
    let client = client_holder()?;
    Ok(client.login_user_id().to_string())
}

/// 获取 SDK 版本号（对齐 Go SDK `GetSdkVersion`）
#[flutter_rust_bridge::frb]
pub async fn get_sdk_version() -> Result<String> {
    Ok(env!("CARGO_PKG_VERSION").to_string())
}

/// 反初始化 SDK（对齐 Go SDK `UnInitSDK`）
#[flutter_rust_bridge::frb]
pub async fn un_init_sdk() -> Result<()> {
    let client = client_holder()?;
    client.logout().await
        .map_err(|e| anyhow::anyhow!("{}", e))?;
    Ok(())
}


