//! 消息撤回逻辑

use super::MessageService;
use super::req::RevokeMessageReq;
use crate::domain::constant::types::notification_type;
use crate::domain::error::types::{Result, SdkError};
use crate::domain::event::types::SdkEvent;
use crate::infra::http::routes::REVOKE_MSG;
use tracing::{info, warn};

impl MessageService {
    /// 撤回消息（对齐 Go SDK revoke.go waitForMessageSyncSeq + revokeOneMessage）
    ///
    /// 如果 seq 为 0，从本地数据库查找；若仍未同步，等待并重试（最多 5 次，每次 2 秒）。
    pub async fn revoke_message(
        &self,
        conversation_id: String,
        seq: i64,
        client_msg_id: String,
        session_type: i32,
    ) -> Result<()> {
        let user_id = self.user_id.lock().unwrap().clone();

        // 如果 seq 为 0，从本地数据库查找（对齐 Go SDK waitForMessageSyncSeq）
        let final_seq = if seq == 0 {
            self.wait_for_message_sync_seq(&conversation_id, &client_msg_id).await?
        } else {
            seq
        };

        let req = RevokeMessageReq {
            conversation_id: conversation_id.clone(),
            seq: final_seq,
            user_id: user_id.clone(),
            client_msg_id: client_msg_id.clone(),
            session_type,
        };

        let _resp: serde_json::Value = self.http_client.post(REVOKE_MSG, &req).await?;

        // 获取原消息信息用于构建事件
        let original_msg = self.message_dao.get_by_client_msg_id(&conversation_id, &client_msg_id).await?;
        
        // 更新本地数据库：标记消息为已撤回
        self.message_dao
            .update_content_type(&conversation_id, &client_msg_id, notification_type::REVOKE)
            .await?;

        // 构建完整的 MessageRevoked 事件
        let revoke_time = chrono::Utc::now().timestamp_millis();
        let (source_message_send_time, source_message_send_id, source_message_sender_nickname) = 
            if let Some(msg) = original_msg {
                (msg.send_time, msg.send_id.clone(), msg.sender_nick_name.clone())
            } else {
                (0, String::new(), String::new())
            };

        self.event_bus.publish(SdkEvent::MessageRevoked {
            conversation_id: conversation_id.clone(),
            seq: final_seq,
            client_msg_id: client_msg_id.clone(),
            revoker_id: user_id.clone(),
            revoker_role: 0,
            revoker_nickname: String::new(),
            revoke_time,
            source_message_send_time,
            source_message_send_id,
            source_message_sender_nickname,
            session_type,
            is_admin_revoke: false,
        });

        info!("消息已撤回: conversation_id={}, seq={}", conversation_id, final_seq);
        Ok(())
    }

    /// 等待消息 seq 同步到本地数据库（对齐 Go SDK waitForMessageSyncSeq）
    ///
    /// 消息发送后 seq 可能尚未同步到本地，需要等待 sync 完成。
    /// 最多重试 5 次，每次等待 2 秒。
    async fn wait_for_message_sync_seq(
        &self,
        conversation_id: &str,
        client_msg_id: &str,
    ) -> Result<i64> {
        for attempt in 0..5 {
            if let Ok(Some(msg)) = self.message_dao.get_by_client_msg_id(conversation_id, client_msg_id).await {
                if msg.seq > 0 {
                    return Ok(msg.seq);
                }
            }
            if attempt < 4 {
                warn!(
                    "消息 seq 尚未同步 (attempt={}), 等待重试: client_msg_id={}",
                    attempt + 1, client_msg_id
                );
                tokio::time::sleep(std::time::Duration::from_secs(2)).await;
            }
        }
        Err(SdkError::invalid_argument(format!(
            "消息 seq 未同步，无法撤回: client_msg_id={}", client_msg_id
        )))
    }
}
