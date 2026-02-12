//! 消息同步器（参考 go/internal/interaction/msg_sync.go）
use crate::im::client::conversation_handle::{ConvCmd, ConvCmdKind};
use crate::im::dao::repository::Repository;
use crate::im::model::constant;
use crate::im::model::constant::sync_flag;
use crate::im::model::message::SeqRange as SeqRangeModel;
use crate::im::model::ws::{self, WsRpcEnvelope};
use crate::im::util;
use anyhow::{anyhow, Result};
use openim_protocol::{prost, sdkws};
use sqlx::{Pool, Sqlite};
use std::collections::HashMap;
use tokio::sync::{mpsc, oneshot};
use tokio::time::{timeout, Duration};
use tokio_util::sync::CancellationToken;
use tracing::*;

const CONNECT_PULL_NUMS: i64 = 1;
const DEFAULT_PULL_NUMS: i64 = 10;
const SPLIT_PULL_MSG_NUM: i64 = 100;
const LONG_CONN_TIMEOUT_SECS: u64 = 5;

/// 具体命令类型（不含 tracing 上下文）
#[derive(Debug)]
pub enum MsgSyncCommandKind {
    /// 长连已连接
    Connected,
    /// App 唤醒触发同步
    Wakeup,
    /// 手动触发指定会话的同步
    ManualSync(Vec<String>),
    /// 推送消息
    Push { push: sdkws::PushMessages },
}

/// 命令信封：具体命令 + span，用于与调用方 tracing 串起来（接收端只对传入 span instrument）
#[derive(Debug)]
pub struct MsgSyncCommand {
    pub kind: MsgSyncCommandKind,
    pub span: tracing::Span,
}

impl MsgSyncCommand {
    /// 在传递位置创建 span，处理处只 enter/instrument
    pub fn with_span(kind: MsgSyncCommandKind) -> Self {
        let span = match &kind {
            MsgSyncCommandKind::Connected => info_span!(parent: tracing::Span::current(), "msg_sync.command:Connected"),
            MsgSyncCommandKind::Wakeup => info_span!(parent: tracing::Span::current(), "msg_sync.command:Wakeup"),
            MsgSyncCommandKind::ManualSync(_) => info_span!(parent: tracing::Span::current(), "msg_sync.command:ManualSync"),
            MsgSyncCommandKind::Push { .. } => info_span!(parent: tracing::Span::current(), "msg_sync.command:Push"),
        };
        Self { kind, span }
    }
}

/// 消息同步器，actor 化：仅通过命令/事件通道与外界交互
pub struct MessageHandle {
    login_user_id: String,
    reinstalled: bool,
    is_syncing: bool,
    repository: Repository,
    synced_max_seqs: HashMap<String, i64>,
    /// 消息/事件输入通道
    cmd_rx: mpsc::UnboundedReceiver<MsgSyncCommand>,
    event_tx: mpsc::UnboundedSender<MsgSyncTriggerEvent>,
    /// 会话命令通道：将新消息/通知/重装同步命令传递给 conversation_handle
    conv_cmd_tx: mpsc::UnboundedSender<ConvCmd>,
    ws_rpc_tx: mpsc::UnboundedSender<WsRpcEnvelope>,
    cancel_token: CancellationToken,
}

impl MessageHandle {
    pub fn new(
        login_user_id: String,
        repository: Repository,
        ws_rpc_tx: mpsc::UnboundedSender<WsRpcEnvelope>,
        cancel_token: CancellationToken,
        event_tx: mpsc::UnboundedSender<MsgSyncTriggerEvent>,
        cmd_rx: mpsc::UnboundedReceiver<MsgSyncCommand>,
        conv_cmd_tx: mpsc::UnboundedSender<ConvCmd>,
    ) -> Self {
        Self {
            login_user_id,
            repository,
            event_tx,
            cmd_rx,
            conv_cmd_tx,
            synced_max_seqs: HashMap::new(),
            reinstalled: false,
            is_syncing: false,
            ws_rpc_tx,
            cancel_token,
        }
    }

    pub fn set_login_user_id(&mut self, login_user_id: String) {
        self.login_user_id = login_user_id;
    }

