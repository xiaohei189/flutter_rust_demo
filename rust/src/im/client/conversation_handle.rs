//! 会话处理模块（对齐 Go internal/conversation_msg）
//!
//! 合并原 conversation/service 的会话同步逻辑，通过命令通道接收消息同步器下发的会话命令。

use crate::im::http_client::Api;
use crate::im::client::callbacks::ClientCallbacks;
use crate::im::dao::black::LocalBlack;
use crate::im::dao::repository::Repository;
use crate::im::dao::user::LocalUser;
use crate::im::listener::FriendListener;
use crate::im::listener::{AdvancedMsgListener, ConversationListener, GroupListener, UserListener};
use crate::im::model::friend::BlackList;
use crate::im::http_client::group::GetIncrementalGroupMemberReq;
use crate::im::model::constant::sync_flag;
use crate::im::model::constant::RECEIVE_MESSAGE;
use crate::im::model::conversation::{ConversationSyncerConfig, LocalVersionSync};
use crate::im::model::group::{server_group_to_local, server_group_member_to_local};
use crate::im::model::message::{attached_info_apply_is_private, msg_handle_by_content_type_result};
use crate::im::model::LocalConversation;
use crate::im::LocalChatLog;
use anyhow::Result;
use openim_protocol::constant;
use openim_protocol::sdkws;
use sqlx::{Pool, Sqlite};
use std::collections::HashMap;
use std::collections::HashSet;
use std::sync::atomic::{AtomicI32, Ordering};
use std::sync::Arc;
use tokio::sync::mpsc;
use tokio::sync::RwLock;
use tokio_util::sync::CancellationToken;
use tracing::{debug, error, info, info_span, instrument, trace, warn};
use uuid::Uuid;

// ---------- 通知 body 解析（与 Go UnmarshalNotificationElem 对齐，服务端下发的为 JSON） ----------

#[derive(serde::Deserialize)]
struct RevokeTips {
    #[serde(rename = "conversationID", default)]
    conversation_id: String,
    #[serde(rename = "seq", default)]
    seq: i64,
    #[serde(rename = "revokerUserID", default)]
    revoker_user_id: String,
    #[serde(rename = "revokeTime", default)]
    revoke_time: i64,
    #[serde(rename = "sesstionType", default)]
    sesstion_type: i32,
    #[serde(rename = "isAdminRevoke", default)]
    is_admin_revoke: bool,
}

#[derive(serde::Deserialize)]
struct ReadReceiptTips {
    #[serde(rename = "markAsReadUserID", default)]
    mark_as_read_user_id: String,
    #[serde(rename = "conversationID", default)]
    conversation_id: String,
    #[serde(rename = "seqs", default)]
    seqs: Vec<i64>,
    #[serde(rename = "hasReadSeq", default)]
    has_read_seq: i64,
}

#[derive(serde::Deserialize)]
struct ClearConversationTipsRust {
    #[serde(rename = "conversationIDs", default)]
    conversation_i_ds: Vec<String>,
}

#[derive(serde::Deserialize)]
struct DeleteMsgsTipsRust {
    #[serde(rename = "conversationID", default)]
    conversation_id: String,
    #[serde(rename = "seqs", default)]
    seqs: Vec<i64>,
}

/// 用户信息变更通知 body（与 Go sdkws.UserInfoUpdatedTips、internal/user/notification.go userInfoUpdatedNotification 对齐）
#[derive(serde::Deserialize)]
struct UserInfoUpdatedTipsRust {
    #[serde(rename = "userID", default)]
    user_id: String,
}

// ---------- 命令类型（对齐 Go pkg/constant Cmd* 与 common.Cmd2Value） ----------

/// 新消息到达会话命令体（对齐 Go sdk_struct.CmdNewMsgComeToConversation）
#[derive(Clone, Debug)]
pub struct CmdNewMsgComeToConversation {
    pub msgs: HashMap<String, sdkws::PullMsgs>,
}

/// 具体命令类型（不含 tracing 上下文）
#[derive(Debug)]
pub enum ConvCmdKind {
    /// 新消息到达会话（constant.CmdNewMsgCome），参数与 Go doMsgNew(c2v) 中 c2v.Value 一致
    NewMsgCome(CmdNewMsgComeToConversation),
    /// 通知消息（constant.CmdNotification）
    Notification { msgs: HashMap<String, sdkws::PullMsgs> },
    /// 同步阶段标记（constant.CmdSyncFlag），取值为 sync_flag::*：MsgSyncBegin(1001)/MsgSyncProcessing(1002)/MsgSyncEnd(1003)/MsgSyncFailed(1004)/AppDataSyncStart(1005)/AppDataSyncFinish(1006)
    SyncFlag(i32),
    /// 同步数据（constant.CmdSyncData）
    SyncData,
    /// 重装后消息同步（constant.CmdMsgSyncInReinstall）
    MsgSyncInReinstall { msgs: HashMap<String, sdkws::PullMsgs>, total: i32 },
}

/// 命令信封：具体命令 + span，用于与调用方 tracing 串起来（接收端只对传入 span enter/instrument）
#[derive(Debug)]
pub struct ConvCmd {
    pub kind: ConvCmdKind,
    pub span: tracing::Span,
}

impl ConvCmd {
    /// 在传递位置创建 span，处理处只 enter/instrument
    pub fn with_span(kind: ConvCmdKind) -> Self {
        let span = match &kind {
            ConvCmdKind::NewMsgCome(ref c2v) => info_span!(parent: tracing::Span::current(), "conv_sync.command:NewMsgCome", convs = c2v.msgs.len()),
            ConvCmdKind::Notification { .. } => info_span!(parent: tracing::Span::current(), "conv_sync.command:Notification"),
            ConvCmdKind::SyncFlag(_) => info_span!(parent: tracing::Span::current(), "conv_sync.command:SyncFlag"),
            ConvCmdKind::SyncData => info_span!(parent: tracing::Span::current(), "conv_sync.command:SyncData"),
            ConvCmdKind::MsgSyncInReinstall { .. } => info_span!(parent: tracing::Span::current(), "conv_sync.command:MsgSyncInReinstall"),
        };
        Self { kind, span }
    }
}

// ---------- 会话处理器（原 ConversationSyncer 逻辑已全部并入，不再单独存在） ----------

/// 与 Go MaxSeqRecorder 对齐：按会话记录已处理条数，IsNewMsg(seq)=seq>get()，Incr(conv,1) 递增
pub struct MaxSeqRecorder {
    seqs: Arc<RwLock<HashMap<String, i64>>>,
}

impl MaxSeqRecorder {
    pub fn new() -> Self {
        Self {
            seqs: Arc::new(RwLock::new(HashMap::new())),
        }
    }
    pub async fn get(&self, conversation_id: &str) -> i64 {
        self.seqs.read().await.get(conversation_id).copied().unwrap_or(0)
    }
    /// 与 Go Incr(conversationID, num) 对齐：已处理条数 += num
    pub async fn incr(&self, conversation_id: &str, num: i64) {
        let mut g = self.seqs.write().await;
        *g.entry(conversation_id.to_string()).or_insert(0) += num;
    }
    pub async fn is_new_msg(&self, conversation_id: &str, seq: i64) -> bool {
        seq > self.get(conversation_id).await
    }
}

pub struct ConversationHandle {
    config: ConversationSyncerConfig,
    api: Api,
    repository: Repository,
    callbacks: Option<Arc<ClientCallbacks>>,
    cmd_rx: mpsc::UnboundedReceiver<ConvCmd>,
    cancel_token: CancellationToken,
    /// 与 Go conversationSyncMutex 对齐：GetAllConversationListDB -> diff -> 写会话 区段加锁
    conversation_sync_mutex: Arc<tokio::sync::Mutex<()>>,
    /// 与 Go maxSeqRecorder 对齐：判未读用
    max_seq_recorder: Arc<MaxSeqRecorder>,
    /// 重装消息同步已处理批数（与 Go c.msgOffset 对齐，用于 OnSyncServerProgress 10→100）
    msg_sync_offset: Arc<AtomicI32>,
}

impl ConversationHandle {
    /// 使用共享连接池与 HTTP 客户端创建（供 client 初始化时调用）
    pub async fn with_listener_and_db_and_client(
        config: ConversationSyncerConfig,
        callbacks: Option<Arc<ClientCallbacks>>,
        db: Pool<Sqlite>,
        http_client: reqwest::Client,
        cmd_rx: mpsc::UnboundedReceiver<ConvCmd>,
        cancel_token: CancellationToken,
    ) -> Result<Self> {
        let api = Api::new(http_client.clone(), config.api_base_url.clone(), config.user_id.clone(), &config.token);
        let repository = Repository::new(db, &config.user_id);
        Ok(Self {
            config,
            api,
            repository,
            callbacks,
            cmd_rx,
            cancel_token,
            conversation_sync_mutex: Arc::new(tokio::sync::Mutex::new(())),
            max_seq_recorder: Arc::new(MaxSeqRecorder::new()),
            msg_sync_offset: Arc::new(AtomicI32::new(0)),
        })
    }

    #[inline]
    fn conversation_listener(&self) -> Option<Arc<dyn ConversationListener>> {
        self.callbacks.as_ref().and_then(|c| c.conversation_listener.clone())
    }

    #[inline]
    fn advanced_msg_listener(&self) -> Option<Arc<dyn AdvancedMsgListener>> {
        self.callbacks.as_ref().and_then(|c| c.advanced_msg_listener.clone())
    }

    #[inline]
    fn user_listener(&self) -> Option<Arc<dyn UserListener>> {
        self.callbacks.as_ref().and_then(|c| c.user_listener.clone())
    }

