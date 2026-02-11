//! 会话处理模块（对齐 Go internal/conversation_msg）
//!
//! 合并原 conversation/service 的会话同步逻辑，通过命令通道接收消息同步器下发的会话命令。

use crate::im::api::api::Api;
use crate::im::dao::repository::Repository;
use crate::im::listener::ConversationListener;
use crate::im::model::constant::sync_flag;
use crate::im::model::conversation::{ConversationSyncerConfig, LocalVersionSync};
use crate::im::model::LocalConversation;
use anyhow::Result;
use openim_protocol::constant;
use openim_protocol::sdkws;
use sqlx::{Pool, Sqlite};
use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::mpsc;
use tokio_util::sync::CancellationToken;
use tracing::{Instrument, debug, info, info_span, instrument, warn};
use uuid::Uuid;

// ---------- 命令类型（对齐 Go pkg/constant Cmd* 与 common.Cmd2Value） ----------

/// 具体命令类型（不含 tracing 上下文）
#[derive(Debug)]
pub enum ConvCmdKind {
    /// 新消息到达会话（constant.CmdNewMsgCome）；msg_id 为下行推送唯一 ID，用于串联处理链路
    NewMsgCome { msg_id: Option<String>, msgs: HashMap<String, sdkws::PullMsgs> },
    /// 更新会话（constant.CmdUpdateConversation）
    UpdateConversation(UpdateConNode),
    /// 通知消息（constant.CmdNotification）；msg_id 为下行推送唯一 ID
    Notification { msg_id: Option<String>, msgs: HashMap<String, sdkws::PullMsgs> },
    /// 同步阶段标记（constant.CmdSyncFlag），取值为 sync_flag::*：MsgSyncBegin(1001)/MsgSyncProcessing(1002)/MsgSyncEnd(1003)/MsgSyncFailed(1004)/AppDataSyncStart(1005)/AppDataSyncFinish(1006)
    SyncFlag(i32),
    /// 同步数据（constant.CmdSyncData）
    SyncData,
    /// 重装后消息同步（constant.CmdMsgSyncInReinstall）；msg_id 为下行推送唯一 ID
    MsgSyncInReinstall { msg_id: Option<String>, msgs: HashMap<String, sdkws::PullMsgs>, total: i32 },
}

/// 命令信封：具体命令 + span，用于与调用方 tracing 串起来（接收端先取命令再按 kind 处理逻辑）
#[derive(Debug)]
pub struct ConvCmd {
    pub kind: ConvCmdKind,
    pub span: Option<tracing::Span>,
}

#[inline]
fn conv_cmd_kind_name(kind: &ConvCmdKind) -> &'static str {
    match kind {
        ConvCmdKind::NewMsgCome { .. } => "NewMsgCome",
        ConvCmdKind::UpdateConversation(_) => "UpdateConversation",
        ConvCmdKind::Notification { .. } => "Notification",
        ConvCmdKind::SyncFlag(_) => "SyncFlag",
        ConvCmdKind::SyncData => "SyncData",
        ConvCmdKind::MsgSyncInReinstall { .. } => "MsgSyncInReinstall",
    }
}

/// 更新会话节点（对齐 Go common.UpdateConNode）
#[derive(Debug)]
pub struct UpdateConNode {
    pub con_id: String,
    /// 1=删除会话 2=更新/新增会话 3=置顶 4=取消置顶 5=未读清零 6=会话变更 8=会话直接变更 9=新会话直接
    pub action: i32,
    pub args: Option<UpdateConArgs>,
}

#[derive(Debug)]
pub enum UpdateConArgs {
    ConversationIds(Vec<String>),
    Conversation(Box<LocalConversation>),
    Json(String),
}

// ---------- 会话处理器（原 ConversationSyncer 逻辑已全部并入，不再单独存在） ----------

pub struct ConversationHandle {
    config: ConversationSyncerConfig,
    api: Api,
    repository: Repository,
    listener: Option<Arc<dyn ConversationListener>>,
    cmd_rx: mpsc::UnboundedReceiver<ConvCmd>,
    cancel_token: CancellationToken,
}