    /// 从本地数据库装载已同步的 seq，参考 Go 的 LoadSeq
    pub async fn load_seq(&mut self) -> Result<()> {
        // 1) 取全部会话 ID
        let ids = self.repository.conversation.get_all_conversation_ids().await?;
        if ids.is_empty() {
            self.reinstalled = true;
            debug!("[message_handle] no local conversations, mark reinstalled=true");
        }

        // 2) 逐会话读取消息表最大 seq（对等 Go 的 CheckConversationNormalMsgSeq）
        for conv_id in ids {
            let max_seq = self.repository.message.check_conversation_normal_msg_seq(&conv_id).await.unwrap_or(0);
            self.synced_max_seqs.insert(conv_id, max_seq);
        }

        // 3) 读取通知类 seq（若表存在）
        if let Ok(notification_seqs) = self.repository.notification_dao.get_notification_all_seqs().await {
            for item in notification_seqs {
                self.synced_max_seqs.insert(item.conversation_id, item.seq);
            }
        }

        debug!("[message_handle] load_seq done, synced_max_seqs size={}", self.synced_max_seqs.len());
        Ok(())
    }

    /// 主循环：监听命令通道并分发（占位）
    pub async fn run(&mut self) -> Result<()> {
        loop {
            let cmd = tokio::select! {
                _ = self.cancel_token.cancelled() => {
                    warn!("[message_handle] 收到取消信号，退出监听器");
                    return Ok(());
                }
                cmd = self.cmd_rx.recv() => cmd,
            };
            let Some(envelope) = cmd else {
                debug!("[message_handle] cmd_rx 已关闭，监听器退出");
                return Ok(());
            };
            // 使用传递位置创建的 span，enter 覆盖整次处理，单次 loop 结束即关闭 span
            let _guard = envelope.span.enter();
            debug!("[message_handle] 收到命令 {:?}", envelope.kind);
            let result = match envelope.kind {
                MsgSyncCommandKind::Connected => {
                    debug!("[message_handle] 收到 Connected 事件");
                    self.do_connected().await
                }
                MsgSyncCommandKind::Wakeup => {
                    debug!("[message_handle] 收到 Wakeup 事件");
                    self.do_wakeup_data_sync().await
                }
                MsgSyncCommandKind::ManualSync(conversation_ids) => {
                    debug!("[message_handle] 收到 ManualSync 事件, conversations={:?}", conversation_ids);
                    self.do_im_message_sync(conversation_ids).await
                }
                MsgSyncCommandKind::Push { push } => self.do_push_msg(None, &push).await,
            };
            if let Err(e) = result {
                warn!("[message_handle] 处理命令失败: {e}");
            }
        }
    }

    /// 简化版开始同步标记，避免并发同步
    async fn start_sync(&mut self) -> bool {
        if self.is_syncing {
            return false;
        }
        self.is_syncing = true;

        // 与 Go 逻辑对齐：5 秒后自动清理同步标记，避免卡死
        // tokio::spawn(async move {
        //     sleep(Duration::from_secs(5)).await;
        //     self.is_syncing = false;
        // });
        true
    }

    fn is_notification(conv_id: &str) -> bool {
        conv_id.starts_with("n_")
    }
    #[tracing::instrument(skip(self))]
    async fn do_connected(&mut self) -> Result<()> {
        if !self.start_sync().await {
            info!("[message_handle] 正在同步，忽略 Connected 事件");
            return Ok(());
        }
        // 通知会话处理器：开始应用数据同步（SyncFlag AppDataSyncStart）
        let _ = self.conv_cmd_tx.send(ConvCmd::with_span(ConvCmdKind::SyncFlag(sync_flag::APP_DATA_SYNC_START)));
        let _ = self.conv_cmd_tx.send(ConvCmd::with_span(ConvCmdKind::SyncData));
        let reinstalled = self.reinstalled;
        let newest = self.get_newest_seq().await?;
        self.compare_seqs_and_batch_sync(newest, CONNECT_PULL_NUMS, reinstalled).await?;
        Ok(())
    }

    #[tracing::instrument(skip(self), name = "msg_sync.wakeup")]
    async fn do_wakeup_data_sync(&mut self) -> Result<()> {
        if !self.start_sync().await {
            debug!("[message_handle] 正在同步，忽略 Wakeup 事件");
            return Ok(());
        }
        let resp = self.get_newest_seq().await?;
        let reinstalled = self.reinstalled;
        self.compare_seqs_and_batch_sync(resp, DEFAULT_PULL_NUMS, reinstalled).await?;
        Ok(())
    }

