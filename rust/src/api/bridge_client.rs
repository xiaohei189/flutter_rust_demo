use anyhow::Result;
use openim_sdk_core_rust::{ClientConfig, OpenIMClient};

/// OpenIM 客户端桥接器
/// 
/// 这是一个面向 Dart 的桥接客户端，通过 flutter_rust_bridge 暴露给 Flutter/Dart。
/// 内部封装了 OpenIMClient 核心逻辑，提供简洁的 API。
#[derive(Clone)]
pub struct OpenIMBridgeClient {
    inner: OpenIMClient,
}

impl OpenIMBridgeClient {
    /// 创建新的客户端实例
    /// 
    /// # 参数
    /// - `user_id`: 用户 ID
    /// - `token`: 认证 token（从登录接口获取）
    /// - `platform_id`: 平台 ID（例如：5 表示 Web）
    /// - `ws_url`: WebSocket 服务器 URL（可选，默认使用 localhost:10001）
    /// 
    /// # 返回
    /// 返回客户端实例
    #[flutter_rust_bridge::frb(sync)]
    pub fn new(
        user_id: String,
        token: String,
        platform_id: i32,
        ws_url: Option<String>,
    ) -> Self {
        let mut config = ClientConfig::new(user_id, token, platform_id);
        if let Some(url) = ws_url {
            config.ws_url = url;
        }
        
        Self {
            inner: OpenIMClient::new(config),
        }
    }

    /// 连接到服务器
    /// 
    /// 建立 WebSocket 连接并启动消息监听。
    /// 连接成功后会自动启动心跳和消息处理任务。
    pub async fn connect(&mut self) -> Result<()> {
        self.inner.connect().await
    }
}

/// 登录接口
/// 
/// 参考 openim-cli.rs 的实现，先登录获取 token 信息
pub async fn login_async(
    area_code: String,
    phone_number: String,
    password: String,
    platform: i32,
) -> Result<LoginResponse, String> {
    let resp = openim_sdk_core_rust::im::auth::login_async(area_code, phone_number, password, platform).await?;
    Ok(LoginResponse { inner: resp })
}

/// 登录响应包装类型（用于 Dart 访问字段）
#[derive(Debug)]
#[flutter_rust_bridge::frb(opaque)]
pub struct LoginResponse {
    inner: openim_sdk_core_rust::im::auth::LoginResponse,
}

impl LoginResponse {
    /// 获取错误代码
    #[flutter_rust_bridge::frb(sync)]
    pub fn err_code(&self) -> i32 {
        self.inner.err_code
    }

    /// 获取错误消息
    #[flutter_rust_bridge::frb(sync)]
    pub fn err_msg(&self) -> String {
        self.inner.err_msg.clone()
    }

    /// 获取用户 ID
    #[flutter_rust_bridge::frb(sync)]
    pub fn user_id(&self) -> Option<String> {
        self.inner.data.as_ref().map(|d| d.user_id.clone())
    }

    /// 获取 IM Token
    #[flutter_rust_bridge::frb(sync)]
    pub fn im_token(&self) -> Option<String> {
        self.inner.data.as_ref().map(|d| d.im_token.clone())
    }

    /// 获取 Chat Token
    #[flutter_rust_bridge::frb(sync)]
    pub fn chat_token(&self) -> Option<String> {
        self.inner.data.as_ref().map(|d| d.chat_token.clone())
    }
}

