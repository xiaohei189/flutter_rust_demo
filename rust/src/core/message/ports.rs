//! 消息子系统外部依赖契约（Ports）
//!
//! 本文件集中定义 message 模块的全部外部依赖 trait。
//! 打开此文件即可一览模块与外界的所有交互边界。
//!
//! # Adapter 对照
//!
//! | Trait | 生产 Adapter | 位置 |
//! |-------|-------------|------|
//! | [`SyncerRemoteApi`] | `ConnectionManager` | `receive/syncer.rs` |
//! | [`MessageServerApi`] | `HttpMessageApi` | `operate/http_api.rs` |

use crate::domain::error::Result;
use async_trait::async_trait;
use openim_protocol::sdkws::{PullMessageBySeqsReq, PullMessageBySeqsResp};
use std::collections::HashMap;

// ============================================================================
// 接收管道 — 同步器远程数据源
// ============================================================================

/// 消息同步器的远程数据源抽象
///
/// 生产环境由 `ConnectionManager` 实现（WebSocket RPC），
/// 测试中使用 mock 返回预设数据。
#[async_trait]
pub trait SyncerRemoteApi: Send + Sync {
    /// 获取服务端所有会话的最新 maxSeq
    async fn fetch_server_max_seqs(&self, user_id: &str) -> Result<HashMap<String, i64>>;

    /// 按 seq 范围拉取消息
    async fn pull_messages_by_seqs(&self, req: &PullMessageBySeqsReq) -> Result<PullMessageBySeqsResp>;

    /// 连接是否已被踢下线
    async fn is_kicked(&self) -> bool;
}

// ============================================================================
// 用户操作管道 — 服务端 HTTP API
// ============================================================================

/// 消息服务端 API 接口
///
/// 定义 MessageService 需要的所有远程操作。
/// 生产环境由 [`HttpMessageApi`](crate::core::message::operate::HttpMessageApi) 实现，测试中可用 mock 替代。
#[async_trait]
pub trait MessageServerApi: Send + Sync {
    /// 通知服务端撤回消息
    async fn revoke_on_server(&self, req: &super::operate::req::RevokeMessageReq) -> Result<()>;

    /// 通知服务端删除消息（按 seqs）
    async fn delete_on_server(&self, conversation_id: &str, seqs: &[i64], user_id: &str) -> Result<()>;

    /// 通知服务端标记会话已读
    async fn mark_conversation_as_read_on_server(&self, req: &super::operate::req::MarkConversationAsReadReq) -> Result<()>;

    /// 通知服务端按 seq 列表标记消息已读
    async fn mark_messages_as_read_on_server(&self, req: &super::operate::req::MarkMessagesAsReadReq) -> Result<()>;
}