    #[tracing::instrument(skip(self), name = "msg_sync.manual", fields(n = conversation_ids.len()))]
    async fn do_im_message_sync(&mut self, conversation_ids: Vec<String>) -> Result<()> {
        // 兜底策略：暂缺 GetConversationsHasReadAndMaxSeq 接口，先用最新 maxSeq 过滤
        let resp = self.get_newest_seq().await?;
        let filtered = resp.into_iter().filter(|(id, _)| conversation_ids.contains(id)).collect::<HashMap<_, _>>();
        if filtered.is_empty() {
            debug!("[message_handle] ManualSync 无匹配会话，跳过");
            return Ok(());
        }
        let reinstalled = self.reinstalled;
        self.compare_seqs_and_batch_sync(filtered, DEFAULT_PULL_NUMS, reinstalled).await?;
        Ok(())
    }

    /// 处理推送消息（对齐 go 的 doPushMsg）；msg_id 为 None 时表示不串联单条 Push 链路
    #[tracing::instrument(skip(self, push), name = "push_msg")]
    async fn do_push_msg(&mut self, msg_id: Option<&str>, push: &sdkws::PushMessages) -> Result<()> {
        self.push_trigger_and_sync(msg_id, &push.msgs, false).await?;
        self.push_trigger_and_sync(msg_id, &push.notification_msgs, true).await?;
        Ok(())
    }

    /// 核心触发与判定逻辑（对齐 Go pushTriggerAndSync）；msg_id 为 None 时表示非单条 Push 链路（如 sync 补拉）
    #[tracing::instrument(skip(self, push_messages), name = "push_trigger_and_sync", fields(is_notification = is_notification, convs = push_messages.len()))]
    async fn push_trigger_and_sync(&mut self, msg_id: Option<&str>, push_messages: &HashMap<String, sdkws::PullMsgs>, is_notification: bool) -> Result<()> {
        if push_messages.is_empty() {
            return Ok(());
        }
        let mut need_sync_seq_map: HashMap<String, (i64, i64)> = HashMap::new();
        let mut last_seq: i64 = 0;
        let mut storage_msgs: Vec<sdkws::MsgData> = Vec::new();

        for (conversation_id, pull) in push_messages {
            if pull.msgs.is_empty() {
                continue;
            }
            for msg in &pull.msgs {
                if msg.seq == 0 {
                    if is_notification {
                        self.trigger_notification(msg_id, &self.create_pull_msgs(conversation_id, &[msg.clone()])).await?;
                    } else {
                        self.trigger_conversation(msg_id, &self.create_pull_msgs(conversation_id, &[msg.clone()])).await?;
                    }
                    continue;
                }

                last_seq = msg.seq;
                storage_msgs.push(msg.clone());
            }

            let synced_seq = *self.synced_max_seqs.get(conversation_id).unwrap_or(&0);

            if last_seq != 0 && last_seq == synced_seq + storage_msgs.len() as i64 && !storage_msgs.is_empty() {
                self.trigger_msgs(conversation_id, &storage_msgs, is_notification).await?;

                if is_notification {
                    self.trigger_notification(msg_id, &self.create_pull_msgs(conversation_id, &storage_msgs)).await?;
                } else {
                    self.trigger_conversation(msg_id, &self.create_pull_msgs(conversation_id, &storage_msgs)).await?;
                }
                self.synced_max_seqs.insert(conversation_id.clone(), last_seq);
            } else if last_seq > synced_seq && last_seq != 0 {
                need_sync_seq_map.insert(conversation_id.clone(), (synced_seq + 1, last_seq));
            }
        }
        self.sync_and_trigger_msgs(&need_sync_seq_map, DEFAULT_PULL_NUMS).await?;
        Ok(())
    }

