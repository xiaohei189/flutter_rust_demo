use std::sync::Arc;

use anyhow::Result;
use crate::im::message::api::MessageApi;
use crate::im::dao::MessageStore;
use crate::im::message::models::{PullMessageBySeqsReq, SeqRange};
use crate::im::message::models::PullMessageBySeqsResp;
use crate::im::message::types::MsgStruct;
use crate::im::message::models::LocalChatLog;

/// 消息同步器（基于 HTTP 拉取），对齐 Go 版 MsgSyncer 的缺口补拉核心思路。
pub struct MessageSyncer {
    api: MessageApi,
    store: Arc<MessageStore>,
    user_id: String,
}

impl MessageSyncer {
    /// 创建消息同步器
    pub fn new(api: MessageApi, store: Arc<MessageStore>, user_id: String) -> Self {
        Self { api, store, user_id }
    }

    /// 以 `/msg/newest_seq` 获取服务器各会话最大 seq，对比本地缺口后执行一次补拉。
    pub async fn sync_once(&self) -> Result<()> {
        let newest = self.api.get_newest_seq().await?;
        let mut ranges = Vec::new();

        for (conv_id, remote_max) in newest.max_seqs.iter() {
            let local_max = self.store.max_seq(conv_id).await.unwrap_or(0);
            if *remote_max > local_max {
                ranges.push(SeqRange {
                    conversation_id: conv_id.clone(),
                    begin: local_max + 1,
                    end: *remote_max,
                    num: *remote_max - local_max,
                });
            }
        }

        if ranges.is_empty() {
            return Ok(());
        }

        let pull_req = PullMessageBySeqsReq {
            user_id: self.user_id.clone(),
            seq_ranges: ranges,
            order: 0,
        };
        let pull_resp = self.api.pull_msg_by_seqs(pull_req).await?;
        self.persist_pull_resp(pull_resp).await
    }

    async fn persist_pull_resp(&self, resp: PullMessageBySeqsResp) -> Result<()> {
        for (conv_id, pull) in resp.msgs.into_iter() {
            let locals = pull.msgs.iter().map(|m| Self::msg_to_local(&conv_id, m)).collect::<Vec<_>>();
            self.store.batch_insert_message_list(&conv_id, &locals).await?;
        }
        for (conv_id, pull) in resp.notification_msgs.into_iter() {
            let locals = pull.msgs.iter().map(|m| Self::msg_to_local(&conv_id, m)).collect::<Vec<_>>();
            self.store.batch_insert_message_list(&conv_id, &locals).await?;
        }
        Ok(())
    }

    fn msg_to_local(conversation_id: &str, m: &MsgStruct) -> LocalChatLog {
        LocalChatLog {
            conversation_id: conversation_id.to_string(),
            client_msg_id: m.client_msg_id.clone().unwrap_or_default(),
            server_msg_id: m.server_msg_id.clone().unwrap_or_default(),
            send_id: m.send_id.clone().unwrap_or_default(),
            recv_id: m.recv_id.clone().unwrap_or_default(),
            sender_platform_id: m.sender_platform_id,
            sender_nickname: m.sender_nickname.clone().unwrap_or_default(),
            sender_face_url: m.sender_face_url.clone().unwrap_or_default(),
            session_type: m.session_type,
            msg_from: m.msg_from,
            content_type: m.content_type,
            content: m.content.clone().unwrap_or_default(),
            is_read: m.is_read,
            status: m.status,
            seq: m.seq,
            send_time: m.send_time,
            create_time: m.create_time,
            attached_info: m.attached_info.clone().unwrap_or_default(),
            ex: m.ex.clone().unwrap_or_default(),
            local_ex: m.local_ex.clone().unwrap_or_default(),
            group_id: m.group_id.clone().unwrap_or_default(),
        }
    }
}


