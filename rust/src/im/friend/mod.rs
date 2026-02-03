//! 联系人（好友）模块
//!
//! 实现 OpenIM SDK 的好友同步功能

pub mod listener;
pub mod models;
pub mod service;
pub mod types;

// 重新导出主要类型和函数
pub use crate::im::api::friend::FriendApi;
// FriendDao 迁移至 crate::im::dao::friend
pub use crate::im::model::friend::{AllFriendsResp, BlackList, FriendRequest, FriendRequestsResp, FriendSyncerConfig, IncrementalFriendsResp};
pub use listener::{EmptyFriendListener, FriendListener};
pub use service::FriendSyncer;
