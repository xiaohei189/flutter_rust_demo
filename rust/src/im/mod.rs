pub mod types;
pub mod serialization;
pub mod auth;
pub mod client;
pub mod msg;

// 重新导出认证相关函数（供 api 模块使用）
pub use auth::{login, login_async};

