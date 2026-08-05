//! 消息撤回逻辑

use super::MessageService;
use crate::constant::notification_type;
use crate::error::{Result, SdkError};
use crate::http::message::RevokeMessageReq;

use tracing::{info, warn};

impl MessageService {
    /// 撤回消息（对齐 Go SDK revoke.go waitForMessageSyncSeq + revokeOneMessage）
    ///
    /// 如果 seq 为 0，从本地数据库查找；若仍未同步，等待并重试（最多 5 次，每次 2 秒）。
    pub async fn revoke_message(&self, mut req: RevokeMessageReq) -> Result<()> {
        // 外部传入的 user_id 可能为空，统一以当前登录用户覆盖（值一致）
        req.user_id = self.user_id.get().await;

        // 如果 seq 为 0，从本地数据库查找（对齐 Go SDK waitForMessageSyncSeq）
        if req.seq == 0 {
            req.seq = self.wait_for_message_sync_seq(&req.conversation_id, &req.client_msg_id).await?;
        }
        let final_seq = req.seq;

        // 通知服务端（失败则整体失败，本地不变更）
        self.api.revoke_on_server(&req).await?;

        // 服务端成功后更新本地
        self.apply_local_revoke(&req.conversation_id, &req.client_msg_id, final_seq, req.session_type).await?;

        info!("消息已撤回: conversation_id={}, seq={}", req.conversation_id, final_seq);
        Ok(())
    }

    /// 本地撤回逻辑（服务端已确认成功后调用）
    pub(crate) async fn apply_local_revoke(&self, conversation_id: &str, client_msg_id: &str, seq: i64, session_type: i32) -> Result<()> {
        // 更新本地数据库：标记消息为已撤回
        self.repositories.message_repo.update_content_type(conversation_id, client_msg_id, notification_type::REVOKE).await?;

        Ok(())
    }

    /// 等待消息 seq 同步到本地数据库（对齐 Go SDK waitForMessageSyncSeq）
    ///
    /// 消息发送后 seq 可能尚未同步到本地，需要等待 sync 完成。
    /// 最多重试 5 次，每次等待 2 秒。
    async fn wait_for_message_sync_seq(&self, conversation_id: &str, client_msg_id: &str) -> Result<i64> {
        for attempt in 0..5 {
            if let Ok(Some(msg)) = self.repositories.message_repo.get_by_client_msg_id(conversation_id, client_msg_id).await {
                if msg.seq > 0 {
                    return Ok(msg.seq);
                }
            }
            if attempt < 4 {
                warn!("消息 seq 尚未同步 (attempt={}), 等待重试: client_msg_id={}", attempt + 1, client_msg_id);
                tokio::time::sleep(std::time::Duration::from_secs(2)).await;
            }
        }
        Err(SdkError::invalid_argument(format!("消息 seq 未同步，无法撤回: client_msg_id={}", client_msg_id)))
    }
}