impl ConversationHandle {
    /// 使用共享连接池与 HTTP 客户端创建（供 client 初始化时调用）
    pub async fn with_listener_and_db_and_client(
        config: ConversationSyncerConfig,
        listener: Option<Arc<dyn ConversationListener>>,
        db: Pool<Sqlite>,
        http_client: reqwest::Client,
        cmd_rx: mpsc::UnboundedReceiver<ConvCmd>,
        cancel_token: CancellationToken,
    ) -> Result<Self> {
        let api = Api::new(http_client.clone(), config.api_base_url.clone(), config.user_id.clone(), &config.token);
        let repository = Repository::new(db);
        Ok(Self { config, api, repository, listener, cmd_rx, cancel_token })
    }

    /// 从数据库获取所有本地会话
    
    pub async fn get_all_conversations(&self) -> Result<Vec<LocalConversation>> {
        self.repository.conversation.get_all_conversations().await
    }

    /// 从数据库获取所有会话 ID
    pub async fn get_all_conversation_ids(&self) -> Result<Vec<String>> {
        self.repository.conversation.get_all_conversation_ids().await
    }

    async fn get_version_sync(&self) -> Result<Option<LocalVersionSync>> {
        self.repository.version_sync.get_version_sync().await
    }

    async fn save_version_sync(&self, version_sync: &LocalVersionSync) -> Result<()> {
        self.repository.version_sync.save_version_sync(version_sync).await
    }

    async fn upsert_conversation(&self, conv: &LocalConversation) -> Result<()> {
        self.repository.conversation.upsert_conversation(conv).await
    }

    fn build_latest_msg_summary(msg: &sdkws::MsgData) -> String {
        if msg.content_type == constant::TEXT {
            if let Ok(s) = String::from_utf8(msg.content.clone()) {
                if let Ok(text_elem) = serde_json::from_str::<crate::im::message::types::TextElem>(&s) {
                    if !text_elem.content.is_empty() {
                        return text_elem.content;
                    }
                }
                if !s.is_empty() {
                    return s;
                }
            }
            return "[文本]".to_string();
        }
        match msg.content_type {
            t if t == constant::PICTURE => "[图片]".to_string(),
            t if t == constant::VOICE => "[语音]".to_string(),
            t if t == constant::VIDEO => "[视频]".to_string(),
            t if t == constant::FILE => "[文件]".to_string(),
            t if t == constant::AT_TEXT => "[@消息]".to_string(),
            t if t == constant::LOCATION => "[位置]".to_string(),
            t if t == constant::MERGER => "[聊天记录]".to_string(),
            t if t == constant::CARD => "[名片]".to_string(),
            1201 | 1203 | 1204 => "[好友通知]".to_string(),
            1501 | 1504 | 1508 => "[群通知]".to_string(),
            2200 => "[已读回执]".to_string(),
            _ => "[新消息]".to_string(),
        }
    }

    /// 基于新消息/通知实时更新会话（未读数、最新消息等）
    #[instrument(skip(self, msg), name = "conv.on_new_message", fields(conv_id = %conversation_id, is_notification = is_notification))]
    pub async fn on_new_message(&self, conversation_id: &str, msg: &sdkws::MsgData, is_notification: bool) -> Result<()> {
        if is_notification {
            match msg.content_type {
                constant::CONVERSATION_CHANGE_NOTIFICATION
                | constant::CONVERSATION_PRIVATE_CHAT_NOTIFICATION
                | constant::CLEAR_CONVERSATION_NOTIFICATION
                | constant::CONVERSATION_UNREAD_NOTIFICATION
                | constant::CONVERSATION_DELETE_NOTIFICATION
                | constant::HAS_READ_RECEIPT => {
                    info!("[ConvSync] 收到会话通知 contentType={} 触发增量会话同步", msg.content_type);
                    if let Err(e) = self.incr_sync_conversations().await {
                        warn!("[ConvSync] 会话通知触发增量同步失败 err={}", e);
                    }
                    return Ok(());
                }
                _ => {}
            }
        }

        let existing_conv = self.repository.conversation.get_conversation_by_id(conversation_id).await?;
        let mut conv = if let Some(ref existing) = existing_conv {
            existing.clone()
        } else {
            LocalConversation {
                conversation_id: conversation_id.to_string(),
                conversation_type: msg.session_type,
                user_id: msg.send_id.clone(),
                group_id: msg.group_id.clone(),
                show_name: String::new(),
                face_url: String::new(),
                latest_msg: String::new(),
                latest_msg_send_time: 0,
                unread_count: 0,
                recv_msg_opt: 0,
                is_pinned: false,
                is_private_chat: false,
                burn_duration: 0,
                group_at_type: 0,
                is_not_in_group: false,
                update_unread_count_time: 0,
                attached_info: String::new(),
                ex: String::new(),
                draft_text: String::new(),
                draft_text_time: 0,
                max_seq: msg.seq,
                min_seq: msg.seq,
                is_msg_destruct: false,
                msg_destruct_time: 0,
            }
        };

        let is_new = existing_conv.is_none();
        let latest = Self::build_latest_msg_summary(msg);
        let send_time = if msg.send_time > 0 { msg.send_time } else { msg.create_time };
        conv.latest_msg = latest;
        conv.latest_msg_send_time = send_time;
        conv.max_seq = conv.max_seq.max(msg.seq);

        let should_count_unread = if msg.send_id == self.config.user_id || is_notification {
            false
        } else {
            *msg.options.get("unreadCount").unwrap_or(&true)
        };

        if should_count_unread {
            let is_new_msg = msg.seq > conv.max_seq.saturating_sub(1);
            if is_new_msg {
                conv.unread_count += 1;
            }
        }

        self.upsert_conversation(&conv).await?;
        let json = serde_json::to_string(&vec![conv.clone()]).unwrap_or_else(|_| "[]".to_string());
        if is_new {
            if let Some(listener) = &self.listener {
                listener.on_new_conversation(json).await;
            }
        } else {
            if let Some(listener) = &self.listener {
                listener.on_conversation_changed(json).await;
            }
        }
        if let Ok(total_unread) = self.get_total_unread_count().await {
            if let Some(listener) = &self.listener {
                listener.on_total_unread_message_count_changed(total_unread).await;
            }
        }
        Ok(())
    }

