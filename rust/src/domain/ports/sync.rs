//! 接收管道 — 同步器远程数据源（Port）

use crate::domain::error::Result;
use async_trait::async_trait;
use openim_protocol::sdkws::{PullMessageBySeqsReq, PullMessageBySeqsResp};
use std::collections::HashMap;

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