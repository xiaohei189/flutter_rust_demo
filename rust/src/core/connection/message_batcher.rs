use std::collections::HashMap;
use std::sync::Arc;
use std::time::{Duration, Instant};
use tokio::sync::{Mutex, mpsc};
use crate::protocol::sdkws::{PullMsgs, PushMessages};

// 对齐 Go SDK message_batcher.go 常量
const MAX_BATCH_MESSAGES: usize = 400;
const MIN_AGGREGATION_DELAY: Duration = Duration::from_millis(50);
const MAX_AGGREGATION_DELAY: Duration = Duration::from_secs(1);
const LOW_LOAD_WINDOW: Duration = Duration::from_secs(10);
const LOW_LOAD_MESSAGE_LIMIT: usize = 20;
const HIGH_LOAD_MESSAGE_LIMIT: usize = 200;

/// 聚合多批 operationID 为单个标识，对齐 Go doBatch 的 Batch_op1$op2$op3 格式
pub fn join_operation_ids(operation_ids: &[String]) -> String {
    if operation_ids.is_empty() {
        return "unknown".to_string();
    }
    if operation_ids.len() == 1 {
        return operation_ids[0].clone();
    }
    format!("Batch_{}", operation_ids.join("$"))
}

#[derive(Clone, Debug)]
struct ArrivalRecord {
    ts: Instant,
    count: usize,
}

/// 推送消息批处理器，对齐 Go SDK MessageBatcher
///
/// 在高负载场景下聚合多批 PushMessages，减少频繁的 UI 刷新和数据库操作。
/// 低负载时直接透传，高负载时自适应延迟聚合（50ms ~ 1s）。
#[derive(Clone)]
pub struct MessageBatcher {
    inner: Arc<Mutex<MessageBatcherInner>>,
    flush_tx: mpsc::Sender<()>,
}

struct MessageBatcherInner {
    buffer: Option<PushMessages>,
    operation_ids: Vec<String>,
    handler: Option<Box<dyn Fn(Vec<String>, PushMessages) + Send + Sync>>,
    arrivals: Vec<ArrivalRecord>,
    recent_total: usize,
    first_buffered: Option<Instant>,
    /// 定时器到期的 flush 通知，timer 任务通过此 sender 发送
    timer_tx: Option<mpsc::Sender<()>>,
}

impl MessageBatcher {
    pub fn new(handler: impl Fn(Vec<String>, PushMessages) + Send + Sync + 'static) -> Self {
        let (flush_tx, flush_rx) = mpsc::channel::<()>(1);
        let inner = Arc::new(Mutex::new(MessageBatcherInner {
            buffer: None,
            operation_ids: Vec::new(),
            handler: Some(Box::new(handler)),
            arrivals: Vec::new(),
            recent_total: 0,
            first_buffered: None,
            timer_tx: None,
        }));

        let batcher = Self {
            inner: inner.clone(),
            flush_tx: flush_tx.clone(),
        };
        let inner_clone = inner.clone();
        tokio::spawn(Self::flush_loop(inner_clone, flush_rx));

        batcher
    }

    /// flush 循环：接收 timer 到期信号
    async fn flush_loop(
        inner: Arc<Mutex<MessageBatcherInner>>,
        mut flush_rx: mpsc::Receiver<()>,
    ) {
        while flush_rx.recv().await.is_some() {
            let mut guard = inner.lock().await;
            if guard.timer_tx.take().is_some() {
                let pending = guard.consume();
                // handler 仅 spawn 异步任务，不会阻塞，可在锁内执行
                if let Some((pending, pending_ops)) = pending {
                    if let Some(h) = guard.handler.as_ref() {
                        h(pending_ops, pending);
                    }
                }
            }
        }
    }

