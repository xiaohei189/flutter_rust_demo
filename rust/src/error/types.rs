use thiserror::Error;

#[derive(Debug, Error)]
pub enum SdkError {
    #[error("网络错误: {message}")]
    NetworkError { message: String },

    #[error("连接错误: {message}")]
    ConnectionError { message: String },

    #[error("HTTP 错误: status={status}, message={message}")]
    HttpError { status: u16, message: String },

    #[error("API 错误: code={code}, message={message}")]
    ApiError { code: i32, message: String },

    #[error("Protobuf 解析错误: {source}")]
    ProtobufError {
        #[from]
        source: prost::DecodeError,
    },

    #[error("JSON 序列化错误: {source}")]
    JsonError {
        #[from]
        source: serde_json::Error,
    },

    #[error("超时: {message}")]
    Timeout { message: String },

    #[error("消息发送失败: {message}")]
    MessageSendFailed { message: String },

    #[error("消息重复: {message}")]
    MsgRepeated { message: String },

    #[error("鉴权失败: {message}")]
    AuthFailed { message: String },

    #[error("被踢下线: {reason}")]
    KickedOffline { reason: String },

    #[error("无效参数: {message}")]
    InvalidArgument { message: String },

    #[error("数据库错误: {message}")]
    DatabaseError { message: String },

    #[error("缓存错误: {message}")]
    CacheError { message: String },

    #[error("文件上传失败: {message}")]
    FileUploadError { message: String },

    #[error("未知错误: {message}")]
    Unknown { message: String },
}

impl SdkError {
    pub fn is_fatal(&self) -> bool {
        matches!(self, SdkError::AuthFailed { .. } | SdkError::KickedOffline { .. })
    }

    pub fn is_retryable(&self) -> bool {
        matches!(
            self,
            SdkError::NetworkError { .. } | SdkError::ConnectionError { .. } | SdkError::Timeout { .. } | SdkError::HttpError { .. }
        )
    }

    pub fn network(message: impl Into<String>) -> Self {
        SdkError::NetworkError { message: message.into() }
    }

    pub fn connection(message: impl Into<String>) -> Self {
        SdkError::ConnectionError { message: message.into() }
    }

    pub fn http(status: u16, message: impl Into<String>) -> Self {
        SdkError::HttpError { status, message: message.into() }
    }

    pub fn api(code: i32, message: impl Into<String>) -> Self {
        SdkError::ApiError { code, message: message.into() }
    }

    pub fn timeout(message: impl Into<String>) -> Self {
        SdkError::Timeout { message: message.into() }
    }

    pub fn message_send(message: impl Into<String>) -> Self {
        SdkError::MessageSendFailed { message: message.into() }
    }

    pub fn msg_repeated(message: impl Into<String>) -> Self {
        SdkError::MsgRepeated { message: message.into() }
    }

    pub fn auth_failed(message: impl Into<String>) -> Self {
        SdkError::AuthFailed { message: message.into() }
    }

    pub fn kicked(reason: impl Into<String>) -> Self {
        SdkError::KickedOffline { reason: reason.into() }
    }

    pub fn invalid_argument(message: impl Into<String>) -> Self {
        SdkError::InvalidArgument { message: message.into() }
    }

    pub fn database(message: impl Into<String>) -> Self {
        SdkError::DatabaseError { message: message.into() }
    }

    pub fn cache(message: impl Into<String>) -> Self {
        SdkError::CacheError { message: message.into() }
    }

    pub fn file_upload(message: impl Into<String>) -> Self {
        SdkError::FileUploadError { message: message.into() }
    }

    pub fn unknown(message: impl Into<String>) -> Self {
        SdkError::Unknown { message: message.into() }
    }
}

impl From<anyhow::Error> for SdkError {
    fn from(err: anyhow::Error) -> Self {
        SdkError::Unknown { message: err.to_string() }
    }
}

impl From<tokio::time::error::Elapsed> for SdkError {
    fn from(_: tokio::time::error::Elapsed) -> Self {
        SdkError::Timeout { message: "操作超时".into() }
    }
}

impl From<reqwest::Error> for SdkError {
    fn from(err: reqwest::Error) -> Self {
        if err.is_timeout() {
            SdkError::Timeout { message: "HTTP 请求超时".into() }
        } else if err.is_connect() {
            SdkError::NetworkError {
                message: format!("网络连接失败: {}", err),
            }
        } else {
            SdkError::HttpError {
                status: err.status().map(|s| s.as_u16()).unwrap_or(0),
                message: err.to_string(),
            }
        }
    }
}

// impl From<sqlx::Error> for SdkError {
//     fn from(err: sqlx::Error) -> Self {
//         SdkError::DatabaseError {
//             message: err.to_string(),
//         }
//     }
// }

pub type Result<T> = std::result::Result<T, SdkError>;

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_is_fatal() {
        let auth_error = SdkError::auth_failed("token expired");
        assert!(auth_error.is_fatal());

        let kicked_error = SdkError::kicked("kicked by other device");
        assert!(kicked_error.is_fatal());

        let network_error = SdkError::network("connection refused");
        assert!(!network_error.is_fatal());
    }

    #[test]
    fn test_is_retryable() {
        let network_error = SdkError::network("connection refused");
        assert!(network_error.is_retryable());

        let timeout_error = SdkError::timeout("operation timeout");
        assert!(timeout_error.is_retryable());

        let auth_error = SdkError::auth_failed("token expired");
        assert!(!auth_error.is_retryable());
    }

    #[test]
    fn test_error_display() {
        let error = SdkError::api(10001, "user not found");
        assert_eq!(format!("{}", error), "API 错误: code=10001, message=user not found");
    }
}