    async fn delete_conversation(&self, conversation_id: &str) -> Result<()> {
        self.repository.conversation.delete_conversation(conversation_id).await
    }

    /// 获取总未读消息数
    pub async fn get_total_unread_count(&self) -> Result<i32> {
        self.repository.conversation.get_total_unread_count().await
    }

    /// 基于服务器的 MaxSeq / HasReadSeq 校正本地未读数
    #[instrument(skip(self), )]
    pub async fn sync_unread_by_seq(&self) -> Result<()> {
        info!("开始按 Seq 校正未读数");
        let mut local_conversations = self.get_all_conversations().await?;
        let mut local_map: HashMap<String, LocalConversation> = HashMap::new();
        for conv in local_conversations.drain(..) {
            local_map.insert(conv.conversation_id.clone(), conv);
        }
        let seqs = self.api.conversation.get_has_read_and_max_seqs().await?;
        if seqs.is_empty() {
            info!("服务器未返回会话 Seq 信息 跳过未读数校正");
            return Ok(());
        }
        let mut changed_conversations: Vec<LocalConversation> = Vec::new();
        let mut new_conversations: Vec<LocalConversation> = Vec::new();
        let mut missing_convs: Vec<(String, (i64, i64))> = Vec::new();
        info!("开始校正未读数 服务器返回 {} 个会话的 Seq 信息", seqs.len());
        for (conv_id, (max_seq, has_read_seq)) in seqs.into_iter() {
            let unread = (max_seq - has_read_seq).max(0) as i32;
            if let Some(mut local) = local_map.remove(&conv_id) {
                if local.unread_count != unread || local.max_seq != max_seq {
                    info!(
                        "[ConvSync] Seq 校正会话未读数 conversationID={} 本地未读数 {}->{} maxSeq {}->{} hasReadSeq={}",
                        conv_id, local.unread_count, unread, local.max_seq, max_seq, has_read_seq
                    );
                    local.unread_count = unread;
                    local.max_seq = max_seq;
                    self.upsert_conversation(&local).await?;
                    changed_conversations.push(local);
                }
            } else {
                info!(
                    "[ConvSync] Seq 按 Seq 校正未读数时发现本地不存在的会话 conversationID={} maxSeq={} hasReadSeq={} unreadCount={}",
                    conv_id, max_seq, has_read_seq, unread
                );
                missing_convs.push((conv_id, (max_seq, has_read_seq)));
            }
        }
        if !missing_convs.is_empty() {
            info!("[ConvSync] Seq 发现本地缺失会话 {} 个 尝试从服务器补齐详情", missing_convs.len());
            if let Ok(all_resp) = self.api.conversation.get_all_conversations().await {
                let server_map: HashMap<String, LocalConversation> =
                    all_resp.conversations.iter().map(|c| (c.conversation_id.clone(), c.clone())).collect();
                for (conv_id, (max_seq, has_read_seq)) in missing_convs.into_iter() {
                    if let Some(mut conv) = server_map.get(&conv_id).cloned() {
                        let unread = (max_seq - has_read_seq).max(0) as i32;
                        conv.unread_count = unread;
                        conv.max_seq = max_seq;
                        self.upsert_conversation(&conv).await?;
                        new_conversations.push(conv);
                    } else {
                        warn!("[ConvSync/Seq] 按 Seq 校正时服务器会话列表中也不存在会话: {} (maxSeq={}, hasReadSeq={})", conv_id, max_seq, has_read_seq);
                    }
                }
            }
        }
        if !new_conversations.is_empty() {
            let json = serde_json::to_string(&new_conversations).unwrap_or_else(|_| "[]".to_string());
            if let Some(listener) = &self.listener {
                listener.on_new_conversation(json).await;
            }
        }
        if !changed_conversations.is_empty() {
            let json = serde_json::to_string(&changed_conversations).unwrap_or_else(|_| "[]".to_string());
            if let Some(listener) = &self.listener {
                listener.on_conversation_changed(json).await;
            }
        }
        if !new_conversations.is_empty() || !changed_conversations.is_empty() {
            if let Ok(total_unread) = self.get_total_unread_count().await {
                if let Some(listener) = &self.listener {
                    listener.on_total_unread_message_count_changed(total_unread).await;
                }
            }
        }
        info!("[ConvSync] Seq 按 Seq 校正未读数完成");
        Ok(())
    }