    /// 入队一批推送消息，自适应聚合后分发
    #[tracing::instrument(level = "debug", skip(self, batch), fields(operationID = %operation_id))]
    pub async fn enqueue(&self, operation_id: String, batch: PushMessages) {
        let mut inner = self.inner.lock().await;
        let now = Instant::now();
        let added_count = count_messages(&batch);
        let recent = inner.record_arrival(now, added_count);

        // 低负载：直接消费缓冲 + 直接分发当前批次（零延迟）
        if recent < LOW_LOAD_MESSAGE_LIMIT {
            let pending = inner.consume();
            inner.cancel_pending_timer();

            if let Some((pending, pending_ops)) = pending {
                if let Some(h) = inner.handler.as_ref() {
                    h(pending_ops, pending);
                }
            }
            if !is_empty(&batch) {
                if let Some(h) = inner.handler.as_ref() {
                    h(vec![operation_id], batch);
                }
            }
            return;
        }

        // 高负载：合并到缓冲区
        inner.operation_ids.push(operation_id);
        inner.merge(&batch);
        if inner.buffer.is_some() && inner.first_buffered.is_none() {
            inner.first_buffered = Some(now);
        }

        let pending_count = inner.pending_count();

        // 缓冲区满且负载不极端 → 立即 flush
        if pending_count >= MAX_BATCH_MESSAGES && recent < HIGH_LOAD_MESSAGE_LIMIT {
            let pending = inner.consume();
            inner.cancel_pending_timer();
            if let Some((pending, pending_ops)) = pending {
                if let Some(h) = inner.handler.as_ref() {
                    h(pending_ops, pending);
                }
            }
            return;
        }

        // 计算自适应延迟
        let first_buffered = inner.first_buffered.unwrap_or(now);
        let elapsed = now.duration_since(first_buffered);
        let total_delay = compute_delay(recent);
        let target_flush = first_buffered + total_delay;

        // 已超过最大延迟或计算延迟 → 立即 flush
        if elapsed >= MAX_AGGREGATION_DELAY || elapsed >= total_delay {
            let pending = inner.consume();
            inner.cancel_pending_timer();
            if let Some((pending, pending_ops)) = pending {
                if let Some(h) = inner.handler.as_ref() {
                    h(pending_ops, pending);
                }
            }
            return;
        }

        // 设置定时器在 target_flush 时刻触发 flush
        let delay = target_flush.saturating_duration_since(Instant::now());
        let delay = delay.max(Duration::from_millis(1));
        inner.schedule_timer(delay, self.flush_tx.clone());
    }

    /// 关闭批处理器：flush 剩余缓冲消息并释放回调
    pub async fn close(&self) {
        let mut inner = self.inner.lock().await;
        let pending = inner.consume();
        inner.cancel_pending_timer();
        let handler = inner.handler.take();

        if let Some((pending, pending_ops)) = pending {
            if let Some(h) = handler.as_ref() {
                h(pending_ops, pending);
            }
        }
    }
}

impl MessageBatcherInner {
    /// 记录消息到达，返回近 10 秒内的消息总数
    fn record_arrival(&mut self, now: Instant, count: usize) -> usize {
        if count == 0 {
            return self.recent_total;
        }
        let cutoff = now - LOW_LOAD_WINDOW;
        let mut idx = 0;
        while idx < self.arrivals.len() && self.arrivals[idx].ts < cutoff {
            self.recent_total -= self.arrivals[idx].count;
            idx += 1;
        }
        if idx > 0 {
            self.arrivals.drain(..idx);
        }
        self.arrivals.push(ArrivalRecord { ts: now, count });
        self.recent_total += count;
        self.recent_total
    }

    /// 合并消息到缓冲区（按 conversationID 归并）
    fn merge(&mut self, batch: &PushMessages) {
        let buffer = self.buffer.get_or_insert_with(|| PushMessages {
            msgs: HashMap::new(),
            notification_msgs: HashMap::new(),
        });
        merge_pulls(&mut buffer.msgs, &batch.msgs);
        merge_pulls(&mut buffer.notification_msgs, &batch.notification_msgs);
    }

    /// 消费缓冲区，返回 (PushMessages, operation_ids)
    fn consume(&mut self) -> Option<(PushMessages, Vec<String>)> {
        let buffer = self.buffer.take()?;
        let ops = std::mem::take(&mut self.operation_ids);
        self.first_buffered = None;
        Some((buffer, ops))
    }

    /// 缓冲区中的消息总数
    fn pending_count(&self) -> usize {
        match &self.buffer {
            None => 0,
            Some(buf) => {
                let mut total = 0;
                for pulls in buf.msgs.values() {
                    total += pulls.msgs.len();
                }
                for pulls in buf.notification_msgs.values() {
                    total += pulls.msgs.len();
                }
                total
            }
        }
    }

    /// 调度一个延迟 flush 定时器
    fn schedule_timer(&mut self, delay: Duration, flush_tx: mpsc::Sender<()>) {
        self.cancel_pending_timer();

        let (timer_tx, mut timer_rx) = mpsc::channel::<()>(1);
        self.timer_tx = Some(timer_tx);

        tokio::spawn(async move {
            tokio::time::sleep(delay).await;
            let _ = flush_tx.send(()).await;
            let _ = timer_rx.recv().await;
        });
    }

    fn cancel_pending_timer(&mut self) {
        self.timer_tx.take();
    }
}

/// 按 conversationID 合并 PullMsgs
fn merge_pulls(
    destination: &mut HashMap<String, PullMsgs>,
    source: &HashMap<String, PullMsgs>,
) {
    for (conv_id, pulls) in source {
        if let Some(existing) = destination.get_mut(conv_id) {
            existing.msgs.extend(pulls.msgs.iter().cloned());
            existing.is_end = pulls.is_end;
            existing.end_seq = pulls.end_seq;
        } else {
            destination.insert(conv_id.clone(), pulls.clone());
        }
    }
}

