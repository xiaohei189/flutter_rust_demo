//! 接收管道 — 同步器远程数据源（Port）

use crate::error::Result;
use async_trait::async_trait;
use openim_protocol::msg::{GetSeqMessageReq, GetSeqMessageResp};
use openim_protocol::sdkws::{PullMessageBySeqsReq, PullMessageBySeqsResp};
use openim_protocol::sdkws::MsgData;
use std::collections::HashMap;

/// 消息同步器的远程数据源抽象
///
/// 生产环境由 ConnectionManager 实现（WebSocket RPC），
/// 测试中使用 mock 返回预设数据。
#[async_trait]
pub trait SyncServerApi: Send + Sync {
    /// 获取服务端所有会话的最新 maxSeq
    async fn fetch_server_max_seqs(&self, user_id: &str) -> Result<HashMap<String, i64>>;

    /// 按 seq 范围拉取消息
    async fn pull_messages_by_seqs(&self, req: &PullMessageBySeqsReq) -> Result<PullMessageBySeqsResp>;

    /// 按 seq 列表拉取指定消息（用于消息连续性检查补拉）
    async fn pull_messages_by_seq_list(&self, req: &GetSeqMessageReq) -> Result<GetSeqMessageResp>;

    /// 连接是否已被踢下线
    async fn is_kicked(&self) -> bool;

    /// 拉取指定会话的最新有效消息（重装模式下用于替换全被删除的会话）
    async fn pull_conv_last_message(
        &self,
        _user_id: &str,
        _conversation_ids: Vec<String>,
    ) -> Result<HashMap<String, MsgData>> {
        Ok(HashMap::new())
    }
}
