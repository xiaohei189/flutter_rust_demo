//! HTTP 客户端与对外调用：登录、OpenIM API（会话/好友/群组/消息/用户/Token）统一入口

pub mod api;
pub mod auth;
pub mod client;
pub mod conversation;
pub mod friend;
pub mod group;
pub mod message;
pub mod middleware;
pub mod response_extractor;
pub mod routes;
pub mod token;
pub mod user;

pub use api::Api;
pub use auth::login_async;
pub use client::{make_client, make_client_without_token, HttpClient};
pub use response_extractor::extract_data;
