//! 会话处理模块（对齐 Go internal/conversation_msg）
//!
//! 通过命令通道接收消息同步器下发的会话相关命令，执行会话更新、通知、同步等逻辑。

use crate::im::dao::repository::Repository;
use crate::im::listener::ConversationListener;
use crate::im::model::LocalConversation;
use anyhow::Result;
use openim_protocol::sdkws;
use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::mpsc;
use tokio_util::sync::CancellationToken;
use tracing::{debug, warn};

// ---------- 命令类型（对齐 Go pkg/constant Cmd* 与 common.Cmd2Value） ----------

/// 会话侧命令（对应 Go 的 conversationEventQueue 收到的 Cmd2Value）
#[derive(Debug)]
pub enum ConvCmd {
    /// 新消息到达会话（constant.CmdNewMsgCome）
    NewMsgCome(HashMap<String, sdkws::PullMsgs>),
    /// 更新会话（constant.CmdUpdateConversation）
    UpdateConversation(UpdateConNode),
    /// 通知消息（constant.CmdNotification）
    Notification(HashMap<String, sdkws::PullMsgs>),
    /// 同步阶段标记（constant.CmdSyncFlag）
    SyncFlag(i32),
    /// 同步数据（constant.CmdSyncData）
    SyncData,
    /// 重装后消息同步（constant.CmdMsgSyncInReinstall）
    MsgSyncInReinstall { msgs: HashMap<String, sdkws::PullMsgs>, total: i32 },
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

// ---------- 会话处理器 ----------

pub struct ConversationHandle {
    login_user_id: String,
    repository: Repository,
    listener: Option<Arc<dyn ConversationListener>>,
    cmd_rx: mpsc::UnboundedReceiver<ConvCmd>,
    cancel_token: CancellationToken,
}

impl ConversationHandle {
    pub fn new(
        login_user_id: String,
        repository: Repository,
        cmd_rx: mpsc::UnboundedReceiver<ConvCmd>,
        cancel_token: CancellationToken,
        listener: Option<Arc<dyn ConversationListener>>,
    ) -> Self {
        Self {
            login_user_id,
            repository,
            listener,
            cmd_rx,
            cancel_token,
        }
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
            let Some(cmd) = cmd else {
                debug!("[conversation_handle] cmd_rx 已关闭，退出");
                return Ok(());
            };
            if let Err(e) = self.work(cmd).await {
                warn!("[conversation_handle] 处理命令失败: {e}");
            }
        }
    }

    async fn work(&mut self, cmd: ConvCmd) -> Result<()> {
        match cmd {
            ConvCmd::NewMsgCome(msgs) => self.do_msg_new(msgs).await,
            ConvCmd::UpdateConversation(node) => self.do_update_conversation(node).await,
            ConvCmd::Notification(msgs) => self.do_notification_manager(msgs).await,
            ConvCmd::SyncFlag(flag) => self.sync_flag(flag).await,
            ConvCmd::SyncData => self.sync_data().await,
            ConvCmd::MsgSyncInReinstall { msgs, total } => self.do_msg_sync_by_reinstalled(msgs, total).await,
        }
    }

    /// 新消息到达会话（Go doMsgNew）
    async fn do_msg_new(&self, _msgs: HashMap<String, sdkws::PullMsgs>) -> Result<()> {
        debug!("[conversation_handle] do_msg_new, convs={}", _msgs.len());
        // TODO: 遍历 msgs，更新各会话的 latestMsg / 未读数，落库并触发 listener
        Ok(())
    }

    /// 更新会话（Go doUpdateConversation）
    async fn do_update_conversation(&self, node: UpdateConNode) -> Result<()> {
        debug!("[conversation_handle] do_update_conversation action={} con_id={}", node.action, node.con_id);
        // TODO: 按 node.action 分支：删除/更新/置顶/未读清零/通知变更等
        Ok(())
    }

    /// 通知消息处理（Go doNotificationManager）
    async fn do_notification_manager(&self, _msgs: HashMap<String, sdkws::PullMsgs>) -> Result<()> {
        debug!("[conversation_handle] do_notification_manager, convs={}", _msgs.len());
        // TODO: 按 contentType 分发好友/群/会话通知，更新通知 seq
        Ok(())
    }

    /// 同步阶段标记（Go syncFlag）
    async fn sync_flag(&self, _flag: i32) -> Result<()> {
        debug!("[conversation_handle] sync_flag flag={}", _flag);
        // TODO: AppDataSyncStart / MsgSyncBegin / MsgSyncEnd 等，回调 listener
        Ok(())
    }

    /// 同步数据（Go syncData）
    async fn sync_data(&self) -> Result<()> {
        debug!("[conversation_handle] sync_data");
        // TODO: 增量同步会话等
        Ok(())
    }

    /// 重装后消息同步（Go doMsgSyncByReinstalled）
    async fn do_msg_sync_by_reinstalled(&self, _msgs: HashMap<String, sdkws::PullMsgs>, _total: i32) -> Result<()> {
        debug!("[conversation_handle] do_msg_sync_by_reinstalled total={}", _total);
        // TODO: 重装场景下会话与消息同步
        Ok(())
    }
}
