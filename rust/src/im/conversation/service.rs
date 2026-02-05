//! 会话同步服务层
//!
//! 实现 OpenIM SDK 的会话增量同步逻辑，参考 Go 版本的实现

use crate::im::api::ConversationApi;
use crate::im::dao::{ConversationDao, VersionSyncDao};
use crate::im::listener::{ConversationListener, EmptyConversationListener};
use crate::im::message::MessageApi;
use crate::im::model::conversation::{ConversationSyncerConfig, LocalVersionSync};
use crate::im::model::LocalConversation;
use anyhow::{Context, Result};
use openim_protocol::constant;
use openim_protocol::sdkws;
use sqlx::{Pool, Sqlite};
use std::collections::HashMap;
use std::sync::Arc;
use std::time::{SystemTime, UNIX_EPOCH};
use tracing::{debug, error, info, warn};
use uuid::Uuid;

/// 会话同步器
pub struct ConversationSyncer {
    config: ConversationSyncerConfig,
    /// 会话 API 客户端
    api: ConversationApi,
    /// 消息 HTTP API 客户端
    message_api: MessageApi,
    /// 会话 DAO
    conversation_dao: ConversationDao,
    /// 版本同步 DAO
    version_sync_dao: VersionSyncDao,
    /// 会话监听器
    listener: Option<Arc<dyn ConversationListener>>,
}

impl ConversationSyncer {
    /// 创建新的会话同步器（使用默认空监听器）
    pub async fn new(config: ConversationSyncerConfig) -> Result<Self> {
        Self::with_listener(config, None).await
    }

    /// 创建新的会话同步器（带自定义监听器，内部自行创建连接池并执行迁移）
    pub async fn with_listener(config: ConversationSyncerConfig, listener: Option<Arc<dyn ConversationListener>>) -> Result<Self> {
        // 构建SQLite数据库连接URL
        let db_url = config.db_path.clone();
        info!("[ConvSync] 创建会话同步器，用户ID: {}, SQLite数据库: {}", config.user_id, db_url);

        // 使用 sqlx 连接池；迁移由上层统一执行，这里假设表已存在
        let pool = sqlx::sqlite::SqlitePoolOptions::new()
            .max_connections(5)
            .connect(&db_url)
            .await
            .context(format!("连接SQLite数据库失败: {}", db_url))?;

        // 创建带认证拦截器的 HTTP 客户端（token 通过 default_headers 自动添加）
        let http_client = reqwest::ClientBuilder::new()
            .default_headers({
                let mut headers = reqwest::header::HeaderMap::new();
                headers.insert(
                    reqwest::header::HeaderName::from_static("token"),
                    reqwest::header::HeaderValue::from_str(&config.token).context("无效的 token")?,
                );
                headers
            })
            .build()
            .context("创建 HTTP 客户端失败")?;

        Self::with_listener_and_db_and_client(config, listener, Arc::new(pool), http_client).await
    }

    /// 创建新的会话同步器（使用共享连接池和 HTTP 客户端）
    pub async fn with_listener_and_db_and_client(
        config: ConversationSyncerConfig,
        listener: Option<Arc<dyn ConversationListener>>,
        db: Arc<Pool<Sqlite>>,
        http_client: reqwest::Client,
    ) -> Result<Self> {
        // 创建带 base_url 的客户端（通过 URL 前缀实现）
        // 注意：reqwest 不支持动态 base_url，所以我们仍然需要在 API 方法中使用完整 URL
        // 但认证信息已经通过 default_headers 设置好了
        let api = ConversationApi::new(http_client.clone(), config.api_base_url.clone(), config.user_id.clone(), &config.token);

        Ok(Self {
            api,
            message_api: MessageApi::new(http_client, config.api_base_url.clone(), config.user_id.clone(), &config.token),
            conversation_dao: ConversationDao::new((*db).clone()),
            version_sync_dao: VersionSyncDao::new((*db).clone(), config.user_id.clone()),
            listener,
            config,
        })
    }

    /// 从数据库获取所有本地会话
    pub async fn get_all_conversations(&self) -> Result<Vec<LocalConversation>> {
        self.conversation_dao.get_all_conversations().await
    }

    /// 从数据库获取所有会话 ID
    pub async fn get_all_conversation_ids(&self) -> Result<Vec<String>> {
        self.conversation_dao.get_all_conversation_ids().await
    }

    /// 从数据库获取版本同步信息
    async fn get_version_sync(&self) -> Result<Option<LocalVersionSync>> {
        self.version_sync_dao.get_version_sync().await
    }

    /// 保存版本同步信息到数据库
    async fn save_version_sync(&self, version_sync: &LocalVersionSync) -> Result<()> {
        self.version_sync_dao.save_version_sync(version_sync).await
    }

