use serde::{Deserialize, Serialize};

/// 客户端配置
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct ClientConfig {
    /// 用户 ID
    pub user_id: String,
    /// 认证 token
    pub token: String,
    /// 平台 ID (1: iOS, 2: Android, 3: Windows, 4: macOS, 5: Web, 6: MiniProgram, 7: Linux)
    pub platform_id: i32,
    /// WebSocket 地址
    pub ws_url: Option<String>,
    /// API 基础 URL
    pub api_base_url: String,
    /// 文件上传 URL
    pub upload_url: Option<String>,
    /// 数据存储目录
    pub data_dir: String,
}

impl ClientConfig {
    pub fn new(user_id: String, token: String, platform_id: i32, ws_url: Option<String>, api_base_url: Option<String>, data_dir: Option<String>) -> Self {
        Self {
            user_id,
            token,
            platform_id,
            ws_url,
            api_base_url: api_base_url.unwrap_or_default(),
            upload_url: None,
            data_dir: data_dir.unwrap_or_else(|| "./data".to_string()),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_client_config_new() {
        let config = ClientConfig::new(
            "user_123".to_string(),
            "token_abc".to_string(),
            5,
            Some("wss://example.com/ws".to_string()),
            Some("https://api.example.com".to_string()),
            Some("./test_data".to_string()),
        );

        assert_eq!(config.user_id, "user_123");
        assert_eq!(config.token, "token_abc");
        assert_eq!(config.platform_id, 5);
        assert_eq!(config.ws_url, Some("wss://example.com/ws".to_string()));
        assert_eq!(config.api_base_url, "https://api.example.com");
        assert_eq!(config.data_dir, "./test_data");
    }

    #[test]
    fn test_client_config_default_api_base() {
        let config = ClientConfig::new("user_123".to_string(), "token_abc".to_string(), 5, None, None, None);

        assert_eq!(config.api_base_url, "");
        assert!(config.ws_url.is_none());
        assert!(config.upload_url.is_none());
        assert_eq!(config.data_dir, "./data");
    }

    #[test]
    fn test_client_config_serialize_deserialize() {
        let config = ClientConfig::new(
            "user_123".to_string(),
            "token_abc".to_string(),
            5,
            Some("wss://example.com/ws".to_string()),
            Some("https://api.example.com".to_string()),
            Some("./test_data".to_string()),
        );

        let json = serde_json::to_string(&config).unwrap();
        let deserialized: ClientConfig = serde_json::from_str(&json).unwrap();

        assert_eq!(deserialized.user_id, config.user_id);
        assert_eq!(deserialized.token, config.token);
        assert_eq!(deserialized.platform_id, config.platform_id);
        assert_eq!(deserialized.ws_url, config.ws_url);
        assert_eq!(deserialized.api_base_url, config.api_base_url);
        assert_eq!(deserialized.data_dir, config.data_dir);
    }
}