    #[instrument(skip(self, server_conversations, local_conversations, seqs_map), name = "conv.sync_conversations", fields(server_n = server_conversations.len(), local_n = local_conversations.len()))]
    async fn sync_conversations(
        &self,
        server_conversations: Vec<LocalConversation>,
        local_conversations: Vec<LocalConversation>,
        seqs_map: Option<&HashMap<String, (i64, i64)>>,
    ) -> Result<()> {
        info!(
            "[ConvSync] 开始同步会话 服务器会话数={} 本地会话数={}",
            server_conversations.len(),
            local_conversations.len()
        );
        let local_map: HashMap<String, LocalConversation> = local_conversations.into_iter().map(|c| (c.conversation_id.clone(), c)).collect();
        let mut server_map: HashMap<String, LocalConversation> =
            server_conversations.into_iter().map(|c| (c.conversation_id.clone(), c)).collect();
        let mut new_conversations = Vec::new();
        let mut changed_conversations = Vec::new();
        let mut insert_count = 0;
        let mut update_count = 0;
        let mut delete_count = 0;
        if let Some(seqs) = seqs_map {
            for (conv_id, &(max_seq, has_read_seq)) in seqs.iter() {
                if let Some(server_conv) = server_map.get_mut(conv_id) {
                    let unread = (max_seq - has_read_seq).max(0) as i32;
                    server_conv.unread_count = unread;
                    server_conv.max_seq = max_seq;
                }
            }
        }
        for (id, server_conv) in server_map.iter() {
            if let Some(local_conv) = local_map.get(id) {
                let mut server_conv = server_conv.clone();
                self.fill_display_fields(&mut server_conv);
                let need_update = !self.conversations_equal(local_conv, &server_conv)
                    || local_conv.unread_count != server_conv.unread_count
                    || local_conv.max_seq != server_conv.max_seq;
                if need_update {
                    self.upsert_conversation(&server_conv).await?;
                    changed_conversations.push(server_conv);
                    update_count += 1;
                }
            } else {
                let mut server_conv = server_conv.clone();
                self.fill_display_fields(&mut server_conv);
                self.upsert_conversation(&server_conv).await?;
                new_conversations.push(server_conv);
                insert_count += 1;
            }
        }
        let local_ids: std::collections::HashSet<String> = local_map.keys().cloned().collect();
        let server_ids: std::collections::HashSet<String> = server_map.keys().cloned().collect();
        for id in local_ids.difference(&server_ids) {
            self.delete_conversation(id).await?;
            delete_count += 1;
        }
        if !new_conversations.is_empty() {
            let json = serde_json::to_string(&new_conversations).unwrap_or_else(|_| "[]".to_string());
            if let Some(listener) = &self.listener {
                listener.on_new_conversation(json).await;
            }
        }
        if !changed_conversations.is_empty() {
            let json = serde_json::to_string(&changed_conversations).unwrap_or_else(|_| "[]".to_string());
            if let Some(listener) = &self.listener {
                listener.on_conversation_changed(json).await;
            }
        }
        if insert_count > 0 || update_count > 0 || delete_count > 0 {
            if let Ok(total_unread) = self.get_total_unread_count().await {
                if let Some(listener) = &self.listener {
                    listener.on_total_unread_message_count_changed(total_unread).await;
                }
            }
        }
        info!("[ConvSync] 会话同步完成 新增={} 更新={} 删除={}", insert_count, update_count, delete_count);
        Ok(())
    }