/// 计算自适应延迟（对齐 Go SDK computeDelayLocked）
fn compute_delay(recent: usize) -> Duration {
    if recent >= HIGH_LOAD_MESSAGE_LIMIT {
        return MAX_AGGREGATION_DELAY;
    }
    if recent <= LOW_LOAD_MESSAGE_LIMIT {
        return MIN_AGGREGATION_DELAY;
    }
    let span = HIGH_LOAD_MESSAGE_LIMIT - LOW_LOAD_MESSAGE_LIMIT;
    let scale = (recent - LOW_LOAD_MESSAGE_LIMIT) as f64 / span as f64;
    let delay_ms = 50.0 + scale * (1000.0 - 50.0);
    Duration::from_millis(delay_ms as u64).clamp(MIN_AGGREGATION_DELAY, MAX_AGGREGATION_DELAY)
}

fn count_messages(batch: &PushMessages) -> usize {
    let mut total = 0;
    for pulls in batch.msgs.values() {
        total += pulls.msgs.len();
    }
    for pulls in batch.notification_msgs.values() {
        total += pulls.msgs.len();
    }
    total
}

fn is_empty(batch: &PushMessages) -> bool {
    batch.msgs.is_empty() && batch.notification_msgs.is_empty()
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::protocol::sdkws::MsgData;

    #[test]
    fn test_compute_delay_low_load() {
        assert_eq!(compute_delay(10), MIN_AGGREGATION_DELAY);
    }

    #[test]
    fn test_compute_delay_high_load() {
        assert_eq!(compute_delay(300), MAX_AGGREGATION_DELAY);
    }

    #[test]
    fn test_compute_delay_mid_load() {
        let delay = compute_delay(110);
        assert!(delay > MIN_AGGREGATION_DELAY);
        assert!(delay < MAX_AGGREGATION_DELAY);
    }

    #[test]
    fn test_merge_pulls() {
        let mut dest = HashMap::new();
        dest.insert(
            "conv1".into(),
            PullMsgs {
                msgs: vec![],
                is_end: false,
                end_seq: 1,
            },
        );

        let mut source = HashMap::new();
        source.insert(
            "conv1".into(),
            PullMsgs {
                msgs: vec![],
                is_end: true,
                end_seq: 5,
            },
        );
        source.insert(
            "conv2".into(),
            PullMsgs {
                msgs: vec![],
                is_end: false,
                end_seq: 3,
            },
        );

        merge_pulls(&mut dest, &source);
        assert_eq!(dest.len(), 2);
        assert!(dest["conv1"].is_end);
        assert_eq!(dest["conv1"].end_seq, 5);
        assert_eq!(dest["conv2"].end_seq, 3);
    }

    #[tokio::test]
    async fn test_batcher_low_load_passthrough() {
        let received = Arc::new(Mutex::new(Vec::<(Vec<String>, PushMessages)>::new()));
        let received_clone = received.clone();

        let batcher = MessageBatcher::new(move |ops, msgs| {
            let r = received_clone.clone();
            tokio::spawn(async move {
                r.lock().await.push((ops, msgs));
            });
        });

        // 非空批次：包含一条消息
        let mut msgs = HashMap::new();
        msgs.insert("conv1".into(), PullMsgs { msgs: vec![MsgData::default()], is_end: false, end_seq: 1 });
        let batch = PushMessages {
            msgs,
            notification_msgs: HashMap::new(),
        };
        batcher.enqueue("op1".into(), batch).await;

        tokio::time::sleep(Duration::from_millis(50)).await;
        let results = received.lock().await;
        assert_eq!(results.len(), 1);
        assert_eq!(results[0].0, vec!["op1"]);
    }

    #[tokio::test]
    async fn test_batcher_close_flushes() {
        let received = Arc::new(Mutex::new(Vec::<(Vec<String>, PushMessages)>::new()));
        let received_clone = received.clone();

        let batcher = MessageBatcher::new(move |ops, msgs| {
            let r = received_clone.clone();
            tokio::spawn(async move {
                r.lock().await.push((ops, msgs));
            });
        });

        // 非空批次
        let mut msgs = HashMap::new();
        msgs.insert("conv1".into(), PullMsgs { msgs: vec![MsgData::default()], is_end: false, end_seq: 1 });
        let batch = PushMessages {
            msgs,
            notification_msgs: HashMap::new(),
        };
        batcher.enqueue("op1".into(), batch).await;
        tokio::time::sleep(Duration::from_millis(50)).await;

        batcher.close().await;
        tokio::time::sleep(Duration::from_millis(50)).await;

        let results = received.lock().await;
        assert_eq!(results.len(), 1);
    }
}