    #[tracing::instrument(skip(self, msgs), name = "create_pull_msgs", fields(conversation_id = %conversation_id, n = msgs.len()))]
    fn create_pull_msgs(&self, conversation_id: &str, msgs: &[sdkws::MsgData]) -> HashMap<String, sdkws::PullMsgs> {
        let pull_msgs = HashMap::from([(
            conversation_id.clone().to_string(),
            sdkws::PullMsgs {
                msgs: msgs.to_vec(),
                is_end: false,
                end_seq: 0,
            },
        )]);
        pull_msgs
    }
    #[tracing::instrument(skip(self, seq_map), name = "sync_and_trigger_msgs", fields(convs = seq_map.len(), sync_msg_num = sync_msg_num))]
    async fn sync_and_trigger_msgs(&mut self, seq_map: &HashMap<String, (i64, i64)>, sync_msg_num: i64) -> Result<()> {
        if seq_map.is_empty() {
            debug!("[message_handle] nothing to sync, sync_msg_num={}", sync_msg_num);
            return Ok(());
        }

        debug!("[message_handle] current sync seq_map: {:?}", seq_map);

        let mut temp_seq_map: HashMap<String, (i64, i64)> = HashMap::with_capacity(50);
        let mut msg_num: i64 = 0;

        for (conv_id, range) in seq_map {
            let one_conversation_sync_num = range.1 - range.0 + 1;
            temp_seq_map.insert(conv_id.clone(), *range);

            let is_notification = Self::is_notification(conv_id);
            msg_num += if is_notification {
                one_conversation_sync_num
            } else {
                one_conversation_sync_num.min(sync_msg_num)
            };

            // 达到分批推拉的数量后拉取一批
            if msg_num >= SPLIT_PULL_MSG_NUM {
                let resp = self.pull_msg_by_seq_range(&temp_seq_map, sync_msg_num).await?;
                self.trigger_conversation(None, &resp.msgs).await?;
                self.trigger_notification(None, &resp.notification_msgs).await?;
                // 同步最大seqs
                for (conversation_id, seqs) in &temp_seq_map {
                    self.synced_max_seqs.insert(conversation_id.clone(), seqs.1);
                }
                // 重置临时map和msgNum
                temp_seq_map = HashMap::with_capacity(50);
                msg_num = 0;
            }
        }

        // 拉最后一批剩余的map
        if !temp_seq_map.is_empty() {
            let resp = self.pull_msg_by_seq_range(&temp_seq_map, sync_msg_num).await?;
            self.trigger_conversation(None, &resp.msgs).await?;
            self.trigger_notification(None, &resp.notification_msgs).await?;
            for (conversation_id, seqs) in &temp_seq_map {
                self.synced_max_seqs.insert(conversation_id.clone(), seqs.1);
            }
        }
        Ok(())
    }
    /// 占位：触发会话/通知消息到上层
    #[tracing::instrument(skip(self, msgs), name = "trigger_msgs", fields(conversation_id = %conversation_id, n = msgs.len(), is_notification = is_notification))]
    async fn trigger_msgs(&self, conversation_id: &str, msgs: &[sdkws::MsgData], is_notification: bool) -> Result<()> {
        debug!("[message_handle] trigger_msgs conv={} len={} is_notification={}", conversation_id, msgs.len(), is_notification);
        // TODO: 分发到事件队列 / 存储
        Ok(())
    }

    /// 触发有新消息的会话事件（msg_id 用于 tracing 串联，非 Push 链路传 None）
    #[tracing::instrument(skip(self, msgs), name = "trigger_conversation", fields(msg_id = ?msg_id, convs = msgs.len()))]
    async fn trigger_conversation(&self, msg_id: Option<&str>, msgs: &std::collections::HashMap<String, sdkws::PullMsgs>) -> Result<()> {
        if msgs.is_empty() {
            debug!("[message_handle] trigger_conversation empty");
            return Ok(());
        }
        debug!(msg_id = ?msg_id, "[ConvSync] 发送 NewMsgCome 会话数={}", msgs.len());
        let _ = self.conv_cmd_tx.send(ConvCmd::with_span(ConvCmdKind::NewMsgCome {
            msg_id: msg_id.map(String::from),
            msgs: msgs.clone(),
        }));
        let _ = self.event_tx.send(MsgSyncTriggerEvent::Conversation(msgs.clone()));
        Ok(())
    }