    fn conversations_equal(&self, local: &LocalConversation, server: &LocalConversation) -> bool {
        local.recv_msg_opt == server.recv_msg_opt
            && local.is_pinned == server.is_pinned
            && local.is_private_chat == server.is_private_chat
            && local.burn_duration == server.burn_duration
            && local.is_not_in_group == server.is_not_in_group
            && local.group_at_type == server.group_at_type
            && local.update_unread_count_time == server.update_unread_count_time
            && local.attached_info == server.attached_info
            && local.ex == server.ex
            && local.max_seq == server.max_seq
            && local.min_seq == server.min_seq
            && local.msg_destruct_time == server.msg_destruct_time
            && local.is_msg_destruct == server.is_msg_destruct
            && local.show_name == server.show_name
            && local.face_url == server.face_url
            && local.latest_msg == server.latest_msg
            && local.latest_msg_send_time == server.latest_msg_send_time
    }

    fn fill_display_fields(&self, _conv: &mut LocalConversation) {}

    /// 增量同步会话（对应 Go 版本的 IncrSyncConversations）
    #[instrument(skip(self))]
    pub async fn incr_sync_conversations(&self) -> Result<()> {
        let version_sync = self.get_version_sync().await?;
        let local_conversations = self.get_all_conversations().await?;
        let local_ids = self.get_all_conversation_ids().await?;
        let reinstalled = local_ids.is_empty();
        if reinstalled {
            if let Some(listener) = &self.listener {
                listener.on_sync_server_start(true).await;
            }
            return self.full_sync().await;
        }
        let all_placeholder = local_conversations.iter().all(|c| {
            c.show_name.is_empty() && c.face_url.is_empty() && c.latest_msg.is_empty() && c.latest_msg_send_time == 0
        });
        if all_placeholder {
            if let Some(listener) = &self.listener {
                listener.on_sync_server_start(true).await;
            }
            return self.full_sync().await;
        }
        let (version, version_id) = if let Some(vs) = version_sync {
            (vs.version, vs.version_id)
        } else {
            let server_ids_vec = self.api.conversation.get_all_conversation_ids().await?;
            let server_ids: std::collections::HashSet<String> = server_ids_vec.iter().cloned().collect();
            let local_ids_set: std::collections::HashSet<String> = local_ids.iter().cloned().collect();
            if server_ids != local_ids_set {
                return self.full_sync().await;
            }
            let all_resp = self.api.conversation.get_all_conversations().await?;
            let server_convs: Vec<LocalConversation> = all_resp.conversations.clone();
            let seqs_map = self.api.conversation.get_has_read_and_max_seqs().await.ok();
            self.sync_conversations(server_convs.clone(), local_conversations.clone(), seqs_map.as_ref()).await?;
            let new_version = LocalVersionSync {
                table_name: "local_conversations".to_string(),
                entity_id: self.config.user_id.clone(),
                version: 1,
                version_id: Uuid::new_v4().to_string(),
            };
            self.save_version_sync(&new_version).await?;
            return Ok(());
        };
        if let Some(listener) = &self.listener {
            listener.on_sync_server_start(false).await;
        }
        if let Some(listener) = &self.listener {
            listener.on_sync_server_progress(10).await;
        }
        let resp = match self.api.conversation.get_incremental_conversations(version, &version_id).await {
            Ok(r) => r,
            Err(e) => {
                if let Some(listener) = &self.listener {
                    listener.on_sync_server_failed(false).await;
                }
                return Err(e);
            }
        };
        if resp.full {
            return self.full_sync().await;
        }
        let mut server_conversations = Vec::new();
        for server_conv in resp.insert.iter() {
            server_conversations.push(server_conv.clone());
        }
        for server_conv in resp.update.iter() {
            server_conversations.push(server_conv.clone());
        }
        let seqs_map = self.api.conversation.get_has_read_and_max_seqs().await.ok();
        self.sync_conversations(server_conversations, local_conversations, seqs_map.as_ref()).await?;
        if let Some(listener) = &self.listener {
            listener.on_sync_server_progress(80).await;
        }
        for id in resp.delete.iter() {
            self.delete_conversation(id).await?;
        }
        if !resp.version_id.is_empty() {
            let new_version = if resp.version > 0 { resp.version } else { version + 1 };
            let new_version_sync = LocalVersionSync {
                table_name: "local_conversations".to_string(),
                entity_id: self.config.user_id.clone(),
                version: new_version,
                version_id: resp.version_id.clone(),
            };
            self.save_version_sync(&new_version_sync).await?;
        }
        if let Some(listener) = &self.listener {
            listener.on_sync_server_progress(100).await;
        }
        if let Some(listener) = &self.listener {
            listener.on_sync_server_finish(false).await;
        }
        let _ = self.sync_unread_by_seq().await;
        Ok(())
    }