    /// 插入或更新会话到数据库
    async fn upsert_conversation(&self, conv: &LocalConversation) -> Result<()> {
        self.conversation_dao.upsert_conversation(conv).await
    }

    /// 根据消息内容生成 latestMsg 摘要（仿 Go 版 SDK 的简化实现）
    fn build_latest_msg_summary(msg: &sdkws::MsgData) -> String {
        // 文本消息：尽量展示正文
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

        // 其他常见内容类型：按类型给固定文案
        match msg.content_type {
            t if t == constant::PICTURE => "[图片]".to_string(),
            t if t == constant::VOICE => "[语音]".to_string(),
            t if t == constant::VIDEO => "[视频]".to_string(),
            t if t == constant::FILE => "[文件]".to_string(),
            t if t == constant::AT_TEXT => "[@消息]".to_string(),
            t if t == constant::LOCATION => "[位置]".to_string(),
            t if t == constant::MERGER => "[聊天记录]".to_string(),
            t if t == constant::CARD => "[名片]".to_string(),

            // 好友相关通知
            1201 | 1203 | 1204 => "[好友通知]".to_string(),
            // 群相关通知（部分示例）
            1501 | 1504 | 1508 => "[群通知]".to_string(),
            // 已读回执
            2200 => "[已读回执]".to_string(),

            // 兜底
            _ => "[新消息]".to_string(),
        }
    }

