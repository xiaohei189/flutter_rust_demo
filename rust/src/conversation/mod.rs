//! 会话子系统 - IM SDK 的会话管理核心
//!
//! # 整体职责
//!
//! 本模块负责会话的完整生命周期管理，包括：
//! - **本地管理**：CRUD、置顶、免打扰、未读数、草稿等
//! - **服务端同步**：增量同步、全量同步、Hash Read Seq 同步
//! - **模型转换**：Server -> Local 一步转换（对齐 Go SDK `ServerConversationToLocal`）
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
//! | [`service`] | `ConversationService` | 本地 CRUD（置顶/免打扰/未读数/草稿） |
//! | [`syncer`] | `ConversationSyncer` | 服务端同步（增量/全量/HashReadSeq） |
//! | (ports) | `ConversationServerApi` | 服务端 API 契约（位于 `domain::ports::conversation`） |
//! | [`converter`] | - | ServerConversation -> LocalConversation 转换（`From` trait） |
//! | [`types`] | - | 请求/响应 DTO 定义 |

pub mod converter;
pub mod service;
pub mod syncer;