    /// 全量同步会话（供测试与内部调用）
    #[instrument(skip(self), name = "conv.full_sync")]
    pub async fn full_sync(&self) -> Result<()> {
        let reinstalled = self.get_all_conversation_ids().await?.is_empty();
        if let Some(listener) = &self.listener {
            listener.on_sync_server_start(reinstalled).await;
        }
        if let Some(listener) = &self.listener {
            listener.on_sync_server_progress(10).await;
        }
        let resp = match self.api.conversation.get_all_conversations().await {
            Ok(r) => r,
            Err(e) => {
                if let Some(listener) = &self.listener {
                    listener.on_sync_server_failed(reinstalled).await;
                }
                return Err(e);
            }
        };
        let server_conversations: Vec<LocalConversation> = resp.conversations.clone();
        if let Some(listener) = &self.listener {
            listener.on_sync_server_progress(30).await;
        }
        let local_conversations = self.get_all_conversations().await?;
        let seqs_map = self.api.conversation.get_has_read_and_max_seqs().await.ok();
        self.sync_conversations(server_conversations, local_conversations, seqs_map.as_ref()).await?;
        if let Some(listener) = &self.listener {
            listener.on_sync_server_progress(80).await;
        }
        let new_version = LocalVersionSync {
            table_name: "local_conversations".to_string(),
            entity_id: self.config.user_id.clone(),
            version: 1,
            version_id: Uuid::new_v4().to_string(),
        };
        self.save_version_sync(&new_version).await?;
        if let Some(listener) = &self.listener {
            listener.on_sync_server_progress(100).await;
        }
        if let Some(listener) = &self.listener {
            listener.on_sync_server_finish(reinstalled).await;
        }
        let _ = self.sync_unread_by_seq().await;
        Ok(())
    }

    /// 获取会话列表（分页）
    pub async fn get_conversation_list_split(&self, offset: usize, count: usize) -> Result<Vec<LocalConversation>> {
        let mut list = self.get_all_conversations().await?;
        list.sort_by(|a, b| {
            match (a.is_pinned, b.is_pinned) {
                (true, false) => std::cmp::Ordering::Less,
                (false, true) => std::cmp::Ordering::Greater,
                _ => {
                    let time_a = a.latest_msg_send_time.max(a.draft_text_time);
                    let time_b = b.latest_msg_send_time.max(b.draft_text_time);
                    time_b.cmp(&time_a)
                }
            }
        });
        let start = offset.min(list.len());
        let end = (offset + count).min(list.len());
        Ok(list[start..end].to_vec())
    }

    /// 获取所有会话列表
    pub async fn get_all_conversation_list(&self) -> Result<Vec<LocalConversation>> {
        self.get_conversation_list_split(0, usize::MAX).await
    }

    // ---------- 命令处理（由 ConversationHandle 调用） ----------

    /// 新消息到达会话（Go doMsgNew）
    #[instrument(skip(self, msgs), name = "conv.do_msg_new", fields(convs = msgs.len()))]
    pub async fn do_msg_new(&self, msgs: HashMap<String, sdkws::PullMsgs>) -> Result<()> {
        for (conversation_id, pull) in msgs {
            for msg in pull.msgs {
                if let Err(e) = self.on_new_message(&conversation_id, &msg, false).await {
                    warn!("[ConvSync] 新消息处理失败 conv={} err={}", conversation_id, e);
                }
            }
        }
        Ok(())
    }