    /// 安装（例如重装）时同步会话消息
    #[tracing::instrument(skip(self, msgs), name = "trigger_reinstall_conversation", fields(msg_id = ?msg_id, convs = msgs.len(), total = total))]
    async fn trigger_reinstall_conversation(&self, msg_id: Option<&str>, msgs: &std::collections::HashMap<String, sdkws::PullMsgs>, total: i32) -> Result<()> {
        if msgs.is_empty() {
            debug!("[message_handle] trigger_reinstall_conversation empty");
            return Ok(());
        }
        debug!(msg_id = ?msg_id, "[ConvSync] 发送 MsgSyncInReinstall total={}", total);
        let _ = self.conv_cmd_tx.send(ConvCmd::with_span(ConvCmdKind::MsgSyncInReinstall {
            msg_id: msg_id.map(String::from),
            msgs: msgs.clone(),
            total,
        }));
        let _ = self.event_tx.send(MsgSyncTriggerEvent::Reinstall { msgs: msgs.clone(), total });
        Ok(())
    }

    /// 触发通知消息事件（msg_id 用于 tracing 串联）
    #[tracing::instrument(skip(self, msgs), name = "trigger_notification", fields(msg_id = ?msg_id, convs = msgs.len()))]
    async fn trigger_notification(&self, msg_id: Option<&str>, msgs: &std::collections::HashMap<String, sdkws::PullMsgs>) -> Result<()> {
        if msgs.is_empty() {
            event!(Level::TRACE, "[message_handle] trigger_notification empty");
            return Ok(());
        }
        event!(Level::TRACE, msg_id = ?msg_id, "[ConvSync] 发送 Notification 会话数={}", msgs.len());
        let _ = self.conv_cmd_tx.send(ConvCmd::with_span(ConvCmdKind::Notification {
            msg_id: msg_id.map(String::from),
            msgs: msgs.clone(),
        }));
        let _ = self.event_tx.send(MsgSyncTriggerEvent::Notification(msgs.clone()));
        Ok(())
    }
    #[instrument(skip(self),fields(max_seq_to_sync.len = max_seq_to_sync.len(), pull_nums = pull_nums, reinstalled = reinstalled))]
    async fn compare_seqs_and_batch_sync(&mut self, max_seq_to_sync: HashMap<String, i64>, pull_nums: i64, reinstalled: bool) -> Result<()> {
        let mut need_sync_seq_map: HashMap<String, (i64, i64)> = HashMap::new();

        if reinstalled {
            // 重装：通知会话直接写入最大 seq，不再拉取；消息会话拉全量或增量
            for (conversation_id, max_seq) in max_seq_to_sync {
                if Self::is_notification(&conversation_id) {
                    if max_seq != 0 {
                        self.synced_max_seqs.insert(conversation_id, max_seq);
                        // TODO: 持久化通知 seq（参考 Go 的 BatchInsertNotificationSeq）
                    }
                    continue;
                }

                let synced = *self.synced_max_seqs.get(&conversation_id).unwrap_or(&0);
                if max_seq > synced {
                    let begin = if synced == 0 { 0 } else { synced + 1 };
                    need_sync_seq_map.insert(conversation_id.clone(), (begin, max_seq));
                }
            }

            // TODO: 对齐 Go 的 syncAndTriggerReinstallMsgs（当前复用普通路径）
            self.sync_and_trigger_msgs(&need_sync_seq_map, pull_nums).await?;

            self.reinstalled = false;
            Ok(())
        } else {
            // 非重装：常规增量
            for (conversation_id, max_seq) in max_seq_to_sync {
                let synced = *self.synced_max_seqs.get(&conversation_id).unwrap_or(&0);
                if max_seq > synced {
                    let begin = if synced == 0 { 0 } else { synced + 1 };
                    need_sync_seq_map.insert(conversation_id.clone(), (begin, max_seq));
                }
            }
            self.sync_and_trigger_msgs(&need_sync_seq_map, pull_nums).await
        }
    }

    #[tracing::instrument(skip(self, seq_map), name = "pull_msg_by_seq_range", fields(convs = seq_map.len(), sync_msg_num = sync_msg_num))]
    pub async fn pull_msg_by_seq_range(&self, seq_map: &std::collections::HashMap<String, (i64, i64)>, sync_msg_num: i64) -> Result<sdkws::PullMessageBySeqsResp> {
        trace!("[Rpc] pull_msg_by_seq_range seq_map={:?}, sync_msg_num={}", seq_map, sync_msg_num);

        let ranges: Vec<SeqRangeModel> = seq_map
            .iter()
            .map(|(conversation_id, seqs)| SeqRangeModel {
                conversation_id: conversation_id.clone(),
                begin: seqs.0,
                end: seqs.1,
                num: sync_msg_num,
            })
            .collect();

        self.pull_msg_by_range(ranges).await
    }