    /// 基于新消息/通知实时更新会话（未读数、最新消息等）
    pub async fn on_new_message(&self, conversation_id: &str, msg: &sdkws::MsgData, is_notification: bool) -> Result<()> {
        // 对部分会话相关通知，优先走"通知路由"：触发一次增量会话同步，而不是直接改本地结构，
        // 行为上更贴近 Go 版的 DoConversation*Notification → IncrSyncConversations 流程。
        if is_notification {
            match msg.content_type {
                // 会话属性变更 / 私聊标记变更
                constant::CONVERSATION_CHANGE_NOTIFICATION
                | constant::CONVERSATION_PRIVATE_CHAT_NOTIFICATION
                // 会话清空 / 删除 / 未读数变更 / 已读回执
                | constant::CLEAR_CONVERSATION_NOTIFICATION
                | constant::CONVERSATION_UNREAD_NOTIFICATION
                | constant::CONVERSATION_DELETE_NOTIFICATION
                | constant::HAS_READ_RECEIPT => {
                    info!(
                        "[ConvSync] 收到会话通知，contentType={}，触发增量会话同步",
                        msg.content_type
                    );
                    if let Err(e) = self.incr_sync_conversations().await {
                        warn!(
                            "[ConvSync] 会话通知触发增量同步失败: {}",
                            e
                        );
                    }
                    // 交给增量同步统一刷新会话表，这里不直接修改本地会话
                    return Ok(());
                }
                _ => {
                    // 其他通知类型走通用路径（latestMsg 标签、回调等）
                }
            }
        }

        // 查询现有会话
        let existing_conv = self.conversation_dao.get_conversation_by_id(conversation_id).await?;

        // 从现有记录或默认值构建 LocalConversation
        let mut conv = if let Some(ref existing) = existing_conv {
            existing.clone()
        } else {
            // 新会话：仅用必要字段构建，其他使用默认值
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

        // 生成 latest_msg 摘要
        let latest = Self::build_latest_msg_summary(msg);

        // 更新时间与未读数
        // 参考 Go 版本：只有消息的 options 中 IsUnreadCount 为 true 时才计入未读数
        let send_time = if msg.send_time > 0 { msg.send_time } else { msg.create_time };
        conv.latest_msg = latest;
        conv.latest_msg_send_time = send_time;
        conv.max_seq = conv.max_seq.max(msg.seq);

        // 检查消息的 options 中的 unreadCount 字段
        // 参考 Go 版本：只有 options 中 unreadCount 为 true 且非自己发送的消息才计入未读数
        let should_count_unread = if msg.send_id == self.config.user_id || is_notification {
            // 自己发送的消息或通知消息不计入未读数
            false
        } else {
            // 检查 options 中的 unreadCount 字段
            // 默认情况下，如果 options 中没有明确设置，则视为 true（计入未读数）
            *msg.options.get("unreadCount").unwrap_or(&true) // 默认计入未读数
        };

        if should_count_unread {
            // 检查是否是新消息（避免重复计数）
            // 如果当前消息的 seq 大于已记录的 max_seq，说明是新消息
            let is_new_msg = msg.seq > conv.max_seq.saturating_sub(1);
            if is_new_msg {
                conv.unread_count += 1;
            }
        }

        // 落库
        self.upsert_conversation(&conv).await?;

        // 触发会话变更/新会话回调
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

        // 更新总未读数
        if let Ok(total_unread) = self.get_total_unread_count().await {
            if let Some(listener) = &self.listener {
                listener.on_total_unread_message_count_changed(total_unread).await;
            }
        }

        Ok(())
    }

    /// 从数据库删除会话
    async fn delete_conversation(&self, conversation_id: &str) -> Result<()> {
        self.conversation_dao.delete_conversation(conversation_id).await
    }

    /// 获取总未读消息数（公开给上层调用）
    pub async fn get_total_unread_count(&self) -> Result<i32> {
        self.conversation_dao.get_total_unread_count().await
    }

    /// 基于服务器的 MaxSeq / HasReadSeq 校正本地未读数
    pub async fn sync_unread_by_seq(&self) -> Result<()> {
        info!("[ConvSync/Seq] 🔄 开始按 Seq 校正未读数...");

        // 1. 获取本地会话
        let mut local_conversations = self.get_all_conversations().await?;
        let mut local_map: HashMap<String, LocalConversation> = HashMap::new();
        for conv in local_conversations.drain(..) {
            local_map.insert(conv.conversation_id.clone(), conv);
        }

        // 2. 从服务器获取每个会话的 MaxSeq/HasReadSeq
        let seqs = self.api.get_has_read_and_max_seqs().await?;
        if seqs.is_empty() {
            info!("[ConvSync/Seq] 服务器未返回会话 Seq 信息，跳过未读数校正");
            return Ok(());
        }

        // 3. 计算未读并更新本地记录，同时补齐本地缺失会话
        let mut changed_conversations: Vec<LocalConversation> = Vec::new();
        let mut new_conversations: Vec<LocalConversation> = Vec::new();
        let mut missing_convs: Vec<(String, (i64, i64))> = Vec::new();

        info!("[ConvSync/Seq] 🔄 开始校正未读数，服务器返回 {} 个会话的 Seq 信息", seqs.len());
        for (conv_id, (max_seq, has_read_seq)) in seqs.into_iter() {
            let unread = (max_seq - has_read_seq).max(0) as i32;

            if let Some(mut local) = local_map.remove(&conv_id) {
                // 仅在有实际变化时更新
                if local.unread_count != unread || local.max_seq != max_seq {
                    info!(
                        "[ConvSync/Seq] 📝 校正会话未读数: conversationID={}, 本地未读数: {} -> {}, maxSeq: {} -> {}, hasReadSeq: {}",
                        conv_id, local.unread_count, unread, local.max_seq, max_seq, has_read_seq
                    );
                    local.unread_count = unread;
                    local.max_seq = max_seq;
                    // 更新时间戳由上层逻辑维护，这里不强行覆盖
                    self.upsert_conversation(&local).await?;
                    changed_conversations.push(local);
                } else {
                    debug!("[ConvSync/Seq] ✓ 会话未读数无需更新: conversationID={}, unreadCount={}, maxSeq={}", conv_id, unread, max_seq);
                }
            } else {
                // 本地没有该会话，记录下来后续从服务器补齐
                info!(
                    "[ConvSync/Seq] ⚠️ 按 Seq 校正未读数时发现本地不存在的会话: conversationID={}, maxSeq={}, hasReadSeq={}, unreadCount={}",
                    conv_id, max_seq, has_read_seq, unread
                );
                missing_convs.push((conv_id, (max_seq, has_read_seq)));
            }
        }

        info!(
            "[ConvSync/Seq] 📊 未读数校正统计: 已更新 {} 个会话，发现 {} 个本地缺失会话",
            changed_conversations.len(),
            missing_convs.len()
        );

        // 输出总未读数（校正前）
        if let Ok(total_before) = self.get_total_unread_count().await {
            info!("[ConvSync/Seq] 📊 校正前总未读数: {}", total_before);
        }

        // 3.1 为本地缺失的会话从服务器补齐详情并按照 Seq 初始化未读数
        if !missing_convs.is_empty() {
            info!("[ConvSync/Seq] 发现本地缺失会话 {} 个，尝试从服务器补齐详情", missing_convs.len());
            match self.api.get_all_conversations().await {
                Ok(all_resp) => {
                    let server_map: HashMap<String, LocalConversation> = all_resp.conversations.iter().map(|c| (c.conversation_id.clone(), c.clone())).collect();

                    for (conv_id, (max_seq, has_read_seq)) in missing_convs.into_iter() {
                        if let Some(mut conv) = server_map.get(&conv_id).cloned() {
                            let unread = (max_seq - has_read_seq).max(0) as i32;
                            debug!("[ConvSync/Seq] 为缺失会话补齐记录: {} (unread={}, maxSeq={}, hasReadSeq={})", conv_id, unread, max_seq, has_read_seq);

                            conv.unread_count = unread;
                            conv.max_seq = max_seq;
                            // 其他字段（latestMsg 等）暂由后续 on_new_message 或上层逻辑完善

                            self.upsert_conversation(&conv).await?;
                            new_conversations.push(conv);
                        } else {
                            warn!(
                                "[ConvSync/Seq] 按 Seq 校正时服务器会话列表中也不存在会话: {} (maxSeq={}, hasReadSeq={})",
                                conv_id, max_seq, has_read_seq
                            );
                        }
                    }
                }
                Err(e) => {
                    warn!("[ConvSync/Seq] 拉取服务器会话详情失败，无法为缺失会话补齐记录: {:?}", e);
                }
            }
        }

        // 4. 触发回调（参考 Go 版本：只要有会话变更就触发总未读数回调）
        if !new_conversations.is_empty() {
            let json = serde_json::to_string(&new_conversations).unwrap_or_else(|_| "[]".to_string());
            info!("[ConvSync/Seq] 📢 触发新会话回调，数量: {}", new_conversations.len());
            if let Some(listener) = &self.listener {
                listener.on_new_conversation(json).await;
            }
        }

        if !changed_conversations.is_empty() {
            let json = serde_json::to_string(&changed_conversations).unwrap_or_else(|_| "[]".to_string());
            info!("[ConvSync/Seq] 📢 触发会话变更回调，数量: {}", changed_conversations.len());
            if let Some(listener) = &self.listener {
                listener.on_conversation_changed(json).await;
            }
        }

        // 只要有会话变更（新会话或变更会话），就触发总未读数回调（参考 Go 版本）
        if !new_conversations.is_empty() || !changed_conversations.is_empty() {
            match self.get_total_unread_count().await {
                Ok(total_unread) => {
                    info!("[ConvSync/Seq] 📢 触发总未读数变更回调: {}", total_unread);
                    if let Some(listener) = &self.listener {
                        listener.on_total_unread_message_count_changed(total_unread).await;
                    }
                }
                Err(e) => {
                    warn!("[ConvSync/Seq] ⚠️ 获取总未读数失败，无法触发回调: {}", e);
                }
            }
        } else {
            info!("[ConvSync/Seq] ℹ️ 无会话变更，跳过回调");
        }

        info!("[ConvSync/Seq] ✅ 按 Seq 校正未读数完成");
        Ok(())
    }

    /// 同步会话（对比服务器和本地数据）
    ///
    /// - `server_conversations`: 服务器返回的会话列表
    /// - `local_conversations`: 本地已有的会话列表
    /// - `seqs_map`: 可选的 seqs 信息（conversationID -> (maxSeq, hasReadSeq)），用于设置未读数
    async fn sync_conversations(&self, server_conversations: Vec<LocalConversation>, local_conversations: Vec<LocalConversation>, seqs_map: Option<&HashMap<String, (i64, i64)>>) -> Result<()> {
        info!("[ConvSync] 开始同步会话，服务器会话数: {}, 本地会话数: {}", server_conversations.len(), local_conversations.len());

        let local_map: HashMap<String, LocalConversation> = local_conversations.into_iter().map(|c| (c.conversation_id.clone(), c)).collect();

        let mut server_map: HashMap<String, LocalConversation> = server_conversations.into_iter().map(|c| (c.conversation_id.clone(), c)).collect();

        let mut new_conversations = Vec::new();
        let mut changed_conversations = Vec::new();
        let mut insert_count = 0;
        let mut update_count = 0;
        let mut delete_count = 0;

        // 处理插入和更新
        // 先根据 seqs 信息更新未读数（参考 Go 版本）
        if let Some(seqs) = seqs_map {
            for (conv_id, &(max_seq, has_read_seq)) in seqs.iter() {
                if let Some(server_conv) = server_map.get_mut(conv_id) {
                    let unread = (max_seq - has_read_seq).max(0) as i32;
                    info!(
                        "[ConvSync]   会话 {} 根据 seqs 设置未读数: maxSeq={}, hasReadSeq={}, unreadCount={}",
                        conv_id, max_seq, has_read_seq, unread
                    );
                    server_conv.unread_count = unread;
                    server_conv.max_seq = max_seq;
                }
            }
        }

        // 然后处理插入和更新
        for (id, server_conv) in server_map.iter() {
            if let Some(local_conv) = local_map.get(id) {
                // 更新：比较并更新变化的字段
                // 注意：即使字段相同，如果未读数有变化也需要更新
                let mut server_conv = server_conv.clone();
                self.fill_display_fields(&mut server_conv);
                let need_update = !self.conversations_equal(local_conv, &server_conv) || local_conv.unread_count != server_conv.unread_count || local_conv.max_seq != server_conv.max_seq;
                if need_update {
                    info!(
                        "[ConvSync]   更新会话: {} (类型: {}), 未读数: {} -> {}",
                        id, server_conv.conversation_type, local_conv.unread_count, server_conv.unread_count
                    );
                    debug!(
                        "[ConvSync]   会话详情 - 置顶: {}, 私聊: {}, maxSeq: {} -> {}",
                        server_conv.is_pinned, server_conv.is_private_chat, local_conv.max_seq, server_conv.max_seq
                    );
                    self.upsert_conversation(&server_conv).await?;
                    changed_conversations.push(server_conv);
                    update_count += 1;
                } else {
                    debug!("[ConvSync]   会话 {} 无需更新", id);
                }
            } else {
                // 插入：新会话
                let mut server_conv = server_conv.clone();
                self.fill_display_fields(&mut server_conv);
                info!("[ConvSync]   新增会话: {} (类型: {}), 未读数: {}", id, server_conv.conversation_type, server_conv.unread_count);
                debug!(
                    "[ConvSync]   会话详情 - 置顶: {}, 私聊: {}, maxSeq: {}",
                    server_conv.is_pinned, server_conv.is_private_chat, server_conv.max_seq
                );
                self.upsert_conversation(&server_conv).await?;
                new_conversations.push(server_conv);
                insert_count += 1;
            }
        }

        // 处理删除：服务器没有但本地有的会话
        let local_ids: std::collections::HashSet<String> = local_map.keys().cloned().collect();
        let server_ids: std::collections::HashSet<String> = server_map.keys().cloned().collect();
        for id in local_ids.difference(&server_ids) {
            warn!("[ConvSync]   删除会话: {}", id);
            self.delete_conversation(id).await?;
            delete_count += 1;
        }

        // 触发回调
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

        // 更新总未读数回调
        if insert_count > 0 || update_count > 0 || delete_count > 0 {
            if let Ok(total_unread) = self.get_total_unread_count().await {
                if let Some(listener) = &self.listener {
                    listener.on_total_unread_message_count_changed(total_unread).await;
                }
            }
        }

        info!("[ConvSync] 会话同步完成 - 新增: {}, 更新: {}, 删除: {}", insert_count, update_count, delete_count);
        Ok(())
    }

    /// 比较两个会话是否相等（用于判断是否需要更新）
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

    /// 参考 Go：在写库前补齐展示字段，避免 show_name/face_url 为空
    fn fill_display_fields(&self, _conv: &mut LocalConversation) {
        // 按 Go 行为：不在客户端虚构展示字段或时间，保持服务端/消息路径的真实数据
    }

    /// 增量同步会话（核心函数，对应 Go 版本的 IncrSyncConversations）
    pub async fn incr_sync_conversations(&self) -> Result<()> {
        // 1. 获取本地版本信息
        let version_sync = self.get_version_sync().await?;
        if let Some(ref vs) = version_sync {
            debug!("[ConvSync] 本地版本信息 - 版本: {}, 版本ID: {}", vs.version, vs.version_id);
        } else {
            debug!("[ConvSync] 本地无版本信息");
        }

        // 2. 获取本地所有会话
        let local_conversations = self.get_all_conversations().await?;
        let local_ids = self.get_all_conversation_ids().await?;

        // 3. 判断是否需要全量同步
        let reinstalled = local_ids.is_empty();
        if reinstalled {
            warn!("[ConvSync] 本地无会话，执行全量同步...");
            if let Some(listener) = &self.listener {
                listener.on_sync_server_start(true).await;
            }
            return self.full_sync().await;
        }
        // 若本地会话均为占位（名称/头像/摘要/时间全空），也按全量兜底，避免增量不生效
        let all_placeholder = local_conversations
            .iter()
            .all(|c| c.show_name.is_empty() && c.face_url.is_empty() && c.latest_msg.is_empty() && c.latest_msg_send_time == 0);
        if all_placeholder {
            warn!("[ConvSync] 本地会话疑似占位数据，执行全量同步兜底...");
            if let Some(listener) = &self.listener {
                listener.on_sync_server_start(true).await;
            }
            return self.full_sync().await;
        }

        // 4. 获取版本信息
        let (version, version_id) = if let Some(vs) = version_sync {
            (vs.version, vs.version_id)
        } else {
            // 如果没有版本信息，先获取全量会话 ID 列表
            let server_ids_vec = self.api.get_all_conversation_ids().await?;
            let server_ids: std::collections::HashSet<String> = server_ids_vec.iter().cloned().collect();
            let local_ids_set: std::collections::HashSet<String> = local_ids.iter().cloned().collect();

            // 如果服务器和本地的 ID 列表不一致，执行全量同步
            if server_ids != local_ids_set {
                warn!("[ConvSync] 会话 ID 列表不一致，执行全量同步...");
                debug!("[ConvSync] 服务器会话ID数: {}, 本地会话ID数: {}", server_ids.len(), local_ids_set.len());
                let diff: Vec<_> = server_ids.difference(&local_ids_set).collect();
                if !diff.is_empty() {
                    debug!("[ConvSync]   服务器多出的会话ID: {:?}", diff);
                }
                let diff: Vec<_> = local_ids_set.difference(&server_ids).collect();
                if !diff.is_empty() {
                    debug!("[ConvSync]   本地多出的会话ID: {:?}", diff);
                }
                return self.full_sync().await;
            }

            // 否则从全量同步获取版本信息
            let all_resp = self.api.get_all_conversations().await?;
            let server_convs: Vec<LocalConversation> = all_resp.conversations.clone();

            // 先获取 seqs 信息用于设置未读数
            let seqs_map = match self.api.get_has_read_and_max_seqs().await {
                Ok(seqs) => {
                    info!("[ConvSync] 获取到 {} 个会话的 seqs 信息，用于设置未读数", seqs.len());
                    Some(seqs)
                }
                Err(e) => {
                    warn!("[ConvSync] 获取 seqs 信息失败，将使用默认未读数: {:?}", e);
                    None
                }
            };

            // 同步数据（传入 seqs_map 用于设置未读数）
            self.sync_conversations(server_convs.clone(), local_conversations.clone(), seqs_map.as_ref()).await?;

            // 更新版本信息（这里简化处理，实际应该从响应中获取）
            let new_version = LocalVersionSync {
                table_name: "local_conversations".to_string(),
                entity_id: self.config.user_id.clone(),
                version: 1,
                version_id: Uuid::new_v4().to_string(),
            };
            self.save_version_sync(&new_version).await?;
            info!("[ConvSync] 已更新版本信息 - 版本: {}, 版本ID: {}", new_version.version, new_version.version_id);

            return Ok(());
        };

        info!("[ConvSync] 使用增量同步，版本: {}, 版本ID: {}", version, version_id);

        // 触发同步开始回调（非重新安装）
        if let Some(listener) = &self.listener {
            listener.on_sync_server_start(false).await;
        }
        if let Some(listener) = &self.listener {
            listener.on_sync_server_progress(10).await;
        }

        // 5. 调用增量同步接口
        let resp = match self.api.get_incremental_conversations(version, &version_id).await {
            Ok(resp) => resp,
            Err(e) => {
                error!("[ConvSync] 增量同步失败: {:?}", e);
                if let Some(listener) = &self.listener {
                    listener.on_sync_server_failed(false).await;
                }
                return Err(e);
            }
        };

        info!(
            "[ConvSync] ✅ 增量会话同步响应\n   全量同步: {}\n   版本ID: {}\n   版本: {}\n   新增: {} 个, 更新: {} 个, 删除: {} 个",
            resp.full,
            resp.version_id,
            resp.version,
            resp.insert.len(),
            resp.update.len(),
            resp.delete.len()
        );
        debug!("[ConvSync]   删除的会话ID: {:?}", resp.delete);
        if let Some(listener) = &self.listener {
            listener.on_sync_server_progress(50).await;
        }

        // 6. 检查是否全量同步
        if resp.full {
            warn!("[ConvSync]   服务器要求全量同步...");
            return self.full_sync().await;
        }

        // 7. 处理增量数据
        let mut server_conversations = Vec::new();

        // 处理插入
        info!("[ConvSync] 处理新增会话，数量: {}", resp.insert.len());
        for server_conv in resp.insert.iter() {
            debug!("[ConvSync]   新增会话ID: {}", server_conv.conversation_id);
            server_conversations.push(server_conv.clone());
        }

        // 处理更新
        info!("[ConvSync] 处理更新会话，数量: {}", resp.update.len());
        for server_conv in resp.update.iter() {
            debug!("[ConvSync]   更新会话ID: {}", server_conv.conversation_id);
            server_conversations.push(server_conv.clone());
        }

        // 8. 先获取 seqs 信息用于设置未读数（参考 Go 版本的 SyncAllConversationHashReadSeqs）
        let seqs_map = match self.api.get_has_read_and_max_seqs().await {
            Ok(seqs) => {
                info!("[ConvSync] 获取到 {} 个会话的 seqs 信息，用于设置未读数", seqs.len());
                Some(seqs)
            }
            Err(e) => {
                warn!("[ConvSync] 获取 seqs 信息失败，将使用默认未读数: {}", e);
                None
            }
        };

        // 同步数据（传入 seqs_map 用于设置未读数）
        self.sync_conversations(server_conversations, local_conversations, seqs_map.as_ref()).await?;

        if let Some(listener) = &self.listener {
            listener.on_sync_server_progress(80).await;
        }

        // 9. 处理删除
        if !resp.delete.is_empty() {
            info!("[ConvSync] 处理删除会话，数量: {}", resp.delete.len());
            for id in resp.delete.iter() {
                warn!("[ConvSync]   删除会话: {}", id);
                self.delete_conversation(id).await?;
            }
        }

        // 10. 更新版本信息
        if !resp.version_id.is_empty() {
            let new_version = if resp.version > 0 { resp.version } else { version + 1 };
            let new_version_sync = LocalVersionSync {
                table_name: "local_conversations".to_string(),
                entity_id: self.config.user_id.clone(),
                version: new_version,
                version_id: resp.version_id.clone(),
            };
            self.save_version_sync(&new_version_sync).await?;
            info!("[ConvSync] 已更新版本信息 - 版本: {} -> {}, 版本ID: {}", version, new_version_sync.version, new_version_sync.version_id);
        }

        if let Some(listener) = &self.listener {
            listener.on_sync_server_progress(100).await;
        }
        if let Some(listener) = &self.listener {
            listener.on_sync_server_finish(false).await;
        }

        // 11. 增量同步后按 Seq 校正未读数（错误不影响整体结果）
        if let Err(e) = self.sync_unread_by_seq().await {
            warn!("[ConvSync/Seq] 增量同步后按 Seq 校正未读数失败: {}", e);
        }

        info!("[ConvSync] ✅ 增量同步完成\n");
        Ok(())
    }

    /// 全量同步会话
    async fn full_sync(&self) -> Result<()> {
        let reinstalled = self.get_all_conversation_ids().await?.is_empty();
        debug!("[ConvSync] full_sync -> on_sync_server_start(reinstalled={})", reinstalled);
        if let Some(listener) = &self.listener {
            listener.on_sync_server_start(reinstalled).await;
        }
        debug!("[ConvSync] full_sync -> on_sync_server_progress(10)");
        if let Some(listener) = &self.listener {
            listener.on_sync_server_progress(10).await;
        }

        // 1. 获取服务器所有会话
        let resp = match self.api.get_all_conversations().await {
            Ok(resp) => resp,
            Err(e) => {
                error!("[ConvSync] 全量同步失败: {:?}", e);
                debug!("[ConvSync] full_sync -> on_sync_server_failed(reinstalled={})", reinstalled);
                if let Some(listener) = &self.listener {
                    listener.on_sync_server_failed(reinstalled).await;
                }
                return Err(e);
            }
        };
        info!("[ConvSync] 从服务器获取到 {} 个会话", resp.conversations.len());
        if let Some(listener) = &self.listener {
            listener.on_sync_server_progress(30).await;
        }

        // 2. 转换为本地格式
        let server_conversations: Vec<LocalConversation> = resp.conversations.clone();
        debug!("[ConvSync] 已转换 {} 个会话为本地格式", server_conversations.len());
        debug!("[ConvSync] full_sync -> on_sync_server_progress(50)");
        if let Some(listener) = &self.listener {
            listener.on_sync_server_progress(50).await;
        }

        // 3. 获取本地会话
        let local_conversations = self.get_all_conversations().await?;
        info!("[ConvSync] 本地已有 {} 个会话", local_conversations.len());

        // 4. 先获取 seqs 信息用于设置未读数（参考 Go 版本的 SyncAllConversationHashReadSeqs）
        let seqs_map = match self.api.get_has_read_and_max_seqs().await {
            Ok(seqs) => {
                info!("[ConvSync] 获取到 {} 个会话的 seqs 信息，用于设置未读数", seqs.len());
                Some(seqs)
            }
            Err(e) => {
                warn!("[ConvSync] 获取 seqs 信息失败，将使用默认未读数: {}", e);
                None
            }
        };

        // 同步数据（传入 seqs_map 用于设置未读数）
        self.sync_conversations(server_conversations, local_conversations, seqs_map.as_ref()).await?;
        debug!("[ConvSync] full_sync -> on_sync_server_progress(80)");
        if let Some(listener) = &self.listener {
            listener.on_sync_server_progress(80).await;
        }

        // 5. 更新版本信息（简化处理）
        let new_version = LocalVersionSync {
            table_name: "local_conversations".to_string(),
            entity_id: self.config.user_id.clone(),
            version: 1,
            version_id: Uuid::new_v4().to_string(),
        };
        self.save_version_sync(&new_version).await?;
        info!("[ConvSync] 已更新版本信息 - 版本: {}, 版本ID: {}", new_version.version, new_version.version_id);

        debug!("[ConvSync] full_sync -> on_sync_server_progress(100)");
        if let Some(listener) = &self.listener {
            listener.on_sync_server_progress(100).await;
        }
        debug!("[ConvSync] full_sync -> on_sync_server_finish(reinstalled={})", reinstalled);
        if let Some(listener) = &self.listener {
            listener.on_sync_server_finish(reinstalled).await;
        }

        // 6. 全量同步后按 Seq 校正未读数（错误不影响整体结果）
        if let Err(e) = self.sync_unread_by_seq().await {
            warn!("[ConvSync/Seq] 全量同步后按 Seq 校正未读数失败: {}", e);
        }

        info!("[ConvSync] ✅ 全量同步完成\n");
        Ok(())
    }

    /// 获取会话列表（分页）
    pub async fn get_conversation_list_split(&self, offset: usize, count: usize) -> Result<Vec<LocalConversation>> {
        // 从数据库查询所有会话
        let mut list = self.get_all_conversations().await?;

        // 排序：置顶优先，然后按时间降序
        list.sort_by(|a, b| {
            // 置顶优先
            match (a.is_pinned, b.is_pinned) {
                (true, false) => std::cmp::Ordering::Less,
                (false, true) => std::cmp::Ordering::Greater,
                _ => {
                    // 按时间降序
                    let time_a = a.latest_msg_send_time.max(a.draft_text_time);
                    let time_b = b.latest_msg_send_time.max(b.draft_text_time);
                    time_b.cmp(&time_a)
                }
            }
        });

        // 分页
        let start = offset.min(list.len());
        let end = (offset + count).min(list.len());
        let result = list[start..end].to_vec();
        debug!("[ConvSync] 返回 {} 个会话 (范围: {} - {})", result.len(), start, end);
        Ok(result)
    }

    /// 获取所有会话列表
    pub async fn get_all_conversation_list(&self) -> Result<Vec<LocalConversation>> {
        self.get_conversation_list_split(0, usize::MAX).await
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::im::logger::logger::init_logger;
    use crate::{
        im::conversation::service::ConversationSyncer,
        im::{db::db::create_sqlite_pool_with_migration, login_async},
    };
    use test_context::{test_context, AsyncTestContext};
    use tokio::sync::OnceCell;

    static APP_CTX: OnceCell<AppCtx> = OnceCell::const_new();

    #[derive(Clone)]
    struct AppCtx {
        syncer: Arc<ConversationSyncer>,
    }

    impl AsyncTestContext for AppCtx {
        async fn setup() -> Self {
            APP_CTX
                .get_or_init(|| async {
                    init_logger("rust_lib_flutter_rust_demo=debug,hyper_util::client=info,reqwest=info");
                    let area_code = "+86".to_string();
                    let password = "284f3d09ea0695538e4ded1c1766d73a".to_string();
                    let platform = 5;
                    let token_info = login_async(area_code, "17764338283".to_string(), password, platform).await.expect("登录失败");

                    let db_path = format!("sqlite://{}/conv_sync_{}.db?mode=rwc", std::env::temp_dir().as_path().to_string_lossy(), token_info.user_id.clone());
                    let pool = create_sqlite_pool_with_migration(&db_path).await.expect("创建测试数据库失败");

                    let cfg = ConversationSyncerConfig {
                        user_id: token_info.user_id.clone(),
                        api_base_url: "http://localhost:10002".to_string(),
                        token: token_info.im_token.clone(),
                        db_path,
                    };
                    let syncer = Arc::new(
                        ConversationSyncer::with_listener_and_db_and_client(cfg, None, Arc::new(pool), reqwest::Client::new())
                            .await
                            .expect("创建会话同步器失败"),
                    );
                    AppCtx { syncer }
                })
                .await
                .clone()
        }

        async fn teardown(self) {
            let _ = self;
        }
    }

    #[test_context(AppCtx)]
    #[tokio::test]
    async fn test_conversation_incr_sync(ctx: &mut AppCtx) {
        ctx.syncer.incr_sync_conversations().await.expect("增量同步失败");
    }

    #[test_context(AppCtx)]
    #[tokio::test]
    async fn test_conversation_full_sync(ctx: &mut AppCtx) {
        ctx.syncer.full_sync().await.expect("全量同步失败");
        // 输出数据库中所有会话信息，并检查关键字段
        let conversations = ctx.syncer.get_all_conversations().await.expect("获取会话失败");
        println!("数据库中当前会话信息数量: {}", conversations.len());
        for (i, conv) in conversations.iter().enumerate() {
            println!("会话#{}: {:?}", i + 1, conv);
            assert!(!conv.conversation_id.is_empty(), "conversation_id 不能为空");
            assert!(conv.conversation_type != 0, "conversation_type 不能为 0");
            // Go 行为：若服务端未返回最新消息字段，允许 show_name/face_url/latest_msg_send_time 为空，等待消息路径刷新
        }
    }
}