    /// 更新会话（Go doUpdateConversation）
    #[instrument(skip(self), name = "conv.do_update_conversation", fields(action = node.action, con_id = %node.con_id))]
    pub async fn do_update_conversation(&self, node: UpdateConNode) -> Result<()> {
        debug!("[ConvSync] 更新会话 action={} con_id={}", node.action, node.con_id);
        // TODO: 按 node.action 分支：删除/更新/置顶/未读清零/通知变更等
        let _ = node;
        Ok(())
    }

    /// 通知消息处理（Go doNotificationManager）
    #[instrument(skip(self, msgs), name = "conv.do_notification_manager", fields(convs = msgs.len()))]
    pub async fn do_notification_manager(&self, msgs: HashMap<String, sdkws::PullMsgs>) -> Result<()> {
        for (conversation_id, pull) in msgs {
            for msg in pull.msgs {
                if let Err(e) = self.on_new_message(&conversation_id, &msg, true).await {
                    warn!("[ConvSync] 通知消息处理失败 conv={} err={}", conversation_id, e);
                }
            }
        }
        Ok(())
    }

    /// 同步阶段标记（Go syncFlag）
    #[instrument(skip(self), fields(flag = flag))]
    pub async fn sync_flag(&self, flag: i32) -> Result<()> {
        if let Some(listener) = &self.listener {
            match flag {
                sync_flag::APP_DATA_SYNC_START => listener.on_sync_server_start(true).await,
                sync_flag::APP_DATA_SYNC_FINISH => listener.on_sync_server_finish(true).await,
                sync_flag::MSG_SYNC_BEGIN => listener.on_sync_server_start(false).await,
                sync_flag::MSG_SYNC_END => listener.on_sync_server_finish(false).await,
                sync_flag::MSG_SYNC_PROCESSING | sync_flag::MSG_SYNC_FAILED => {}
                _ => {}
            }
        }
        Ok(())
    }

    /// 同步数据（对齐 Go syncData，notification.go）
    ///
    /// 1. 同步步骤（syncWait）：校正会话已读/未读 Seq（SyncAllConversationHashReadSeqs）
    /// 2. 异步步骤（asyncNoWait）：增量同步会话（IncrSyncConversationsWithLock）
    ///
    /// Go 中还有 user/relation/group 等异步任务，当前仅实现会话相关。
    #[instrument(skip(self))]
    pub async fn sync_data(&self) -> Result<()> {
        // 1. 同步：拉取服务器 HasRead/MaxSeq，校正本地未读数
        if let Err(e) = self.sync_unread_by_seq().await {
            warn!("[ConvSync] SyncData 中 sync_unread_by_seq 失败 err={}", e);
        }
        // 2. 增量同步会话列表
        self.incr_sync_conversations().await
    }

    /// 重装后消息同步（Go doMsgSyncByReinstalled）
    #[instrument(skip(self, msgs), fields(convs = msgs.len(), total = _total))]
    pub async fn do_msg_sync_by_reinstalled(&self, msgs: HashMap<String, sdkws::PullMsgs>, _total: i32) -> Result<()> {
        self.do_msg_new(msgs).await
    }

    /// 主循环：接收命令并分发（对齐 Go Conversation.Work）
    pub async fn run(&mut self) -> Result<()> {
        loop {
            let cmd = tokio::select! {
                _ = self.cancel_token.cancelled() => {
                    debug!("[conversation_handle] 收到取消信号，退出");
                    return Ok(());
                }
                cmd = self.cmd_rx.recv() => cmd,
            };
            let Some(envelope) = cmd else {
                debug!("[ConvSync] cmd_rx 已关闭 退出");
                return Ok(());
            };
            // 取出透传的 span，后续处理步骤接入 trace
            let common_span = match &envelope.span {
                Some(p) => info_span!(
                    parent: p,
                    "conv_sync.command",
                    kind = conv_cmd_kind_name(&envelope.kind),
                    messaging_operation = "process",
                    otel_span_kind = "CONSUMER",
                ),
                None => info_span!(
                    parent: None,
                    "conv_sync.command",
                    kind = conv_cmd_kind_name(&envelope.kind),
                    messaging_operation = "process",
                    otel_span_kind = "CONSUMER",
                ),
            };
            // 将整个处理包在 instrument 内，使 debug/work 全在 span 范围内
            let process_fut = async {
                debug!("[ConvSync] 收到命令 {:?}", envelope.kind);
                if let Err(e) = self.work(envelope).await {
                    warn!("[ConvSync] 处理命令失败 err={}", e);
                }
            };
            process_fut.instrument(common_span).await;
        }
    }

