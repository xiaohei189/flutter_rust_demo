//! 会话子系统 - IM SDK 的会话管理核心
//!
//! # 整体职责
//!
//! 本模块负责会话的完整生命周期管理，包括：
//! - **本地管理**：CRUD、置顶、免打扰、未读数、草稿等
//! - **服务端同步**：增量同步、全量同步、Hash Read Seq 同步
//! - **模型转换**：Server / Domain / Local 三层模型互转
//!
//! # 数据流
//!
//! ```text
//! 同步: Server -> api(trait) -> syncer -> DB + Events
//! 管理: Client -> manager -> DB + Events
//! ```
//!
//! # 子模块
//!
//! | 模块 | 核心结构体 | 职责 |
//! |------|-----------|------|
//! | [`manager`] | `ConversationManager` | 本地 CRUD（置顶/免打扰/未读数/草稿） |
//! | [`syncer`] | `ConversationSyncer` | 服务端同步（增量/全量/HashReadSeq） |
//! | [`api`] | `ConversationServerApi` | HTTP 调用抽象 trait（便于测试 mock） |
//! | [`converter`] | - | Server/Domain/Local 三层模型互转 |
//! | [`types`] | - | 请求/响应 DTO 定义 |

pub mod manager;
pub mod syncer;
pub mod api;
pub mod converter;
pub mod types;
