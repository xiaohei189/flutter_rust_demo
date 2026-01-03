//! 联系人（好友）模块
//!
//! 实现 OpenIM SDK 的好友同步功能

pub mod api;
pub mod listener;
pub mod service;
pub mod models;
pub mod types;

// 重新导出主要类型和函数
pub use api::FriendApi;
// FriendDao 迁移至 crate::im::dao::friend
pub use listener::{EmptyFriendListener, FriendListener};
pub use crate::im::model::friend::{
    AllFriendsResp, BlackList, FriendRequest, FriendRequestsResp, FriendSyncerConfig,
    IncrementalFriendsResp,
};
pub use service::FriendSyncer;