    async fn work(&mut self, envelope: ConvCmd) -> Result<()> {
        match envelope.kind {
            ConvCmdKind::NewMsgCome { msg_id, msgs } => {
                if let Some(ref id) = msg_id {
                    debug!(msg_id = %id, "[ConvSync] 处理 NewMsgCome 会话数={}", msgs.len());
                }
                self.do_msg_new(msgs).await
            }
            ConvCmdKind::UpdateConversation(node) => self.do_update_conversation(node).await,
            ConvCmdKind::Notification { msg_id, msgs } => {
                if let Some(ref id) = msg_id {
                    debug!(msg_id = %id, "[ConvSync] 处理 Notification 会话数={}", msgs.len());
                }
                self.do_notification_manager(msgs).await
            }
            ConvCmdKind::SyncFlag(flag) => self.sync_flag(flag).await,
            ConvCmdKind::SyncData => self.sync_data().await,
            ConvCmdKind::MsgSyncInReinstall { msg_id, msgs, total } => {
                if let Some(ref id) = msg_id {
                    debug!(msg_id = %id, "[ConvSync] 处理 MsgSyncInReinstall total={}", total);
                }
                self.do_msg_sync_by_reinstalled(msgs, total).await
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::im::dao::Repository;
    use crate::im::logger::logger::init_logger;
    use crate::im::model::conversation::ConversationSyncerConfig;
    use crate::im::login_async;
    use test_context::{test_context, AsyncTestContext};
    use tokio_util::sync::CancellationToken;

    struct AppCtx {
        handle: ConversationHandle,
    }

    impl AsyncTestContext for AppCtx {
        async fn setup() -> Self {
            init_logger("rust_lib_flutter_rust_demo=debug,hyper_util::client=info,reqwest=info");
            let area_code = "+86".to_string();
            let password = "284f3d09ea0695538e4ded1c1766d73a".to_string();
            let platform = 5;
            let token_info =
                login_async(area_code, "17764338283".to_string(), password, platform).await.expect("登录失败");
            let db_path = format!(
                "sqlite://{}/conv_sync_{}.db?mode=rwc",
                std::env::temp_dir().as_path().to_string_lossy(),
                token_info.user_id
            );
            let repo = Repository::create(&db_path).await.expect("创建测试数据库失败");
            let cfg = ConversationSyncerConfig {
                user_id: token_info.user_id.clone(),
                api_base_url: "http://localhost:10002".to_string(),
                token: token_info.im_token.clone(),
                db_path,
            };
            let (_tx, rx) = mpsc::unbounded_channel();
            let cancel = CancellationToken::new();
            let handle = ConversationHandle::with_listener_and_db_and_client(
                cfg,
                None,
                repo.pool.clone(),
                reqwest::Client::new(),
                rx,
                cancel,
            )
            .await
            .expect("创建 ConversationHandle 失败");
            AppCtx { handle }
        }

        async fn teardown(self) {
            let _ = self;
        }
    }

    #[test_context(AppCtx)]
    #[tokio::test]
    async fn test_conversation_incr_sync(ctx: &mut AppCtx) {
        ctx.handle.incr_sync_conversations().await.expect("增量同步失败");
    }

    #[test_context(AppCtx)]
    #[tokio::test]
    async fn test_conversation_full_sync(ctx: &mut AppCtx) {
        ctx.handle.full_sync().await.expect("全量同步失败");
        let conversations = ctx.handle.get_all_conversations().await.expect("获取会话失败");
        println!("数据库中当前会话信息数量: {}", conversations.len());
        for (i, conv) in conversations.iter().enumerate() {
            println!("会话#{}: {:?}", i + 1, conv);
            assert!(!conv.conversation_id.is_empty(), "conversation_id 不能为空");
            assert!(conv.conversation_type != 0, "conversation_type 不能为 0");
        }
    }
}