    #[tracing::instrument(skip(self))]
    async fn get_newest_seq(&self) -> Result<HashMap<String, i64>> {
        let req = self.make_ws_req(constant::GET_NEWEST_SEQ, sdkws::GetMaxSeqReq { user_id: self.login_user_id.clone() })?;
        let resp = self.send_ws_req_wait(req).await?;
        let decoded: sdkws::GetMaxSeqResp = self.decode_ws_resp(&resp)?;
        let max_seqs = decoded.max_seqs;
        tracing::event!(
            tracing::Level::DEBUG,
            len = max_seqs.len(),
            entries = ?max_seqs,
            "[message_handle] get_newest_seq 结果"
        );
        Ok(max_seqs)
    }

    #[tracing::instrument(skip(self, ranges), name = "pull_msg_by_range", fields(n = ranges.len()))]
    async fn pull_msg_by_range(&self, ranges: Vec<SeqRangeModel>) -> Result<sdkws::PullMessageBySeqsResp> {
        let req = self.make_ws_req(
            constant::PULL_MSG_BY_RANGE,
            sdkws::PullMessageBySeqsReq {
                user_id: self.login_user_id.clone(),
                seq_ranges: ranges
                    .into_iter()
                    .map(|r| sdkws::SeqRange {
                        conversation_id: r.conversation_id,
                        begin: r.begin,
                        end: r.end,
                        num: r.num,
                    })
                    .collect(),
                order: 0,
            },
        )?;
        let resp = self.send_ws_req_wait(req).await?;
        let decoded: sdkws::PullMessageBySeqsResp = self.decode_ws_resp(&resp)?;
        Ok(decoded)
    }
    /// 构造通用 WS 请求（protobuf -> bytes）；operation_id 使用当前 OTel trace_id:span_id 便于响应端通过 trace_id 建子 span
    fn make_ws_req<M: prost::Message>(&self, req_identifier: i32, msg: M) -> Result<ws::OpenIMReq> {
        let data = msg.encode_to_vec();
        Ok(crate::im::model::ws::OpenIMReq {
            req_identifier,
            token: String::new(),
            send_id: self.login_user_id.clone(),
            operation_id: crate::im::trace_context::operation_id_from_otel(),
            msg_incr: crate::im::util::make_msg_incr(),
            data,
        })
    }

    async fn send_ws_req_wait(&self, req: ws::OpenIMReq) -> Result<ws::OpenIMResp> {
        let (tx, rx) = oneshot::channel();
        let envelope: crate::im::model::ws::WsRpcEnvelope = (req, Some(tx));

        self.ws_rpc_tx.send(envelope).map_err(|_| anyhow!("long_conn_mgr channel closed"))?;

        match timeout(Duration::from_secs(LONG_CONN_TIMEOUT_SECS), rx).await {
            Ok(Ok(resp)) => Ok(resp),
            Ok(Err(e)) => Err(anyhow!("long_conn_mgr oneshot dropped: {:?}", e)),
            Err(_) => Err(anyhow!("long_conn_mgr timeout")),
        }
    }

    fn decode_ws_resp<T: prost::Message + Default>(&self, resp: &crate::im::model::ws::OpenIMResp) -> Result<T> {
        if resp.err_code != 0 {
            return Err(anyhow!("ws rpc err code={}, msg={}", resp.err_code, resp.err_msg));
        }
        prost::Message::decode(resp.data.as_slice()).map_err(|e| anyhow!("decode ws resp failed: {e}"))
    }
}

/// MsgSyncer 输出给上层的事件（可由 UI/监听器消费）
#[derive(Debug)]
pub enum MsgSyncTriggerEvent {
    Conversation(HashMap<String, sdkws::PullMsgs>),
    Reinstall { msgs: HashMap<String, sdkws::PullMsgs>, total: i32 },
    Notification(HashMap<String, sdkws::PullMsgs>),
}
