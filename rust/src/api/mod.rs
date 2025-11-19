pub mod types;
pub mod serialization;
pub mod auth;
pub mod client;
pub mod simple;

// 重新导出主要类型
pub use client::{OpenIMClient, ClientConfig};
pub use auth::{login, login_async};
