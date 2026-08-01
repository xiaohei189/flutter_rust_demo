use std::future::Future;
use std::pin::Pin;
use std::sync::Arc;

use tokio::sync::{mpsc, oneshot};
use tracing::{debug, warn, Instrument};

use crate::core::message::shared::content_type::ContentTypeUtils;
use crate::domain::error::SdkError;
use crate::infra::logger::{encode_operation_id, extract_span_id, extract_trace_id, span_from_operation_id};
use openim_protocol::sdkws::UserSendMsgResp;

/// 单条消息的发送结果
pub type SendResult = std::result::Result<UserSendMsgResp, SdkError>;

type BoxFuture<T> = Pin<Box<dyn Future<Output = T> + Send>>;

/// 发送任务：封装一次消息发送的全部信息
struct SendTask {
    /// 实际执行发送的闭包（async）
    send_fn: Box<dyn FnOnce() -> BoxFuture<SendResult> + Send>,
    /// 提交时的 trace 上下文（encode_operation_id 编码的 trace_id:span_id 字符串）
    operation_id: String,
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
            // 官方推荐：worker 不跨任务持有 Span 句柄，而是用提交时提取的
            // 字符串上下文重建 span，并通过 .instrument 绑定到发送 future
            let span = span_from_operation_id("send_queue_lane", &task.operation_id);
            let result = (task.send_fn)().instrument(span).await;
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
        // 官方推荐：跨 task 不传 Span 句柄，只提取 trace 上下文字符串，
        // 由 lane worker 消费时重建本地 span（避免对已关闭 span 调用 enter）
        let trace_id = extract_trace_id();
        let span_id = extract_span_id();
        let operation_id = encode_operation_id(&trace_id, span_id);
        let (result_tx, result_rx) = oneshot::channel();

        let task = SendTask {
            send_fn: Box::new(send_fn),
            operation_id,
            result_tx,
        };

