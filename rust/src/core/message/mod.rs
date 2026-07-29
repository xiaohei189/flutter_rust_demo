//! 消息子系统 — IM SDK 的核心消息管道
//!
//! # 整体职责
//!
//! 本模块负责消息的完整生命周期管理，包括：
//! - **发送**：双 Lane 优先级队列，文本/命令消息高优先，媒体消息低优先
//! - **接收**：从 WebSocket 推送中解析、分类、入库、触发事件
//! - **同步**：登录后/重连后从服务端拉取缺失消息（seq 对齐）
//! - **操作**：用户主动发起的撤回、删除、标记已读等
//! - **校验**：消息列表 seq 连续性检查与缺失补拉（预留）
//!
//! # 数据流
//!
//! ```text
//! 发送: Client → send_queue → Connection → Server
//! 接收: Server → Connection → syncer → handler → DB + Events
//! 操作: Client → service → HTTP API + DB + Events
//! ```
//!
//! # 子模块
//!
//! | 模块 | 核心结构体 | 职责 |
//! |------|-----------|------|
//! | [`send_queue`] | `MessageSendQueue` | 双 Lane 消息发送队列（高优=文本，低优=媒体） |
//! | [`syncer`] | `MessageSyncer` | 服务端消息同步拉取（seq 对齐、增量 pull） |
//! | [`handler`] | `MessageHandler` | 接收消息分类入库 + 事件分发（撤回/已读/typing） |
//! | [`service`] | `MessageService` | 用户主动操作（撤回/删除/标记已读/搜索） |
//! | [`checker`] | `MessageChecker` | seq gap 三层连续性检查与补拉（预留） |
//! | [`content_type`] | `ContentTypeUtils` | content_type 统一命名/分类中心 |

pub mod syncer;
pub mod handler;
pub mod content_type;
pub mod service;
pub mod send_queue;
pub mod checker;
