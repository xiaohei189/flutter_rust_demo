use std::future::Future;
use std::pin::Pin;
use std::sync::Arc;

use tokio::sync::{mpsc, oneshot};
use tracing::{debug, info, warn};

use crate::domain::error::types::SdkError;
use crate::protocol::sdkws::UserSendMsgResp;

/// 媒体消息 content_type（图片/语音/视频/文件）
const MEDIA_CONTENT_TYPES: [i32; 4] = [102, 103, 104, 105];

/// 单条消息的发送结果
pub type SendResult = std::result::Result<UserSendMsgResp, SdkError>;

type BoxFuture<T> = Pin<Box<dyn Future<Output = T> + Send>>;

/// 发送任务：封装一次消息发送的全部信息
struct SendTask {
    /// 实际执行发送的闭包（async）
    send_fn: Box<dyn FnOnce() -> BoxFuture<SendResult> + Send>,
    /// 将结果回传给调用方
    result_tx: oneshot::Sender<SendResult>,
}

/// 双 Lane 消息发送队列
///
/// - Lane A（高优先级）：文本消息（content_type 101, 106, 114, 117, 118）和命令消息
/// - Lane B（低优先级）：媒体消息（content_type 102, 103, 104, 105）
/// - 两个 Lane 并行发送，互不阻塞
/// - 同一 Lane 内按顺序发送（FIFO）
pub struct MessageSendQueue {
    high_tx: mpsc::Sender<SendTask>,
    low_tx: mpsc::Sender<SendTask>,
}

impl MessageSendQueue {
    /// 创建双 Lane 队列并启动后台消费任务
    pub fn new() -> Arc<Self> {
        let (high_tx, high_rx) = mpsc::channel::<SendTask>(256);
        let (low_tx, low_rx) = mpsc::channel::<SendTask>(256);

        // Lane A：高优先级（文本/命令消息）
        tokio::spawn(Self::lane_worker("high", high_rx));
        // Lane B：低优先级（媒体消息）
        tokio::spawn(Self::lane_worker("low", low_rx));

        debug!("MessageSendQueue: 双 Lane 发送队列已启动");

        Arc::new(Self { high_tx, low_tx })
    }

    /// 后台消费任务：从 channel 中逐条取出并执行
    async fn lane_worker(name: &'static str, mut rx: mpsc::Receiver<SendTask>) {
        debug!("send_queue lane[{}]: worker started", name);
        while let Some(task) = rx.recv().await {
            let result = (task.send_fn)().await;
            if task.result_tx.send(result).is_err() {
                warn!("send_queue lane[{}]: result receiver dropped", name);
            }
        }
        debug!("send_queue lane[{}]: worker stopped (channel closed)", name);
    }

    /// 提交一条消息到发送队列
    ///
    /// - 根据 content_type 自动选择 Lane
    /// - 返回 oneshot::Receiver，调用方 await 获取发送结果
    pub async fn submit<F>(&self, content_type: i32, send_fn: F) -> SendResult
    where
        F: FnOnce() -> BoxFuture<SendResult> + Send + 'static,
    {
        let (result_tx, result_rx) = oneshot::channel();

        let task = SendTask {
            send_fn: Box::new(send_fn),
            result_tx,
        };

        let tx = if is_media_content_type(content_type) {
            &self.low_tx
        } else {
            &self.high_tx
        };

        tx.send(task).await.map_err(|_| {
            SdkError::message_send("send queue closed")
        })?;

        result_rx.await.map_err(|_| {
            SdkError::message_send("send task cancelled")
        })?
    }

    /// 判断 content_type 是否为媒体类型
    pub fn is_media_type(content_type: i32) -> bool {
        is_media_content_type(content_type)
    }
}

/// 判断是否为媒体消息类型（图片/语音/视频/文件）
fn is_media_content_type(content_type: i32) -> bool {
    MEDIA_CONTENT_TYPES.contains(&content_type)
}
