//! 消息删除逻辑

use super::MessageService;
use crate::domain::error::types::Result;
use crate::domain::event::types::SdkEvent;
use crate::infra::http::routes::DELETE_MSGS;
use tracing::info;

impl MessageService {
    /// 删除消息（对齐 Go SDK deleteMessage）
    ///
    /// 服务端 API 需要 seqs，从本地数据库查找。
    pub async fn delete_messages(
        &self,
        conversation_id: String,
        client_msg_ids: Vec<String>,
    ) -> Result<()> {
        // 从本地数据库查找每条消息的 seq
        let mut seqs = Vec::new();
        for client_msg_id in &client_msg_ids {
            if let Ok(Some(msg)) = self.message_dao.get_by_client_msg_id(&conversation_id, client_msg_id).await {
                if msg.seq > 0 {
                    seqs.push(msg.seq);
                }
            }
        }

        // 调用服务端 API（需要 seqs）
        #[derive(serde::Serialize)]
        struct ServerDeleteReq {
            #[serde(rename = "conversationID")]
            conversation_id: String,
            seqs: Vec<i64>,
            #[serde(rename = "userID")]
            user_id: String,
        }
        let user_id = self.user_id.lock().unwrap().clone();
        let req = ServerDeleteReq {
            conversation_id: conversation_id.clone(),
            seqs,
            user_id,
        };
        let _resp: serde_json::Value = self.http_client.post(DELETE_MSGS, &req).await?;

        // 删除本地数据库中的消息
        for client_msg_id in &client_msg_ids {
            self.message_dao.delete_by_client_msg_id(&conversation_id, client_msg_id).await?;
        }

        self.event_bus.publish(SdkEvent::MessagesDeleted {
            conversation_id: conversation_id.clone(),
            client_msg_ids: client_msg_ids.clone(),
        });

        info!("消息已删除: conversation_id={}, count={}", conversation_id, client_msg_ids.len());
        Ok(())
    }
}