    #[inline]
    fn friend_listener(&self) -> Option<Arc<dyn FriendListener>> {
        self.callbacks.as_ref().and_then(|c| c.friend_listener.clone())
    }

    #[inline]
    fn group_listener(&self) -> Option<Arc<dyn GroupListener>> {
        self.callbacks.as_ref().and_then(|c| c.group_listener.clone())
    }

    /// 与 Go getConversationIDBySessionType 对齐：单聊 si_排序双ID、群 sg_/g_、通知 sn_
    fn get_conversation_id_by_session_type(&self, source_id: &str, session_type: i32) -> String {
        match session_type {
            constant::SINGLE_CHAT_TYPE => {
                let mut v = vec![self.config.user_id.as_str(), source_id];
                v.sort();
                format!("si_{}_{}", v[0], v[1])
            }
            constant::READ_GROUP_CHAT_TYPE => format!("sg_{}", source_id),
            constant::NOTIFICATION_CHAT_TYPE => format!("sn_{}_{}", source_id, self.config.user_id),
            _ => format!("g_{}", source_id),
        }
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
                if let Ok(text_elem) = serde_json::from_str::<crate::im::model::message::TextElem>(&s) {
                    if !text_elem.content.is_empty() {
                        return text_elem.content;
                    }
                }
                if let Ok(v) = serde_json::from_str::<serde_json::Value>(&s) {
                    let content_str = v
                        .get("content")
                        .and_then(|c| c.as_str())
                        .map(String::from)
                        .or_else(|| {
                            v.get("text")
                                .and_then(|t| t.get("content"))
                                .and_then(|c| c.as_str())
                                .map(String::from)
                        });
                    if let Some(c) = content_str {
                        if !c.is_empty() {
                            return c;
                        }
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

    /// 构建供 on_recv_new_message / on_recv_online_only_message 回调使用的消息 JSON。
    /// 对 TEXT 类型将 content 转为已解析的字符串，避免前端收到字节数组时显示为空。
    fn build_msg_json_for_listener(msg: &sdkws::MsgData) -> String {
        let mut value = match serde_json::to_value(msg) {
            Ok(v) => v,
            Err(_) => return "{}".to_string(),
        };
        if msg.content_type == constant::TEXT {
            if let Ok(content_str) = msg_handle_by_content_type_result(&msg.content, msg.content_type) {
                value["content"] = serde_json::Value::String(content_str);
            }
        }
        serde_json::to_string(&value).unwrap_or_else(|_| "{}".to_string())
    }

    /// TYPING 消息专用回调：OnRecvTypingStatus + OnConversationUserInputStatusChanged（与 client.handle_single_message 一致）
    async fn trigger_typing_callbacks(&self, conversation_id: &str, msg: &sdkws::MsgData) {
        let mut msg_tip = String::new();
        if let Ok(json) = serde_json::from_slice::<serde_json::Value>(&msg.content) {
            if let Some(v) = json.get("msgTip").and_then(|v| v.as_str()) {
                msg_tip = v.to_string();
            }
        }
        let typing_json = serde_json::json!({
            "conversationID": conversation_id,
            "sendID": msg.send_id,
            "msgTip": msg_tip,
        });
        let typing_json_str = serde_json::to_string(&typing_json).unwrap_or_default();
        if let Some(l) = self.conversation_listener() {
            l.on_conversation_user_input_status_changed(typing_json_str).await;
        }
    }

    /// 与 Go handleExceptionMessages 对齐：分类并改写 exception 消息的 client_msg_id（前缀+随机后缀），避免主键冲突
    fn handle_exception_messages(existing: Option<&LocalChatLog>, log: &mut LocalChatLog, _user_id: &str) {
        let prefix = match existing {
            None => {
                if log.status == constant::MSG_STATUS_HAS_DELETED {
                    if log.client_msg_id.is_empty() {
                        log.client_msg_id = Uuid::new_v4().to_string();
                        format!("[SEQ_GAP_+{}]", log.seq)
                    } else {
                        "[DELETED]".to_string()
                    }
                } else {
                    "[UNKNOWN]".to_string()
                }
            }
            Some(ex) => {
                if ex.seq == log.seq {
                    "[SEQ_DUP]".to_string()
                } else {
                    "[CLIENT_DUP]".to_string()
                }
            }
        };
        let random_suffix = format!("_{}", Uuid::new_v4().to_string().replace('-', "").chars().take(8).collect::<String>());
        log.status = constant::MSG_STATUS_HAS_DELETED;
        log.client_msg_id = format!("{}{}{}", prefix, log.client_msg_id, random_suffix);
    }

    /// 从新消息构建会话条目（用于 do_msg_new 的 conversation_set，对齐 Go 中 build lc）
    /// LatestMsg 与 Go 一致存整条消息 JSON（StructToJsonString(msg)）
    /// unread_count 只存本批增量（unread_delta），diff 时会与 local 的 unread 相加，若存 existing+delta 会导致重复累加
    fn build_lc_from_msg(conversation_id: &str, msg: &sdkws::MsgData, is_self: bool, unread_delta: i32, _existing_unread: i32) -> LocalConversation {
        let latest = serde_json::to_string(msg).unwrap_or_else(|_| String::new());
        let send_time = if msg.send_time > 0 { msg.send_time } else { msg.create_time };
        let (user_id, show_name, face_url) = if is_self {
            (msg.recv_id.clone(), String::new(), String::new())
        } else {
            (msg.send_id.clone(), msg.sender_nickname.clone(), msg.sender_face_url.clone())
        };
        LocalConversation {
            conversation_id: conversation_id.to_string(),
            conversation_type: msg.session_type,
            user_id,
            group_id: msg.group_id.clone(),
            show_name,
            face_url,
            latest_msg: latest,
            latest_msg_send_time: send_time,
            unread_count: unread_delta.max(0),
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
    }

    /// 合并到会话集合（对齐 Go updateConversation(lc, conversationSet)）
    fn update_conversation_in_set(lc: LocalConversation, set: &mut HashMap<String, LocalConversation>) {
        if let Some(old) = set.get_mut(&lc.conversation_id) {
            old.unread_count = (old.unread_count + lc.unread_count).max(0);
            if lc.latest_msg_send_time > old.latest_msg_send_time {
                old.latest_msg = lc.latest_msg.clone();
                old.latest_msg_send_time = lc.latest_msg_send_time;
            }
        } else {
            set.insert(lc.conversation_id.clone(), lc);
        }
    }

    async fn delete_conversation(&self, conversation_id: &str) -> Result<()> {
        self.repository.conversation.delete_conversation(conversation_id).await
    }

    /// 获取总未读消息数
    pub async fn get_total_unread_count(&self) -> Result<i32> {
        self.repository.conversation.get_total_unread_count().await
    }

    /// 与 Go SyncLoginUserInfo / SyncLoginUserInfoWithoutNotice 对齐：拉取当前登录用户并落库；with_notice 时若昵称/头像变化则 OnSelfInfoUpdated + 会话/消息更新
    #[instrument(skip(self), fields(with_notice = with_notice))]
    pub async fn sync_login_user_info(&self, with_notice: bool) -> Result<()> {
        let Some(remote) = self.api.user.get_login_user_from_server().await? else {
            trace!("sync_login_user_info: 服务端未返回当前用户");
            return Ok(());
        };
        let old_local = self.repository.user.get_login_user(&self.config.user_id).await?;
        let new_local = LocalUser {
            user_id: remote.user_id.clone(),
            nickname: remote.nickname.clone(),
            face_url: remote.face_url.clone(),
            create_time: remote.create_time,
            app_manger_level: remote.app_manger_level,
            ex: remote.ex.clone(),
            attached_info: remote.attached_info.clone(),
            global_recv_msg_opt: remote.global_recv_msg_opt,
        };
        self.repository.user.upsert_login_user(&new_local).await?;

        if !with_notice {
            return Ok(());
        }
        let changed = old_local.as_ref().map_or(true, |o| o.nickname != new_local.nickname || o.face_url != new_local.face_url);
        if !changed {
            return Ok(());
        }
        let server_json = serde_json::json!({
            "userID": new_local.user_id,
            "nickname": new_local.nickname,
            "faceURL": new_local.face_url,
            "createTime": new_local.create_time,
            "appMangerLevel": new_local.app_manger_level,
            "ex": new_local.ex,
            "attachedInfo": new_local.attached_info,
            "globalRecvMsgOpt": new_local.global_recv_msg_opt,
        });
        if let Some(l) = self.user_listener() {
            l.on_self_info_updated(server_json.to_string()).await;
        }
        let conv_id = self.get_conversation_id_by_session_type(&self.config.user_id, constant::SINGLE_CHAT_TYPE);
        let _ = self.repository.conversation.update_show_name_and_face_url(&conv_id, &new_local.nickname, &new_local.face_url).await;
        if let Ok(ids) = self.repository.conversation.get_all_single_conversation_ids().await {
            for cid in ids {
                let _ = self.repository.message.update_sender_face_url_and_nickname(&cid, &self.config.user_id, &new_local.face_url, &new_local.nickname).await;
            }
        }
        if let Ok(convs) = self.repository.conversation.get_all_conversations().await {
            let changed_list: Vec<&LocalConversation> = convs.iter().filter(|c| c.conversation_id == conv_id).collect();
            if let Some(conv) = changed_list.first() {
                if let Ok(json) = serde_json::to_string(&conv) {
                    if let Some(l) = self.conversation_listener() {
                        l.on_conversation_changed(json).await;
                    }
                }
            }
        }
        Ok(())
    }

    /// 基于服务器的 MaxSeq / HasReadSeq 校正本地未读数
    #[instrument(skip(self))]
    pub async fn sync_unread_by_seq(&self) -> Result<()> {
        trace!("开始按 Seq 校正未读数");
        let mut local_conversations = self.get_all_conversations().await?;
        let mut local_map: HashMap<String, LocalConversation> = HashMap::new();
        for conv in local_conversations.drain(..) {
            local_map.insert(conv.conversation_id.clone(), conv);
        }
        let seqs = self.api.conversation.get_has_read_and_max_seqs().await?;
        if seqs.is_empty() {
            trace!("服务器未返回会话 Seq 信息 跳过未读数校正");
            return Ok(());
        }
        let mut changed_conversations: Vec<LocalConversation> = Vec::new();
        let mut new_conversations: Vec<LocalConversation> = Vec::new();
        let mut missing_convs: Vec<(String, (i64, i64))> = Vec::new();
        trace!("开始校正未读数 服务器返回 {} 个会话的 Seq 信息", seqs.len());
        for (conv_id, (max_seq, has_read_seq)) in seqs.into_iter() {
            let unread = (max_seq - has_read_seq).max(0) as i32;
            if let Some(mut local) = local_map.remove(&conv_id) {
                if local.unread_count != unread || local.max_seq != max_seq {
                    trace!(
                        "校正会话未读数 conversationID={} 本地未读数 {}->{} maxSeq {}->{} hasReadSeq={}",
                        conv_id,
                        local.unread_count,
                        unread,
                        local.max_seq,
                        max_seq,
                        has_read_seq
                    );
                    local.unread_count = unread;
                    local.max_seq = max_seq;
                    self.upsert_conversation(&local).await?;
                    changed_conversations.push(local);
                }
            } else {
                trace!(
                    "Seq 按 Seq 校正未读数时发现本地不存在的会话 conversationID={} maxSeq={} hasReadSeq={} unreadCount={}",
                    conv_id,
                    max_seq,
                    has_read_seq,
                    unread
                );
                missing_convs.push((conv_id, (max_seq, has_read_seq)));
            }
        }

        if !missing_convs.is_empty() {
            trace!("Seq 发现本地缺失会话 {} 个 尝试从服务器补齐详情", missing_convs.len());
            if let Ok(all_resp) = self.api.conversation.get_all_conversations().await {
                let server_map: HashMap<String, LocalConversation> = all_resp.conversations.iter().map(|c| (c.conversation_id.clone(), c.clone())).collect();
                for (conv_id, (max_seq, has_read_seq)) in missing_convs.into_iter() {
                    if let Some(mut conv) = server_map.get(&conv_id).cloned() {
                        let unread = (max_seq - has_read_seq).max(0) as i32;
                        conv.unread_count = unread;
                        conv.max_seq = max_seq;
                        self.upsert_conversation(&conv).await?;
                        new_conversations.push(conv);
                    } else {
                        warn!("按 Seq 校正时服务器会话列表中也不存在会话: {} (maxSeq={}, hasReadSeq={})", conv_id, max_seq, has_read_seq);
                    }
                }
            }
        }

        if !new_conversations.is_empty() {
            let json = serde_json::to_string(&new_conversations).unwrap_or_else(|_| "[]".to_string());
            if let Some(listener) = self.conversation_listener() {
                listener.on_new_conversation(json).await;
            }
        }

        if !changed_conversations.is_empty() {
            let json = serde_json::to_string(&changed_conversations).unwrap_or_else(|_| "[]".to_string());
            if let Some(listener) = self.conversation_listener() {
                listener.on_conversation_changed(json).await;
            }
        }

        if !new_conversations.is_empty() || !changed_conversations.is_empty() {
            if let Ok(total_unread) = self.get_total_unread_count().await {
                if let Some(listener) = self.conversation_listener() {
                    listener.on_total_unread_message_count_changed(total_unread).await;
                }
            }
        }
        trace!("Seq 按 Seq 校正未读数完成");
        Ok(())
    }

    #[instrument(skip(self, server_conversations, local_conversations, seqs_map), name = "conv.sync_conversations", fields(server_n = server_conversations.len(), local_n = local_conversations.len()))]
    async fn sync_conversations(&self, server_conversations: Vec<LocalConversation>, local_conversations: Vec<LocalConversation>, seqs_map: Option<&HashMap<String, (i64, i64)>>) -> Result<()> {
        info!(
            "[conversation_handle] 开始同步会话 服务器会话数={} 本地会话数={}",
            server_conversations.len(),
            local_conversations.len()
        );
        let local_map: HashMap<String, LocalConversation> = local_conversations.into_iter().map(|c| (c.conversation_id.clone(), c)).collect();
        let mut server_map: HashMap<String, LocalConversation> = server_conversations.into_iter().map(|c| (c.conversation_id.clone(), c)).collect();
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
                let need_update = !self.conversations_equal(local_conv, &server_conv) || local_conv.unread_count != server_conv.unread_count || local_conv.max_seq != server_conv.max_seq;
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
            if let Some(listener) = self.conversation_listener() {
                listener.on_new_conversation(json).await;
            }
        }
        if !changed_conversations.is_empty() {
            let json = serde_json::to_string(&changed_conversations).unwrap_or_else(|_| "[]".to_string());
            if let Some(listener) = self.conversation_listener() {
                listener.on_conversation_changed(json).await;
            }
        }
        if insert_count > 0 || update_count > 0 || delete_count > 0 {
            if let Ok(total_unread) = self.get_total_unread_count().await {
                if let Some(listener) = self.conversation_listener() {
                    listener.on_total_unread_message_count_changed(total_unread).await;
                }
            }
        }
        info!("[conversation_handle] 会话同步完成 新增={} 更新={} 删除={}", insert_count, update_count, delete_count);
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
            return self.full_sync().await;
        }
        let all_placeholder = local_conversations
            .iter()
            .all(|c| c.show_name.is_empty() && c.face_url.is_empty() && c.latest_msg.is_empty() && c.latest_msg_send_time == 0);
        if all_placeholder {
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
        let resp = match self.api.conversation.get_incremental_conversations(version, &version_id).await {
            Ok(r) => r,
            Err(e) => return Err(e),
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
        let _ = self.sync_unread_by_seq().await;
        Ok(())
    }

    /// 全量同步会话（供测试与内部调用）。同步进度/开始/结束仅由 sync_flag() 触发，此处不再调用 listener。
    #[instrument(skip(self), name = "conv.full_sync")]
    pub async fn full_sync(&self) -> Result<()> {
        let resp = match self.api.conversation.get_all_conversations().await {
            Ok(r) => r,
            Err(e) => return Err(e),
        };
        let server_conversations: Vec<LocalConversation> = resp.conversations.clone();
        let local_conversations = self.get_all_conversations().await?;
        let seqs_map = self.api.conversation.get_has_read_and_max_seqs().await.ok();
        self.sync_conversations(server_conversations, local_conversations, seqs_map.as_ref()).await?;
        let new_version = LocalVersionSync {
            table_name: "local_conversations".to_string(),
            entity_id: self.config.user_id.clone(),
            version: 1,
            version_id: Uuid::new_v4().to_string(),
        };
        self.save_version_sync(&new_version).await?;
        let _ = self.sync_unread_by_seq().await;
        Ok(())
    }

    /// 获取会话列表（分页）
    pub async fn get_conversation_list_split(&self, offset: usize, count: usize) -> Result<Vec<LocalConversation>> {
        let mut list = self.get_all_conversations().await?;
        list.sort_by(|a, b| match (a.is_pinned, b.is_pinned) {
            (true, false) => std::cmp::Ordering::Less,
            (false, true) => std::cmp::Ordering::Greater,
            _ => {
                let time_a = a.latest_msg_send_time.max(a.draft_text_time);
                let time_b = b.latest_msg_send_time.max(b.draft_text_time);
                time_b.cmp(&time_a)
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

    /// 新消息到达会话（对齐 Go doMsgNew(c2v)）
    ///
    /// 差异表与补齐计划（相对 Go）：
    /// - GetMessage + self/others 分支：已补齐（get_message、updateMessage/exception/insert/conversation_set）
    /// - 空 conversation_id 校验：已补齐
    /// - faceURLAndNicknameHandle：已补齐（合并 self+others，可扩展补头像昵称）
    /// - conversation_set + diff + batch_upsert + doUpdateConversation：已补齐
    /// - 未读 is_trigger_unread_count：已补齐（他人新消息且 seq 更新则置 true，最后触发 TotalUnreadMessageChanged）
    /// - new_messages 排序：已补齐（按 send_time）
    /// - 仅对 status==HAS_DELETED 触发 on_msg_deleted，exception 统一打日志
    /// - msgHandleByContentType / isNotPrivate：已补齐（content 按 contentType 解析落库，attached_info 写 isPrivateChat）
    /// - 隐藏会话 ph：未实现（可后续按需补）
    #[instrument(skip(self, c2v), fields(convs = c2v.msgs.len()))]
    pub async fn do_msg_new(&self, c2v: CmdNewMsgComeToConversation) -> Result<()> {
        let all_msg = &c2v.msgs;

        let mut insert_msg: HashMap<String, Vec<LocalChatLog>> = HashMap::new();
        let mut update_msg: HashMap<String, Vec<LocalChatLog>> = HashMap::new();
        let mut exception_msg: Vec<String> = Vec::new();
        let mut new_messages: Vec<(String, sdkws::MsgData, bool)> = Vec::new();
        let mut online_map: HashSet<(String, String)> = HashSet::new();
        let mut conversation_set: HashMap<String, LocalConversation> = HashMap::new();
        let mut is_trigger_unread_count = false;

        for (conversation_id, msgs) in all_msg {
            let mut insert_message: Vec<LocalChatLog> = Vec::new();
            let mut self_insert_message: Vec<LocalChatLog> = Vec::new();
            let mut others_insert_message: Vec<LocalChatLog> = Vec::new();
            let mut update_message: Vec<LocalChatLog> = Vec::new();

            for v in &msgs.msgs {
                // 与 Go 一致：conversationID 空在消息循环内检查，仅跳过该条
                if conversation_id.is_empty() {
                    warn!("[conversation_handle] do_msg_new conversationID is empty, skip msg");
                    continue;
                }
                let is_history = v.options.get(constant::IS_HISTORY).copied().unwrap_or(true);
                let is_unread_count = v.options.get(constant::IS_UNREAD_COUNT).copied().unwrap_or(true);
                let is_conversation_update = v.options.get(constant::IS_CONVERSATION_UPDATE).copied().unwrap_or(true);
                let is_not_private = v.options.get(constant::IS_NOT_PRIVATE).copied().unwrap_or(true);
                let is_sender_conversation_update = v.options.get(constant::IS_SENDER_CONVERSATION_UPDATE).copied().unwrap_or(true);

                // 与 Go 一致：不在此处跳过 TYPING，TYPING 可进入 new_messages，后续由 typing 回调和 listener 内按 contentType 处理
                if v.status == constant::MSG_STATUS_HAS_DELETED {
                    let mut log = LocalChatLog::from((v, conversation_id.to_string()));
                    log.status = constant::MSG_STATUS_HAS_DELETED;
                    log.attached_info = attached_info_apply_is_private(&log.attached_info, is_not_private);
                    Self::handle_exception_messages(None, &mut log, &self.config.user_id);
                    exception_msg.push(serde_json::to_string(&log).unwrap_or_else(|_| "{}".to_string()));
                    insert_message.push(log);
                    continue;
                }

                let mut log = LocalChatLog::from((v, conversation_id.to_string()));
                log.status = constant::MSG_STATUS_SEND_SUCCESS;
                // 与 Go 一致：解析失败则跳过该条（msgHandleByContentType err continue）
                let content = match msg_handle_by_content_type_result(&v.content, v.content_type) {
                    Ok(s) => s,
                    Err(e) => {
                        warn!("[conversation_handle] Parsing data error (skip msg): {} type={} msg={:?}", e, v.content_type, v);
                        continue;
                    }
                };
                log.content = content;
                log.attached_info = attached_info_apply_is_private(&log.attached_info, is_not_private);

                if !is_history {
                    online_map.insert((v.client_msg_id.clone(), v.server_msg_id.clone()));
                    new_messages.push((conversation_id.clone(), v.clone(), true));
                }

                let existing_msg: Option<LocalChatLog> = self.repository.message.get_message(conversation_id, &v.client_msg_id).await.ok().flatten();

                if v.send_id == self.config.user_id {
                    if let Some(ref existing) = existing_msg {
                        if existing.seq == 0 {
                            if !is_conversation_update {
                                log.status = constant::MSG_STATUS_FILTERED;
                            }
                            update_message.push(log);
                        } else {
                            Self::handle_exception_messages(Some(existing), &mut log, &self.config.user_id);
                            exception_msg.push(serde_json::to_string(&log).unwrap_or_else(|_| "{}".to_string()));
                            insert_message.push(log);
                        }
                    } else {
                        if is_conversation_update && is_sender_conversation_update {
                            let lc = Self::build_lc_from_msg(conversation_id, v, true, 0, 0);
                            Self::update_conversation_in_set(lc, &mut conversation_set);
                        }
                        new_messages.push((conversation_id.clone(), v.clone(), false));
                        if is_history {
                            self_insert_message.push(log);
                        }
                    }
                } else {
                    if let Some(ref existing) = existing_msg {
                        Self::handle_exception_messages(Some(existing), &mut log, &self.config.user_id);
                        exception_msg.push(serde_json::to_string(&log).unwrap_or_else(|_| "{}".to_string()));
                        insert_message.push(log);
                    } else {
                        let existing_conv = self.repository.conversation.get_conversation_by_id(conversation_id).await.ok().flatten();
                        let existing_unread = existing_conv.as_ref().map(|c| c.unread_count).unwrap_or(0);
                        let is_new_msg = self.max_seq_recorder.is_new_msg(conversation_id, v.seq).await;
                        if is_new_msg {
                            self.max_seq_recorder.incr(conversation_id, 1).await;
                        }
                        let unread_delta = if is_unread_count && is_new_msg {
                            is_trigger_unread_count = true;
                            1
                        } else {
                            0
                        };
                        let lc = Self::build_lc_from_msg(conversation_id, v, false, unread_delta, existing_unread);
                        if is_conversation_update {
                            Self::update_conversation_in_set(lc, &mut conversation_set);
                        }
                        new_messages.push((conversation_id.clone(), v.clone(), false));
                        if is_history {
                            others_insert_message.push(log);
                        }
                    }
                }
            }

            let handled = self.face_url_and_nickname_handle(self_insert_message, others_insert_message, conversation_id).await;
            let mut merged = insert_message;
            merged.extend(handled);
            if !merged.is_empty() {
                insert_msg.insert(conversation_id.clone(), merged);
            }
            if !update_message.is_empty() {
                update_msg.insert(conversation_id.clone(), update_message);
            }
        }

        // 与 Go 对齐：锁覆盖 get_all -> diff -> 写消息 -> 写会话 整段；GetAllConversationListDB 失败时 Go 只打 log 继续用空 list
        let _guard = self.conversation_sync_mutex.lock().await;
        let list = match self.repository.conversation.get_all_conversations().await {
            Ok(l) => l,
            Err(e) => {
                warn!("[conversation_handle] get_all_conversations failed (align Go: continue with empty list): {}", e);
                vec![]
            }
        };
        let mut local_map: HashMap<String, LocalConversation> = HashMap::new();
        for c in list {
            local_map.insert(c.conversation_id.clone(), c);
        }
        let (conversation_changed_set, mut new_conversation_set) = Self::diff_conversations(&local_map, &conversation_set);
        // 与 Go 一致：batchAddFaceURLAndName 失败则 nc 不填入，新会话不写入
        let batch_face_ok = self.batch_add_face_url_and_name(&mut new_conversation_set).await.is_ok();
        let new_list: Vec<LocalConversation> = if batch_face_ok {
            new_conversation_set.values().cloned().collect()
        } else {
            warn!("[conversation_handle] batch_add_face_url_and_name failed, skip writing new conversations (align Go)");
            vec![]
        };
        let changed_list: Vec<LocalConversation> = conversation_changed_set.values().cloned().collect();

        // 与 Go batchUpdateMessageList 一致：GetConversation 失败则整会话跳过；更新消息后若为会话最新一条则更新会话 LatestMsg 并 doUpdateConversation(AddConOrUpLatMsg)
        for (conversation_id, list) in update_msg.iter() {
            let mut conv = match self.repository.conversation.get_conversation_by_id(conversation_id).await {
                Ok(Some(c)) => c,
                Ok(None) => {
                    warn!("[conversation_handle] GetConversation err conversationID={} (skip this conv)", conversation_id);
                    continue;
                }
                Err(e) => {
                    warn!("[conversation_handle] GetConversation err conversationID={} err={} (skip this conv)", conversation_id, e);
                    continue;
                }
            };
            let latest_client_msg_id: Option<String> = serde_json::from_str::<serde_json::Value>(&conv.latest_msg)
                .ok()
                .and_then(|root| root.get("clientMsgID").or_else(|| root.get("client_msg_id")).and_then(|v| v.as_str().map(String::from)));
            for log in list {
                if let Err(e) = self.repository.message.update_message(conversation_id, log).await {
                    warn!("[conversation_handle] do_msg_new update_message err: {}", e);
                    continue;
                }
                if latest_client_msg_id.as_deref() == Some(log.client_msg_id.as_str()) {
                    let mut latest_value: serde_json::Value = match serde_json::from_str(&conv.latest_msg) {
                        Ok(v) => v,
                        Err(_) => continue,
                    };
                    if let Some(obj) = latest_value.as_object_mut() {
                        obj.insert("serverMsgID".to_string(), serde_json::Value::String(log.server_msg_id.clone()));
                        obj.insert("seq".to_string(), serde_json::Value::Number(serde_json::Number::from(log.seq)));
                        obj.insert("sendTime".to_string(), serde_json::Value::Number(serde_json::Number::from(log.send_time)));
                        obj.insert("status".to_string(), serde_json::Value::Number(serde_json::Number::from(log.status)));
                    }
                    let new_latest_msg = serde_json::to_string(&latest_value).unwrap_or_else(|_| conv.latest_msg.clone());
                    if let Err(e) = self.repository.conversation.update_conversation_latest_msg(conversation_id, &new_latest_msg, log.send_time).await {
                        warn!("[conversation_handle] update_conversation_latest_msg err: {}", e);
                    } else {
                        conv.latest_msg = new_latest_msg;
                        conv.latest_msg_send_time = log.send_time;
                        if let Some(l) = self.conversation_listener() {
                            let args = serde_json::to_string(&[conv.clone()]).unwrap_or_else(|_| "[]".to_string());
                            l.on_conversation_changed(args).await;
                        }
                    }
                }
            }
        }
        for (conversation_id, list) in &insert_msg {
            if let Err(e) = self.repository.message.batch_insert_message_list(conversation_id, list).await {
                warn!(
                    "[conversation_handle] do_msg_new batch_insert_message_list failed conv={} count={} err={}",
                    conversation_id,
                    list.len(),
                    e
                );
            } else {
                info!("[conversation_handle] do_msg_new 落库成功 conv={} count={}", conversation_id, list.len());
            }
        }

        // 与 Go 一致：GetHiddenConversationList 在写消息之后调用，再算 ph_changed / ph_new
        let h_list = self.repository.conversation.get_hidden_conversation_list().await.unwrap_or_default();
        let (ph_changed_list, ph_new_list) = if batch_face_ok {
            let mut ph_changed_list: Vec<LocalConversation> = Vec::new();
            for h in &h_list {
                if let Some(nc) = new_conversation_set.get(&h.conversation_id) {
                    let mut merged = nc.clone();
                    merged.recv_msg_opt = h.recv_msg_opt;
                    merged.group_at_type = h.group_at_type;
                    merged.is_pinned = h.is_pinned;
                    merged.is_private_chat = h.is_private_chat;
                    if merged.is_private_chat {
                        merged.burn_duration = h.burn_duration;
                    }
                    if h.unread_count != 0 {
                        merged.unread_count = h.unread_count;
                    }
                    merged.is_not_in_group = h.is_not_in_group;
                    merged.attached_info = h.attached_info.clone();
                    merged.ex = h.ex.clone();
                    merged.is_msg_destruct = h.is_msg_destruct;
                    merged.msg_destruct_time = h.msg_destruct_time;
                    ph_changed_list.push(merged);
                }
            }
            let ph_changed_ids: HashSet<String> = ph_changed_list.iter().map(|c| c.conversation_id.clone()).collect();
            let ph_new_list: Vec<LocalConversation> = new_list.iter().filter(|c| !ph_changed_ids.contains(&c.conversation_id)).cloned().collect();
            (ph_changed_list, ph_new_list)
        } else {
            (vec![], vec![])
        };

        // 与 Go 对齐：BatchUpdate(cc+phChanged)，BatchInsert(phNew)；失败打 log（align Go log.ZError）
        let to_update: Vec<LocalConversation> = changed_list.iter().chain(ph_changed_list.iter()).cloned().collect();
        if !to_update.is_empty() {
            if let Err(e) = self.repository.conversation.batch_update_conversation_list(&to_update).await {
                warn!("[conversation_handle] insert changed conversation err (align Go): {}", e);
            }
        }
        if !ph_new_list.is_empty() {
            if let Err(e) = self.repository.conversation.batch_insert_conversation_list(&ph_new_list).await {
                warn!("[conversation_handle] insert new conversation err (align Go): {}", e);
            }
        }
        drop(_guard);

        // newMessage：与 Go 一致，含 GetBackground/RecvMsgOpt 分支，且对 self 消息也回调
        new_messages.sort_by(|a, b| a.1.send_time.cmp(&b.1.send_time));
        let recv_opt_map: HashMap<String, i32> = changed_list.iter().chain(new_list.iter()).map(|c| (c.conversation_id.clone(), c.recv_msg_opt)).collect();
        let get_background = self.config.get_background.as_ref().map(|f| f()).unwrap_or(false);
        if get_background {
            if let Ok(Some(u)) = self.repository.user.get_login_user(&self.config.user_id).await {
                if u.global_recv_msg_opt != RECEIVE_MESSAGE {
                    // 全局不接收则不回调
                } else if let Some(listener) = self.advanced_msg_listener() {
                    for (conv_id, msg, _) in &new_messages {
                        if msg.content_type == constant::TYPING {
                            continue;
                        }
                        if recv_opt_map.get(conv_id).copied().unwrap_or(0) == RECEIVE_MESSAGE {
                            let msg_json = serde_json::to_string(msg).unwrap_or_else(|_| "{}".to_string());
                            listener.on_recv_offline_new_message(msg_json).await;
                        }
                    }
                }
            }
        } else {
            if let Some(listener) = self.advanced_msg_listener() {
                for (_conv_id, msg, in_online_map) in &new_messages {
                    if msg.content_type == constant::TYPING {
                        continue;
                    }
                    let msg_json = Self::build_msg_json_for_listener(msg);
                    if *in_online_map {
                        listener.on_recv_online_only_message(msg_json).await;
                    } else {
                        listener.on_recv_new_message(msg_json).await;
                    }
                }
            }
        }

        if !new_list.is_empty() {
            if let Some(l) = self.conversation_listener() {
                let args = serde_json::to_string(&new_list).unwrap_or_default();
                l.on_new_conversation(args).await;
            }
        }
        if !changed_list.is_empty() {
            if let Some(l) = self.conversation_listener() {
                let args = serde_json::to_string(&changed_list).unwrap_or_default();
                l.on_conversation_changed(args).await;
            }
        }
        if is_trigger_unread_count {
            if let Some(l) = self.conversation_listener() {
                let total = self.get_total_unread_count().await.unwrap_or(0);
                l.on_total_unread_message_count_changed(total).await;
            }
        }

        for (conv_id, pull) in all_msg {
            for msg in &pull.msgs {
                if msg.content_type == constant::TYPING {
                    self.trigger_typing_callbacks(conv_id, msg).await;
                }
            }
        }

        for msg_json in &exception_msg {
            warn!("[conversation_handle] exceptionMsg show: {}", msg_json);
        }

        Ok(())
    }

    /// 与 Go GetUserInfoWithCache 对齐：先本地，缺或昵称/头像为空则拉服务端并落库后返回
    async fn get_user_info_with_cache(&self, user_id: &str) -> Result<Option<LocalUser>> {
        let local = self.repository.user.get_login_user(user_id).await?;
        if let Some(ref u) = local {
            if !u.nickname.is_empty() && !u.face_url.is_empty() {
                return Ok(local);
            }
        }
        if let Ok(resp) = self.api.user.get_users_info(vec![user_id.to_string()]).await {
            for remote in resp.users_info {
                let local_user = LocalUser {
                    user_id: remote.user_id,
                    nickname: remote.nickname,
                    face_url: remote.face_url,
                    create_time: remote.create_time,
                    app_manger_level: remote.app_manger_level,
                    ex: remote.ex,
                    attached_info: remote.attached_info,
                    global_recv_msg_opt: remote.global_recv_msg_opt,
                };
                let _ = self.repository.user.upsert_login_user(&local_user).await;
                return Ok(Some(local_user));
            }
        }
        Ok(local)
    }

    /// 与 Go batchAddFaceURLAndName 对齐：对新会话补 face_url/show_name；返回 Err 时调用方不写入 nc（新会话不落库）。
    /// 与 Go 一致：仅远程/关键步骤失败才返回 Err；本地 DB 查不到（None）或查询出错不导致整段失败，避免因本地无好友/用户/群数据就跳过新会话写入。
    async fn batch_add_face_url_and_name(&self, new_conversation_set: &mut HashMap<String, LocalConversation>) -> Result<()> {
        for conv_id in new_conversation_set.keys().cloned().collect::<Vec<_>>() {
            let Some(nc) = new_conversation_set.get_mut(&conv_id) else { continue };
            if nc.conversation_type == constant::SINGLE_CHAT_TYPE || nc.conversation_type == constant::NOTIFICATION_CHAT_TYPE {
                if let Ok(Some(f)) = self.repository.friend.get_friend_by_friend_user_id(&nc.user_id).await {
                    if let Some(u) = f.friend_user {
                        if !u.face_url.is_empty() {
                            nc.face_url = u.face_url;
                        }
                        if !u.nickname.is_empty() {
                            nc.show_name = u.nickname;
                        }
                    }
                }
                if nc.face_url.is_empty() || nc.show_name.is_empty() {
                    if let Ok(Some(u)) = self.get_user_info_with_cache(&nc.user_id).await {
                        if nc.face_url.is_empty() && !u.face_url.is_empty() {
                            nc.face_url = u.face_url.clone();
                        }
                        if nc.show_name.is_empty() && !u.nickname.is_empty() {
                            nc.show_name = u.nickname.clone();
                        }
                    }
                }
                if nc.show_name.is_empty() {
                    nc.show_name = "UserNotFound".to_string();
                }
            } else if nc.conversation_type == constant::READ_GROUP_CHAT_TYPE {
                if let Ok(Some(g)) = self.repository.group.get_group_info_by_group_id(&nc.group_id).await {
                    if !g.face_url.is_empty() {
                        nc.face_url = g.face_url.clone();
                    }
                    if !g.group_name.is_empty() {
                        nc.show_name = g.group_name.clone();
                    }
                }
            }
            if nc.face_url.is_empty() || nc.show_name.is_empty() {
                if let Ok(Some(existing)) = self.repository.conversation.get_conversation_by_id(&conv_id).await {
                    if nc.face_url.is_empty() && !existing.face_url.is_empty() {
                        nc.face_url = existing.face_url.clone();
                    }
                    if nc.show_name.is_empty() && !existing.show_name.is_empty() {
                        nc.show_name = existing.show_name.clone();
                    }
                }
            }
        }
        Ok(())
    }

    /// 与 Go faceURLAndNicknameHandle 对齐：合并 self + others，并从会话补 others 的头像/昵称
    async fn face_url_and_nickname_handle(&self, self_insert: Vec<LocalChatLog>, others_insert: Vec<LocalChatLog>, conversation_id: &str) -> Vec<LocalChatLog> {
        let mut out = self_insert;
        if let Ok(Some(lc)) = self.repository.conversation.get_conversation_by_id(conversation_id).await {
            if !lc.face_url.is_empty() || !lc.show_name.is_empty() {
                let mut others = others_insert;
                for log in &mut others {
                    if !lc.face_url.is_empty() {
                        log.sender_face_url = lc.face_url.clone();
                    }
                    if !lc.show_name.is_empty() {
                        log.sender_nickname = lc.show_name.clone();
                    }
                }
                out.extend(others);
                return out;
            }
        }
        out.extend(others_insert);
        out
    }

    /// 与 Go diff 对齐：local 为当前库中会话，generated 为本批产生的会话集；输出 cc（变更）、nc（新）
    fn diff_conversations(local: &HashMap<String, LocalConversation>, generated: &HashMap<String, LocalConversation>) -> (HashMap<String, LocalConversation>, HashMap<String, LocalConversation>) {
        let mut cc: HashMap<String, LocalConversation> = HashMap::new();
        let mut nc: HashMap<String, LocalConversation> = HashMap::new();
        for (id, v) in generated {
            if let Some(local_c) = local.get(id) {
                let mut merged = local_c.clone();
                merged.unread_count = (merged.unread_count + v.unread_count).max(0);
                if v.latest_msg_send_time > merged.latest_msg_send_time {
                    merged.latest_msg = v.latest_msg.clone();
                    merged.latest_msg_send_time = v.latest_msg_send_time;
                }
                cc.insert(id.clone(), merged);
            } else {
                nc.insert(id.clone(), v.clone());
            }
        }
        (cc, nc)
    }

    /// 通知消息处理（Go doNotificationManager）：按 ContentType 分发，与 doNotification 一致
    #[instrument(skip(self, msgs), name = "conv.do_notification_manager", fields(convs = msgs.len()))]
    pub async fn do_notification_manager(&self, msgs: HashMap<String, sdkws::PullMsgs>) -> Result<()> {
        for (conversation_id, pull) in msgs {
            for msg in &pull.msgs {
                if let Err(e) = self.do_notification(&conversation_id, msg).await {
                    warn!("[conversation_handle] 通知处理失败 conv={} contentType={} err={}", conversation_id, msg.content_type, e);
                }
            }
            if let Some(last) = pull.msgs.last() {
                if last.seq != 0 {
                    if let Err(e) = self.repository.notification_dao.set_notification_seq(&conversation_id, last.seq).await {
                        warn!("[conversation_handle] SetNotificationSeq 失败 conv={} seq={} err={}", conversation_id, last.seq, e);
                    }
                }
            }
        }
        Ok(())
    }

    /// 单条通知按类型分发（对齐 Go doNotification）
    async fn do_notification(&self, conversation_id: &str, msg: &sdkws::MsgData) -> Result<()> {
        match msg.content_type {
            constant::MSG_REVOKE_NOTIFICATION => self.do_revoke_msg(conversation_id, msg).await,
            constant::HAS_READ_RECEIPT => self.do_read_drawing(conversation_id, msg).await,
            constant::CONVERSATION_CHANGE_NOTIFICATION | constant::CONVERSATION_PRIVATE_CHAT_NOTIFICATION => {
                if let Err(e) = self.incr_sync_conversations().await {
                    warn!("[conversation_handle] 会话变更通知触发增量同步失败 err={}", e);
                }
                Ok(())
            }
            constant::CLEAR_CONVERSATION_NOTIFICATION => self.do_clear_conversations(msg).await,
            constant::DELETE_MSGS_NOTIFICATION => self.do_delete_msgs(conversation_id, msg).await,
            constant::USER_INFO_UPDATED_NOTIFICATION => self.do_user_info_updated_notification(msg).await,
            constant::BUSINESS_NOTIFICATION => Ok(()),
            _ => {
                if msg.content_type >= constant::GROUP_NOTIFICATION_BEGIN && msg.content_type < constant::SUPER_GROUP_NOTIFICATION_BEGIN {
                    self.do_group_notification(msg).await
                } else if msg.content_type >= constant::NOTIFICATION_BEGIN && msg.content_type <= constant::NOTIFICATION_END {
                    if let Err(e) = self.incr_sync_conversations().await {
                        warn!("[conversation_handle] 通知触发增量同步失败 err={}", e);
                    }
                    Ok(())
                } else {
                    Ok(())
                }
            }
        }
    }

    /// 撤回消息（Go doRevokeMsg → revokeMessage）：更新本地消息为撤回态并触发 OnNewRecvMessageRevoked
    async fn do_revoke_msg(&self, conversation_id: &str, msg: &sdkws::MsgData) -> Result<()> {
        let tips: RevokeTips = serde_json::from_slice(&msg.content).map_err(|e| anyhow::anyhow!("parse RevokeMsgTips: {}", e))?;
        let seq = tips.seq;
        let msgs: Vec<LocalChatLog> = self.repository.message.get_messages_by_seq(conversation_id, &[seq]).await?;
        let revoked_msg = msgs
            .into_iter()
            .next()
            .ok_or_else(|| anyhow::anyhow!("GetMessageBySeq not found conv={} seq={}", conversation_id, seq))?;
        let revoker_nickname = String::new();
        let n = serde_json::json!({
            "detail": serde_json::json!({
                "revokerID": tips.revoker_user_id,
                "revokerRole": 0i32,
                "clientMsgID": revoked_msg.client_msg_id,
                "revokerNickname": revoker_nickname,
                "sessionType": tips.sesstion_type,
                "seq": tips.seq,
                "revokeTime": tips.revoke_time,
                "sourceMessageSendTime": revoked_msg.send_time,
                "sourceMessageSendID": revoked_msg.send_id,
                "sourceMessageSenderNickname": revoked_msg.sender_nickname,
                "ex": revoked_msg.ex,
                "isAdminRevoke": tips.is_admin_revoke,
            })
        });
        let revoke_content = serde_json::to_string(&n).unwrap_or_default();
        let mut updated = revoked_msg.clone();
        updated.content_type = constant::MSG_REVOKE_NOTIFICATION;
        updated.content = revoke_content.clone();
        self.repository.message.update_message(conversation_id, &updated).await?;
        if let Some(listener) = self.advanced_msg_listener() {
            listener.on_new_recv_message_revoked(revoke_content).await;
        }
        Ok(())
    }

    /// 用户信息变更通知（对齐 Go internal/user/notification.go userInfoUpdatedNotification）：若为当前登录用户则 SyncLoginUserInfo
    async fn do_user_info_updated_notification(&self, msg: &sdkws::MsgData) -> Result<()> {
        let tips: UserInfoUpdatedTipsRust = serde_json::from_slice(&msg.content)
            .map_err(|e| anyhow::anyhow!("parse UserInfoUpdatedTips: {}", e))?;
        if tips.user_id != self.config.user_id {
            trace!("UserInfoUpdatedTips userID != loginUserID, skip sync_login_user_info");
            return Ok(());
        }
        if let Err(e) = self.sync_login_user_info(true).await {
            warn!("[conversation_handle] UserInfoUpdatedNotification sync_login_user_info 失败 err={}", e);
        }
        Ok(())
    }

    /// 群组相关通知（Go: Group.DoNotification）：刷新群数据并回调 GroupListener
    async fn do_group_notification(&self, msg: &sdkws::MsgData) -> Result<()> {
        if let Err(e) = self.sync_all_joined_groups_and_members().await {
            warn!("[conversation_handle] 群通知后 sync_all_joined_groups_and_members 失败 err={}", e);
        }
        let content_str = String::from_utf8_lossy(&msg.content).to_string();
        if let Some(l) = self.group_listener() {
            l.on_group_info_changed(content_str).await;
        }
        Ok(())
    }

    /// 已读回执（Go doReadDrawing）：更新本地已读并触发 OnRecvC2CReadReceipt
    async fn do_read_drawing(&self, conversation_id: &str, msg: &sdkws::MsgData) -> Result<()> {
        let tips: ReadReceiptTips = serde_json::from_slice(&msg.content).map_err(|e| anyhow::anyhow!("parse MarkAsReadTips: {}", e))?;
        if tips.mark_as_read_user_id == self.config.user_id {
            return Ok(());
        }
        if tips.seqs.is_empty() {
            return Ok(());
        }
        let messages = self.repository.message.get_messages_by_seq(conversation_id, &tips.seqs).await?;
        let mut success_msg_ids = Vec::new();
        for mut m in messages {
            m.is_read = true;
            if self.repository.message.update_message(conversation_id, &m).await.is_ok() {
                success_msg_ids.push(m.client_msg_id);
            }
        }
        let receipt_list = vec![serde_json::json!({
            "userID": tips.mark_as_read_user_id,
            "msgIDList": success_msg_ids,
            "sessionType": msg.session_type,
            "readTime": msg.send_time,
        })];
        let receipt_json = serde_json::to_string(&receipt_list).unwrap_or_default();
        if let Some(listener) = self.advanced_msg_listener() {
            listener.on_recv_c2c_read_receipt(receipt_json).await;
        }
        Ok(())
    }

    /// 清空会话（Go doClearConversations）
    async fn do_clear_conversations(&self, msg: &sdkws::MsgData) -> Result<()> {
        let tips: ClearConversationTipsRust = serde_json::from_slice(&msg.content).map_err(|e| anyhow::anyhow!("parse ClearConversationTips: {}", e))?;
        for cid in &tips.conversation_i_ds {
            let _ = self.repository.message.delete_conversation(cid).await;
            let _ = self.repository.conversation.delete_conversation(cid).await;
        }
        if let Some(listener) = self.conversation_listener() {
            let json = serde_json::to_string(&tips.conversation_i_ds).unwrap_or_else(|_| "[]".to_string());
            listener.on_conversation_changed(json).await;
        }
        if let Err(e) = self.incr_sync_conversations().await {
            warn!("[conversation_handle] 清空会话后增量同步失败 err={}", e);
        }
        Ok(())
    }

    /// 删除本地消息（Go doDeleteMsgs）
    async fn do_delete_msgs(&self, conversation_id: &str, msg: &sdkws::MsgData) -> Result<()> {
        let tips: DeleteMsgsTipsRust = serde_json::from_slice(&msg.content).map_err(|e| anyhow::anyhow!("parse DeleteMsgsTips: {}", e))?;
        for seq in &tips.seqs {
            let msgs: Vec<LocalChatLog> = self.repository.message.get_messages_by_seq(conversation_id, &[*seq]).await?;
            if let Some(m) = msgs.into_iter().next() {
                let _ = self.repository.message.delete_by_client_msg_id(conversation_id, &m.client_msg_id).await;
            }
        }
        Ok(())
    }

    /// 与 Go SyncAllBlackList / SyncAllBlackListWithoutNotice 对齐：全量拉取服务端黑名单，与本地 diff 后落库；with_notice 时回调 on_black_list_changed
    #[instrument(skip(self), fields(with_notice = with_notice))]
    pub async fn sync_black_list(&self, with_notice: bool) -> Result<()> {
        let server_list = self.api.friend.get_black_list().await?;
        let local_list = self.repository.black.get_black_list().await?;
        let owner = self.config.user_id.clone();
        let server_ids: HashSet<String> = server_list.iter().map(|b| b.block_user_id.clone()).collect();
        let local_map: HashMap<String, LocalBlack> = local_list.into_iter().map(|b| (b.block_user_id.clone(), b)).collect();
        for b in &server_list {
            let row = LocalBlack {
                owner_user_id: owner.clone(),
                block_user_id: b.block_user_id.clone(),
                nickname: b.nickname.clone(),
                face_url: b.face_url.clone(),
                create_time: b.create_time,
                add_source: b.add_source,
                operator_user_id: b.operator_user_id.clone(),
                ex: b.ex.clone(),
                attached_info: b.attached_info.clone(),
            };
            if local_map.contains_key(&b.block_user_id) {
                let _ = self.repository.black.update(&row).await;
            } else {
                let _ = self.repository.black.insert(&row).await;
            }
        }
        for (block_id, _) in &local_map {
            if !server_ids.contains(block_id) {
                let _ = self.repository.black.delete(block_id).await;
            }
        }
        if with_notice {
            if let Some(l) = self.friend_listener() {
                if let Ok(json) = serde_json::to_string(&server_list) {
                    l.on_black_list_changed(json).await;
                }
            }
        }
        Ok(())
    }

    /// 与 Go IncrSyncFriends 对齐：增量同步好友并落库；完成后可选触发 on_friend_list_changed
    #[instrument(skip(self))]
    pub async fn incr_sync_friends(&self) -> Result<()> {
        use crate::im::model::conversation::LocalVersionSync;
        let version_sync = self.repository.friend.get_version_sync().await?;
        let (version, version_id) = version_sync.as_ref().map(|v| (v.version, v.version_id.as_str())).unwrap_or((0, ""));
        let local_friends = self.repository.friend.get_all_friends().await?;
        if version_sync.is_none() {
            if let Ok((srv_version, srv_version_id, server_ids)) = self.api.friend.get_full_friend_user_ids().await {
                let server_set: HashSet<String> = server_ids.iter().cloned().collect();
                let local_ids = self.repository.friend.get_all_friend_ids().await?;
                let local_set: HashSet<String> = local_ids.into_iter().collect();
                if server_set != local_set {
                    let all_resp = self.api.friend.get_all_friends().await?;
                    self.apply_friends_full_sync(&all_resp.friends_info, &local_friends, true).await?;
                    let _ = self.repository.friend.save_version_sync(&LocalVersionSync {
                        table_name: "local_friends".to_string(),
                        entity_id: self.config.user_id.clone(),
                        version: srv_version,
                        version_id: srv_version_id,
                    }).await;
                    return Ok(());
                }
                if srv_version > 0 && !srv_version_id.is_empty() {
                    let _ = self.repository.friend.save_version_sync(&LocalVersionSync {
                        table_name: "local_friends".to_string(),
                        entity_id: self.config.user_id.clone(),
                        version: srv_version,
                        version_id: srv_version_id,
                    }).await;
                }
            }
        }
        let resp = self.api.friend.get_incremental_friends(version, version_id).await?;
        if resp.full {
            let all_resp = self.api.friend.get_all_friends().await?;
            self.apply_friends_full_sync(&all_resp.friends_info, &local_friends, true).await?;
            if !resp.version_id.is_empty() {
                let new_v = if resp.version > 0 { resp.version } else { version + 1 };
                let _ = self.repository.friend.save_version_sync(&LocalVersionSync {
                    table_name: "local_friends".to_string(),
                    entity_id: self.config.user_id.clone(),
                    version: new_v,
                    version_id: resp.version_id.clone(),
                }).await;
            }
            return Ok(());
        }
        let mut server_friends = Vec::new();
        server_friends.extend(resp.insert.into_iter());
        server_friends.extend(resp.update.into_iter());
        self.apply_friends_full_sync(&server_friends, &local_friends, false).await?;
        for id in &resp.delete {
            let _ = self.repository.friend.delete_friend(id).await;
        }
        if !resp.version_id.is_empty() {
            let new_v = if resp.version > 0 { resp.version } else { version + 1 };
            let _ = self.repository.friend.save_version_sync(&LocalVersionSync {
                table_name: "local_friends".to_string(),
                entity_id: self.config.user_id.clone(),
                version: new_v,
                version_id: resp.version_id,
            }).await;
        }
        if let Some(l) = self.friend_listener() {
            if let Ok(updated) = self.repository.friend.get_all_friends().await {
                if let Ok(json) = serde_json::to_string(&updated) {
                    l.on_friend_list_changed(json).await;
                }
            }
        }
        Ok(())
    }

    /// 与 Go SyncAllJoinedGroupsAndMembersWithLock 对齐：先增量同步加入的群列表，再对每个群增量同步成员（复用 friend 的版本+增量模式）
    async fn sync_all_joined_groups_and_members(&self) -> Result<()> {
        const LOCAL_GROUPS_TABLE: &str = "local_groups";
        const LOCAL_GROUP_ENTITIES_VERSION_TABLE: &str = "local_group_entities_version";
        const MAX_SYNC_PULL_NUMBER: usize = 20;

        let user_id = &self.config.user_id;

        // 1) 增量同步加入的群列表（与 Go IncrSyncJoinGroup 一致）
        let version_sync = self
            .repository
            .version_sync
            .get_version_sync_for(LOCAL_GROUPS_TABLE, user_id)
            .await?;
        let (version, version_id) = version_sync
            .as_ref()
            .map(|v| (v.version, v.version_id.as_str()))
            .unwrap_or((0, ""));

        let resp = self
            .api
            .group
            .get_incremental_join_groups(version, version_id)
            .await?;

        if resp.full {
            let local = self.repository.group.get_joined_group_list().await?;
            for g in &local {
                let _ = self.repository.group.delete(&g.group_id).await;
            }
            for g in &resp.insert {
                let local_group = server_group_to_local(g);
                let _ = self.repository.group.insert(&local_group).await;
            }
        } else {
            for group_id in &resp.delete {
                let _ = self.repository.group.delete(group_id).await;
            }
            for g in &resp.insert {
                let _ = self.repository.group.insert(&server_group_to_local(g)).await;
            }
            for g in &resp.update {
                let local_group = server_group_to_local(g);
                if self.repository.group.get_group_info_by_group_id(&local_group.group_id).await?.is_some() {
                    let _ = self.repository.group.update(&local_group).await;
                } else {
                    let _ = self.repository.group.insert(&local_group).await;
                }
            }
        }

        let new_group_version = LocalVersionSync {
            table_name: LOCAL_GROUPS_TABLE.to_string(),
            entity_id: user_id.to_string(),
            version: resp.version,
            version_id: resp.version_id.clone(),
        };
        self.repository.version_sync.save_version_sync(&new_group_version).await?;

        // 2) 对已加入的每个群增量同步成员（与 Go syncGroupAndMember 一致，分批拉取）
        let joined = self.repository.group.get_joined_group_list().await?;
        let group_ids: Vec<String> = joined.into_iter().map(|g| g.group_id).collect();

        for chunk in group_ids.chunks(MAX_SYNC_PULL_NUMBER) {
            let mut req_list: Vec<GetIncrementalGroupMemberReq> = Vec::with_capacity(chunk.len());
            for group_id in chunk {
                let lvs = self
                    .repository
                    .version_sync
                    .get_version_sync_for(LOCAL_GROUP_ENTITIES_VERSION_TABLE, group_id)
                    .await?;
                req_list.push(GetIncrementalGroupMemberReq {
                    group_id: group_id.clone(),
                    version_id: lvs.as_ref().map(|v| v.version_id.as_str()).unwrap_or("").to_string(),
                    version: lvs.as_ref().map(|v| v.version),
                });
            }

            let batch = self.api.group.get_incremental_group_members_batch(&req_list).await?;
            for (gid, member_resp) in batch {
                if let Some(grp) = &member_resp.group {
                    let local_group = server_group_to_local(grp);
                    if self.repository.group.get_group_info_by_group_id(&local_group.group_id).await?.is_some() {
                        let _ = self.repository.group.update(&local_group).await;
                    } else {
                        let _ = self.repository.group.insert(&local_group).await;
                    }
                }

                if member_resp.full {
                    let _ = self.repository.group_member.delete_all_members(&gid).await;
                    for m in &member_resp.insert {
                        let local_m = server_group_member_to_local(m);
                        let _ = self.repository.group_member.insert(&local_m).await;
                    }
                } else {
                    for uid in &member_resp.delete {
                        let _ = self.repository.group_member.delete(&gid, uid).await;
                    }
                    for m in member_resp.insert.iter().chain(member_resp.update.iter()) {
                        let local_m = server_group_member_to_local(m);
                        if self.repository.group_member.get_by_group_id_user_id(&gid, &local_m.user_id).await?.is_some() {
                            let _ = self.repository.group_member.update(&local_m).await;
                        } else {
                            let _ = self.repository.group_member.insert(&local_m).await;
                        }
                    }
                }

                let member_version = LocalVersionSync {
                    table_name: LOCAL_GROUP_ENTITIES_VERSION_TABLE.to_string(),
                    entity_id: gid.clone(),
                    version: member_resp.version,
                    version_id: member_resp.version_id.clone(),
                };
                let _ = self.repository.version_sync.save_version_sync(&member_version).await;
            }
        }

        Ok(())
    }

    async fn apply_friends_full_sync(
        &self,
        server_friends: &[sdkws::FriendInfo],
        local_friends: &[sdkws::FriendInfo],
        is_full: bool,
    ) -> Result<()> {
        let local_map: HashMap<String, sdkws::FriendInfo> = local_friends
            .iter()
            .filter_map(|f| f.friend_user.as_ref().map(|u| (u.user_id.clone(), f.clone())))
            .collect();
        let server_map: HashMap<String, sdkws::FriendInfo> = server_friends
            .iter()
            .filter_map(|f| f.friend_user.as_ref().map(|u| (u.user_id.clone(), f.clone())))
            .collect();
        for (_, server_f) in server_map.iter() {
            self.repository.friend.upsert_friend(server_f).await?;
        }
        if is_full {
            let server_ids: HashSet<String> = server_map.keys().cloned().collect();
            for (id, _) in local_map.iter() {
                if !server_ids.contains(id) {
                    self.repository.friend.delete_friend(id).await?;
                }
            }
        }
        Ok(())
    }

    /// 与 Go InitSyncProgress 一致（reinstalled 时进度起点）
    const INIT_SYNC_PROGRESS: i32 = 10;

    /// 同步阶段标记（Go syncFlag）：AppDataSyncStart 内容与 Go 对齐（进度 + syncWait 会话/已读 + asyncNoWait 用户/黑名单）；MsgSyncBegin 时执行 syncData
    #[instrument(skip(self), fields(flag = flag))]
    pub async fn sync_flag(&self, flag: i32) -> Result<()> {
        if let Some(listener) = self.conversation_listener() {
            match flag {
                sync_flag::APP_DATA_SYNC_START => {
                    self.msg_sync_offset.store(0, Ordering::SeqCst);
                    listener.on_sync_server_start(true).await;
                    listener.on_sync_server_progress(1).await;
                    // Go asyncWait: SyncAllJoinedGroupsAndMembersWithLock, IncrSyncFriends
                    if let Err(e) = self.sync_all_joined_groups_and_members().await {
                        warn!("[conversation_handle] AppDataSyncStart sync_all_joined_groups_and_members 失败 err={}", e);
                    }
                    if let Err(e) = self.incr_sync_friends().await {
                        warn!("[conversation_handle] AppDataSyncStart incr_sync_friends 失败 err={}", e);
                    }
                    listener.on_sync_server_progress(Self::INIT_SYNC_PROGRESS * 4 / 10).await; // 4，与 Go addInitProgress(4) 后 c.progress 一致
                    // Go syncWait: IncrSyncConversations, SyncAllConversationHashReadSeqs
                    if let Err(e) = self.incr_sync_conversations().await {
                        warn!("[conversation_handle] AppDataSyncStart incr_sync_conversations 失败 err={}", e);
                    }
                    if let Err(e) = self.sync_unread_by_seq().await {
                        warn!("[conversation_handle] AppDataSyncStart sync_unread_by_seq 失败 err={}", e);
                    }
                    listener.on_sync_server_progress(Self::INIT_SYNC_PROGRESS).await; // 10，与 Go addInitProgress(6) 后 c.progress=4+6 一致
                    // Go asyncNoWait: SyncLoginUserInfoWithoutNotice, SyncAllBlackListWithoutNotice
                    if let Err(e) = self.sync_login_user_info(false).await {
                        warn!("[conversation_handle] SyncFlag(APP_DATA_SYNC_START) sync_login_user_info 失败 err={}", e);
                    }
                    if let Err(e) = self.sync_black_list(false).await {
                        warn!("[conversation_handle] AppDataSyncStart sync_black_list 失败 err={}", e);
                    }
                }
                sync_flag::APP_DATA_SYNC_FINISH => {
                    listener.on_sync_server_progress(100).await;
                    listener.on_sync_server_finish(true).await
                }
                sync_flag::MSG_SYNC_BEGIN => {
                    listener.on_sync_server_start(false).await;
                    if let Err(e) = self.sync_data().await {
                        error!("[conversation_handle] SyncFlag(MSG_SYNC_BEGIN) sync_data 失败 err={}", e);
                    }
                }
                sync_flag::MSG_SYNC_END => listener.on_sync_server_finish(false).await,
                sync_flag::MSG_SYNC_FAILED => listener.on_sync_server_failed(false).await,
                sync_flag::MSG_SYNC_PROCESSING => {}
                _ => {}
            }
        }
        Ok(())
    }

    /// 同步数据（对齐 Go syncData，notification.go）
    ///
    /// syncWait: SyncAllConversationHashReadSeqs；asyncNoWait 五项并发：SyncLoginUserInfo、SyncAllBlackList、SyncAllJoinedGroupsAndMembersWithLock、IncrSyncFriendsWithLock、IncrSyncConversationsWithLock
    #[instrument(skip(self))]
    pub async fn sync_data(&self) -> Result<()> {
        if let Err(e) = self.sync_unread_by_seq().await {
            error!("[conversation_handle] SyncData 中 sync_unread_by_seq 失败 err={}", e);
        }
        let (r1, r2, r3, r4, r5) = tokio::join!(
            self.sync_login_user_info(true),
            self.sync_black_list(true),
            self.sync_all_joined_groups_and_members(),
            self.incr_sync_friends(),
            self.incr_sync_conversations(),
        );
        if let Err(e) = r1 {
            error!("[conversation_handle] SyncData 中 sync_login_user_info 失败 err={}", e);
        }
        if let Err(e) = r2 {
            error!("[conversation_handle] SyncData 中 sync_black_list 失败 err={}", e);
        }
        if let Err(e) = r3 {
            error!("[conversation_handle] SyncData 中 sync_all_joined_groups_and_members 失败 err={}", e);
        }
        if let Err(e) = r4 {
            error!("[conversation_handle] SyncData 中 incr_sync_friends 失败 err={}", e);
        }
        r5
    }

    /// 重装后消息同步（Go doMsgSyncByReinstalled）：落库后按批上报 progress 10→100
    #[instrument(skip(self, msgs), fields(convs = msgs.len(), total = total))]
    pub async fn do_msg_sync_by_reinstalled(&self, msgs: HashMap<String, sdkws::PullMsgs>, total: i32) -> Result<()> {
        self.do_msg_new(CmdNewMsgComeToConversation { msgs: msgs.clone() }).await?;
        let msg_len = msgs.len() as i32;
        let new_offset = self.msg_sync_offset.fetch_add(msg_len, Ordering::SeqCst) + msg_len;
        let total = total.max(1);
        let progress = (new_offset * (100 - Self::INIT_SYNC_PROGRESS) / total + Self::INIT_SYNC_PROGRESS).min(100);
        if let Some(l) = self.conversation_listener() {
            l.on_sync_server_progress(progress).await;
        }
        Ok(())
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
                debug!("[conversation_handle] cmd_rx 已关闭 退出");
                return Ok(());
            };
            // 使用传递位置创建的 span，enter 覆盖整次处理，单次 loop 结束即关闭 span
            let _guard = envelope.span.enter();
            let result = match envelope.kind {
                ConvCmdKind::NewMsgCome(c2v) => self.do_msg_new(c2v).await,
                ConvCmdKind::Notification { msgs } => self.do_notification_manager(msgs).await,
                ConvCmdKind::SyncFlag(flag) => self.sync_flag(flag).await,
                ConvCmdKind::SyncData => self.sync_data().await,
                ConvCmdKind::MsgSyncInReinstall { msgs, total } => self.do_msg_sync_by_reinstalled(msgs, total).await,
            };
            if let Err(e) = result {
                warn!("[conversation_handle] 处理命令失败: {e}");
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::im::dao::Repository;
    use crate::im::logger::logger::init_logger;
    use crate::im::login_async;
    use crate::im::model::conversation::ConversationSyncerConfig;
    use test_context::{test_context, AsyncTestContext};
    use tokio_util::sync::CancellationToken;

    struct AppCtx {
        handle: ConversationHandle,
    }

    impl AsyncTestContext for AppCtx {
        async fn setup() -> Self {
            init_logger("rust_lib_flutter_rust_demo=debug,sqlx=trace,hyper_util::client=info,reqwest=info");
            let area_code = "+86".to_string();
            let password = "284f3d09ea0695538e4ded1c1766d73a".to_string();
            let platform = 5;
            let token_info = login_async(area_code, "17764338283".to_string(), password, platform).await.expect("登录失败");
            let db_path = format!("sqlite://{}/conv_sync_{}.db?mode=rwc", std::env::temp_dir().as_path().to_string_lossy(), token_info.user_id);
            let repo = Repository::create(&db_path).await.expect("创建测试数据库失败");
            let cfg = ConversationSyncerConfig {
                user_id: token_info.user_id.clone(),
                api_base_url: "http://localhost:10002".to_string(),
                token: token_info.im_token.clone(),
                db_path,
                get_background: None,
            };
            let (_tx, rx) = mpsc::unbounded_channel();
            let cancel = CancellationToken::new();
            let handle = ConversationHandle::with_listener_and_db_and_client(cfg, None, repo.pool.clone(), reqwest::Client::new(), rx, cancel)
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