        let tx = if ContentTypeUtils::is_media(content_type) {
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
        ContentTypeUtils::is_media(content_type)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    // ========================================================================
    // ContentTypeUtils::is_media 路由测试
    // ========================================================================

    #[test]
    fn test_media_types_are_media() {
        assert!(ContentTypeUtils::is_media(102)); // PICTURE
        assert!(ContentTypeUtils::is_media(103)); // SOUND
        assert!(ContentTypeUtils::is_media(104)); // VIDEO
        assert!(ContentTypeUtils::is_media(105)); // FILE
    }

    #[test]
    fn test_non_media_types() {
        assert!(!ContentTypeUtils::is_media(101)); // TEXT
        assert!(!ContentTypeUtils::is_media(106)); // AT_TEXT
        assert!(!ContentTypeUtils::is_media(113)); // TYPING
        assert!(!ContentTypeUtils::is_media(114)); // QUOTE
        assert!(!ContentTypeUtils::is_media(119)); // CUSTOM_NOT_TRIGGER
        assert!(!ContentTypeUtils::is_media(120)); // CUSTOM_ONLINE_ONLY
        assert!(!ContentTypeUtils::is_media(0));
        assert!(!ContentTypeUtils::is_media(-1));
        assert!(!ContentTypeUtils::is_media(999));
    }

    #[test]
    fn test_is_media_type_public_api() {
        // 确保公开 API 和 ContentTypeUtils 行为一致
        assert_eq!(MessageSendQueue::is_media_type(102), ContentTypeUtils::is_media(102));
        assert_eq!(MessageSendQueue::is_media_type(101), ContentTypeUtils::is_media(101));
    }

    // ========================================================================
    // 队列路由行为测试
    // ========================================================================

    #[tokio::test]
    async fn test_text_message_goes_to_high_lane() {
        let queue = MessageSendQueue::new();
        // 文本消息应走 high lane，并正常返回结果
        let result = queue.submit(101, || {
            Box::pin(async {
                Ok(UserSendMsgResp {
                    server_msg_id: "srv_1".to_string(),
                    client_msg_id: "cli_1".to_string(),
                    send_time: 1000,
                })
            })
        }).await;
        assert!(result.is_ok());
        assert_eq!(result.unwrap().server_msg_id, "srv_1");
    }

    #[tokio::test]
    async fn test_media_message_goes_to_low_lane() {
        let queue = MessageSendQueue::new();
        // 媒体消息应走 low lane，并正常返回结果
        let result = queue.submit(102, || {
            Box::pin(async {
                Ok(UserSendMsgResp {
                    server_msg_id: "srv_media".to_string(),
                    client_msg_id: "cli_media".to_string(),
                    send_time: 2000,
                })
            })
        }).await;
        assert!(result.is_ok());
        assert_eq!(result.unwrap().server_msg_id, "srv_media");
    }

    #[tokio::test]
    async fn test_send_failure_propagates() {
        let queue = MessageSendQueue::new();
        let result = queue.submit(101, || {
            Box::pin(async {
                Err(SdkError::message_send("network timeout"))
            })
        }).await;
        assert!(result.is_err());
    }

    #[tokio::test]
    async fn test_fifo_order_within_lane() {
        use std::sync::atomic::{AtomicUsize, Ordering};
        let counter = Arc::new(AtomicUsize::new(0));
        let queue = MessageSendQueue::new();

        // 提交 3 条文本消息，验证顺序执行
        let mut results = Vec::new();
        for i in 0..3 {
            let c = counter.clone();
            let result = queue.submit(101, move || {
                let order = c.fetch_add(1, Ordering::SeqCst);
                Box::pin(async move {
                    Ok(UserSendMsgResp {
                        server_msg_id: format!("srv_{}_{}", order, i),
                        client_msg_id: format!("cli_{}", i),
                        send_time: i as i64 * 1000,
                    })
                })
            }).await;
            results.push(result.unwrap());
        }

        // 同一 lane 内应按提交顺序执行
        assert_eq!(results[0].server_msg_id, "srv_0_0");
        assert_eq!(results[1].server_msg_id, "srv_1_1");
        assert_eq!(results[2].server_msg_id, "srv_2_2");
    }

    // ========================================================================
    // 双 Lane 并发不互阻测试
    // ========================================================================

    #[tokio::test]
    async fn test_lanes_do_not_block_each_other() {
        use std::time::Duration;
        let queue = MessageSendQueue::new();
        let start = tokio::time::Instant::now();

        // 先提交媒体消息（Lane B），sleep 200ms 模拟上传
        let q2 = queue.clone();
        let media_handle = tokio::spawn(async move {
            q2.submit(102, || Box::pin(async {
                tokio::time::sleep(Duration::from_millis(200)).await;
                Ok(UserSendMsgResp {
                    server_msg_id: "media".to_string(),
                    client_msg_id: "cli_media".to_string(),
                    send_time: 0,
                })
            })).await
        });

        // 等 10ms 确保媒体任务已进入 lane_worker
        tokio::time::sleep(Duration::from_millis(10)).await;

        // 再提交文本消息（Lane A），应立即返回
        let text_result = queue.submit(101, || Box::pin(async {
            Ok(UserSendMsgResp {
                server_msg_id: "text".to_string(),
                client_msg_id: "cli_text".to_string(),
                send_time: 0,
            })
        })).await;

        let text_elapsed = start.elapsed();
        assert!(text_result.is_ok());
        assert_eq!(text_result.unwrap().server_msg_id, "text");

        // 关键断言：文本完成时间 < 100ms（远小于媒体的 200ms）
        assert!(
            text_elapsed < Duration::from_millis(100),
            "text lane was blocked by media lane: {:?}", text_elapsed
        );

        // 等待媒体完成
        let media_result = media_handle.await.unwrap();
        assert!(media_result.is_ok());
        assert_eq!(media_result.unwrap().server_msg_id, "media");
    }
}
