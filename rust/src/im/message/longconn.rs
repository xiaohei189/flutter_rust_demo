use std::collections::HashMap;
use async_trait::async_trait;
use anyhow::Result;

use crate::im::message::api::MessageApi;
use crate::im::message::models::{PullMessageBySeqsReq, PullMessageBySeqsResp, SeqRange};

/// 长连接消息同步 RPC 抽象
#[async_trait]
pub trait LongConnRpc: Send + Sync {
    /// 获取各会话最新 seq（等价于 /msg/newest_seq 的结果）
    async fn get_newest_seq(&self) -> Result<HashMap<String, i64>>;

    /// 按区间拉取消息（等价于 /msg/pull_msg_by_seq 的长连版）
    async fn pull_msg_by_ranges(&self, ranges: Vec<SeqRange>) -> Result<PullMessageBySeqsResp>;
}

/// 使用 HTTP API 的回退实现，便于在未接入真实长连时跑通流程
pub struct HttpFallbackLongConn {
    api: MessageApi,
    user_id: String,
}

impl HttpFallbackLongConn {
    pub fn new(api: MessageApi, user_id: String) -> Self {
        Self { api, user_id }
    }
}

#[async_trait]
impl LongConnRpc for HttpFallbackLongConn {
    async fn get_newest_seq(&self) -> Result<HashMap<String, i64>> {
        let newest = self.api.get_newest_seq().await?;
        Ok(newest.max_seqs)
    }

    async fn pull_msg_by_ranges(&self, ranges: Vec<SeqRange>) -> Result<PullMessageBySeqsResp> {
        if ranges.is_empty() {
            return Ok(PullMessageBySeqsResp::default());
        }
        let req = PullMessageBySeqsReq {
            user_id: self.user_id.clone(),
            seq_ranges: ranges,
            order: 0,
        };
        self.api.pull_msg_by_seqs(req).await
    }
}

