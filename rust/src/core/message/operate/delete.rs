//! 消息删除逻辑

use super::MessageService;
use crate::domain::error::types::Result;
use crate::event::types::SdkEvent;
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
            if let Ok(Some(msg)) = self.stores.message_repo.get_by_client_msg_id(&conversation_id, client_msg_id).await {
                if msg.seq > 0 {
                    seqs.push(msg.seq);
                }
            }
        }

        // 通知服务端（失败则整体失败，本地不变更）
        let user_id = self.user_id.get().await;
        self.api.delete_on_server(&conversation_id, &seqs, &user_id).await?;

        // 服务端成功后删除本地
        self.apply_local_delete(&conversation_id, &client_msg_ids).await?;

        info!("消息已删除: conversation_id={}, count={}", conversation_id, client_msg_ids.len());
        Ok(())
    }

    /// 本地删除逻辑（服务端已确认成功后调用）
    pub(crate) async fn apply_local_delete(
        &self,
        conversation_id: &str,
        client_msg_ids: &[String],
    ) -> Result<()> {
        for client_msg_id in client_msg_ids {
            self.stores.message_repo.delete_by_client_msg_id(conversation_id, client_msg_id).await?;
        }

        self.event_bus.publish(SdkEvent::MessagesDeleted {
            conversation_id: conversation_id.to_string(),
            client_msg_ids: client_msg_ids.to_vec(),
        });

        Ok(())
    }
}

