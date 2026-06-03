# 04 - 消息发送器模块详细设计

> 本文档为 Rust SDK 重写参考规范，详细描述消息发送器（MessageSender）的设计与实现。
> Go SDK 对标文件：`internal/conversation_msg/send_queue.go`（239 行）+ `internal/interaction/message_batcher.go`（294 行）

---

## 1. 模块职责

消息发送器负责高效、有序地将消息从客户端发送到服务端：

- **发送队列管理**：使用 Worker Pool 并发执行发送任务
- **双 Lane 保序**：文本消息和媒体消息分别在独立的有序通道中发送
- **动态阈值估计**：根据网络状况动态判断媒体消息是否需要保序
- **发送结果通知**：成功/失败后通过回调通知上层
- **推送聚合器**：将高频推送消息聚批次处理，减少 UI 刷新开销

---

## 2. Go SDK 对标分析

### 2.1 核心文件

| 文件 | 行数 | 职责 |
|------|------|------|
| `send_queue.go` | 239 | 消息发送队列（Worker Pool、双 Lane、阈值估计器） |
| `message_batcher.go` | 294 | 推送消息聚合器（MessageBatcher，按负载动态延迟） |

### 2.2 常量定义

```go
// Go SDK send_queue.go L19-L27
const (
    sendTaskQueueSize        = 256              // 发送任务队列大小
    sendChainMaxWait         = 3 * time.Second  // 有序消息最大等待时间
    defaultMediaOrderedBytes = 16 * 1024        // 默认媒体保序阈值 = 16KB
    minMediaOrderedBytes     = 4 * 1024         // 最小阈值 = 4KB
    maxMediaOrderedBytes     = 8 * 1024 * 1024  // 最大阈值 = 8MB
    maxSendEnqueueRetry      = 100              // 最大入队重试次数
    sendEnqueueRetryInterval = 5 * time.Millisecond  // 重试间隔
)
```

### 2.3 核心数据结构

```go
// Go SDK send_queue.go L29-L39
type sendTask struct {
    ctx       context.Context              // 执行上下文（含回调信息）
    msg       *sdk_struct.MsgStruct        // 待发送的消息
    exec      func(context.Context) (*sdk_struct.MsgStruct, error)  // 执行函数
    enqueueAt time.Time                    // 入队时间（用于延迟计算）
    ordered   bool                         // 是否需要保序
    lane      ccontext.SendOrderLane       // 所属车道（Text/Media）
    seq       int64                        // 车道内序号
    mediaSize int64                        // 媒体文件大小（字节）
    deadline  time.Time                    // 保序超时时间
}
```

```go
// Go SDK send_queue.go L41-L50
type messageSender struct {
    conversation *Conversation
    queue        chan *sendTask        // 任务队列（有界 channel）
    wg           sync.WaitGroup       // Worker 等待组
    textSeq      atomic.Int64         // 文本车道序号生成器
    mediaSeq     atomic.Int64         // 媒体车道序号生成器
    estimator    *thresholdEstimator  // 动态阈值估计器
}
```

---

## 3. 双车道机制

### 3.1 设计原理

消息发送需要保序（用户 A 发送消息 1、2、3，服务端接收顺序也应为 1、2、3），但不同类型的消息对带宽占用差异很大。双车道机制将文本和媒体分开处理：

```
┌─────────────────────────────────────────────────────┐
│                    Submit 入口                       │
│                       │                              │
│            ┌──────────┴──────────┐                   │
│            │  isMediaContent?    │                   │
│            ├─── Yes ─────────────┼─── No ────────┐   │
│            ▼                    │               ▼   │
│    shouldKeepMediaOrdered?      │         Text Lane │
│    ├─── Yes ──────┐             │         (Lane=1)  │
│    ▼              ▼             │           │       │
│  Media Lane  无序发送           │           ▼       │
│  (Lane=2)   (跳过保序)         │     保序发送       │
│    │                          │                   │
│    ▼                          │                   │
│  保序发送                      │                   │
└─────────────────────────────────────────────────────┘
```

### 3.2 车道分配逻辑

```go
// Go SDK send_queue.go L83-L111
func (m *messageSender) decorate(task *sendTask) {
    task.ordered = true
    if isMediaContentType(task.msg.ContentType) {
        task.lane = ccontext.SendOrderLaneMedia       // Lane 2
        task.mediaSize = estimateMediaSize(task.msg)
        task.ordered = m.shouldKeepMediaOrdered(task.mediaSize)
    } else {
        task.lane = ccontext.SendOrderLaneText        // Lane 1
    }

    if task.ordered {
        if task.lane == ccontext.SendOrderLaneText {
            task.seq = m.textSeq.Add(1)               // 原子递增文本序号
        } else {
            task.seq = m.mediaSeq.Add(1)              // 原子递增媒体序号
        }
        task.deadline = task.enqueueAt.Add(sendChainMaxWait)  // 入队时间 + 3s
        // 注册到 LongConnMgr 用于写泵超时检测
        m.conversation.LongConnMgr.RegisterSendOrder(task.lane, task.seq, task.deadline)
    } else {
        task.seq = 0
        task.deadline = time.Time{}
    }
}
```

### 3.3 媒体内容类型判断

```go
// Go SDK send_queue.go L207-L214
func isMediaContentType(contentType int32) bool {
    switch contentType {
    case constant.Picture,   // 102
         constant.Sound,     // 103
         constant.Video,     // 104
         constant.File:      // 105
        return true
    default:
        return false
    }
}
```

**媒体大小估算**（send_queue.go L216-L239）：

| ContentType | 取值字段 |
|-------------|----------|
| Picture (102) | `PictureElem.SourcePicture.Size` |
| Sound (103) | `SoundElem.DataSize` |
| Video (104) | `VideoElem.VideoSize`（优先）→ `VideoElem.SnapshotSize` |
| File (105) | `FileElem.FileSize` |

---

## 4. 阈值估计算法

### 4.1 设计目的

动态决定多大的媒体消息需要保序发送。小文件保序可以保证体验，大文件保序会阻塞后续所有消息。

### 4.2 核心算法

```go
// Go SDK send_queue.go L164-L205
type thresholdEstimator struct {
    value float64  // 当前阈值（字节）
}

func newThresholdEstimator() *thresholdEstimator {
    return &thresholdEstimator{value: defaultMediaOrderedBytes}  // 初始 16KB
}

// 更新阈值（每次成功发送媒体消息后调用）
func (t *thresholdEstimator) Update(size int64, elapsed time.Duration) {
    if size <= 0 || elapsed <= 0 {
        return
    }
    bytesPerSec := float64(size) / elapsed.Seconds()
    if bytesPerSec <= 0 {
        return
    }
    
    // 目标值 = 当前发送速率 × 3秒（即 3 秒能传完的数据量）
    target := bytesPerSec * sendChainMaxWait.Seconds()  // × 3.0
    
    // 钳制到 [4KB, 8MB]
    target = clamp(target, minMediaOrderedBytes, maxMediaOrderedBytes)
    
    // EMA 平滑：0.6 × 目标 + 0.4 × 旧值
    if t.value <= 0 {
        t.value = target
    } else {
        t.value = 0.6*target + 0.4*t.value
    }
}

func (t *thresholdEstimator) Current() float64 {
    if t.value <= 0 {
        return defaultMediaOrderedBytes
    }
    return clamp(t.value, minMediaOrderedBytes, maxMediaOrderedBytes)
}
```

### 4.3 算法图解

```
发送 1MB 图片，耗时 0.5s：
  bytesPerSec = 1MB / 0.5s = 2MB/s
  target = 2MB/s × 3.0s = 6MB
  target = clamp(6MB, 4KB, 8MB) = 6MB
  newValue = 0.6 × 6MB + 0.4 × 16KB ≈ 3.66MB

下次判断：若新图片 3MB < 3.66MB → 保序
         若新图片 5MB > 3.66MB → 无序（跳过）
```

### 4.4 关键参数

| 参数 | 值 | 说明 |
|------|------|------|
| `defaultMediaOrderedBytes` | 16 KB | 初始阈值（保守） |
| `minMediaOrderedBytes` | 4 KB | 最小阈值下限 |
| `maxMediaOrderedBytes` | 8 MB | 最大阈值上限 |
| `sendChainMaxWait` | 3 s | EMA 窗口时间 |
| EMA 权重 | 0.6/0.4 | 目标/历史 |

---

## 5. Worker Pool

### 5.1 初始化

```go
// Go SDK send_queue.go L52-L67
func newMessageSender(conversation *Conversation) *messageSender {
    workers := runtime.NumCPU()
    if workers < 4 {
        workers = 4           // 至少 4 个 Worker
    }
    ms := &messageSender{
        conversation: conversation,
        queue:        make(chan *sendTask, sendTaskQueueSize),  // 有界 channel, cap=256
        estimator:    newThresholdEstimator(),
    }
    for i := 0; i < workers; i++ {
        ms.wg.Add(1)
        go ms.worker()        // 每个 Worker 是一个 goroutine
    }
    return ms
}
```

### 5.2 Worker 循环

```go
// Go SDK send_queue.go L120-L125
func (m *messageSender) worker() {
    defer m.wg.Done()
    for task := range m.queue {  // 从 channel 无限循环读取
        m.runTask(task)
    }
}
```

### 5.3 Rust Worker Pool 参考实现

```rust
use tokio::sync::mpsc;
use std::sync::Arc;

pub struct MessageSender {
    tx: mpsc::Sender<SendTask>,
    text_seq: AtomicI64,
    media_seq: AtomicI64,
    estimator: ThresholdEstimator,
}

impl MessageSender {
    pub fn new(worker_count: usize) -> Self {
        let (tx, rx) = mpsc::channel(256);
        let rx = Arc::new(tokio::sync::Mutex::new(rx));
        
        let workers = worker_count.max(4);
        for _ in 0..workers {
            let rx = rx.clone();
            tokio::spawn(async move {
                loop {
                    let task = {
                        let mut guard = rx.lock().await;
                        guard.recv().await
                    };
                    match task {
                        Some(task) => Self::run_task(task).await,
                        None => break,  // channel 关闭
                    }
                }
            });
        }
        
        Self {
            tx,
            text_seq: AtomicI64::new(0),
            media_seq: AtomicI64::new(0),
            estimator: ThresholdEstimator::new(),
        }
    }
}
```

---

## 6. Submit → Worker → Execute 流程

### 6.1 完整流程

```
用户调用 send_msg()
    │
    ▼
Step 1: Submit（send_queue.go L69-L81）
    │  ├── task.enqueueAt = time.Now()
    │  ├── decorate(task)          // 分配车道、计算序号、设置 deadline
    │  └── 入队（最多重试 100 × 5ms = 500ms）
    │      ├── 成功 → 返回 nil
    │      └── 失败 → 返回 "send task queue full" 错误
    │
    ▼
Step 2: Worker（send_queue.go L120-L125）
    │  └── 从 channel 读取 task → runTask(task)
    │
    ▼
Step 3: RunTask（send_queue.go L127-L137）
    │  ├── 执行 task.exec(ctx)     // 实际发送（HTTP/gRPC/WebSocket）
    │  ├── 成功 → 更新 estimator + notifySendSuccess
    │  └── 失败 → notifySendError
```

### 6.2 Submit 入队重试

```go
// Go SDK send_queue.go L69-L81
func (m *messageSender) submit(task *sendTask) error {
    task.enqueueAt = time.Now()
    m.decorate(task)
    
    for i := 0; i < maxSendEnqueueRetry; i++ {    // 最多 100 次
        select {
        case m.queue <- task:
            return nil                             // 入队成功
        default:
            time.Sleep(sendEnqueueRetryInterval)   // 等待 5ms
        }
    }
    return errs.New("send task queue full")
}
```

### 6.3 RunTask 执行与结果通知

```go
// Go SDK send_queue.go L127-L137
func (m *messageSender) runTask(task *sendTask) {
    msg, err := task.exec(task.ctx)
    
    // 媒体消息成功后更新阈值估计器
    if task.lane == ccontext.SendOrderLaneMedia && 
       task.mediaSize > 0 && err == nil && task.ordered {
        m.estimator.Update(task.mediaSize, time.Since(task.enqueueAt))
    }
    
    if err != nil {
        notifySendError(task.ctx, err)
        return
    }
    notifySendSuccess(task.ctx, msg)
}
```

### 6.4 结果回调

```go
// Go SDK send_queue.go L139-L162
func notifySendSuccess(ctx context.Context, msg *sdk_struct.MsgStruct) {
    callback, _ := ctx.Value(ccontext.CtxCallback).(SendMsgCallBack)
    if callback == nil { return }
    data, _ := json.Marshal(msg)
    callback.OnSuccess(string(data))
}

func notifySendError(ctx context.Context, err error) {
    callback, _ := ctx.Value(ccontext.CtxCallback).(SendMsgCallBack)
    if callback == nil { return }
    if code, ok := err.(errs.CodeError); ok {
        callback.OnError(int32(code.Code()), code.Msg())
        return
    }
    callback.OnError(sdkerrs.UnknownCode, err.Error())
}
```

---

## 7. 有序消息超时处理

### 7.1 写泵（Write Pump）超时机制

在 WebSocket 写泵中，有序消息的 seq 是连续递增的。如果某个 seq 对应的消息发送失败或长时间未到达，后续消息会被阻塞。

**超时处理逻辑：**

```
writePump 检测到 gap:
  当前 expected = seq 5
  队列中最小 seq = seq 8  (gap = 6, 7 缺失)
  │
  ├── 等待 3 秒（sendChainMaxWait）
  │
  ├── 超时 → 跳过缺失的 seq
  │   expected = 8（跳过 6、7）
  │   继续发送 seq 8 的消息
  │
  └── 3 秒内缺失消息到达 → 正常处理
```

### 7.2 Rust 实现参考

```rust
use tokio::time::{timeout, Duration};

async fn write_pump(
    mut receiver: mpsc::Receiver<SendTask>,
    deadline_map: HashMap<(SendOrderLane, i64), Instant>,
) {
    let mut buffer: HashMap<SendOrderLane, VecDeque<SendTask>> = HashMap::new();
    let mut expected: HashMap<SendOrderLane, i64> = HashMap::new();
    
    loop {
        // 选择最近的超时时间
        let nearest_deadline = compute_nearest_deadline(&deadline_map);
        
        match timeout(nearest_deadline, receiver.recv()).await {
            Ok(Some(task)) => {
                // 收到新任务，放入 buffer
                buffer.entry(task.lane).or_default().push_back(task);
            }
            Ok(None) => break,  // channel 关闭
            Err(_) => {
                // 超时：跳过缺失 seq，推进 expected
                for (lane, expected_seq) in &mut expected {
                    if let Some(front) = buffer.get(lane).and_then(|q| q.front()) {
                        if front.seq > *expected_seq {
                            *expected_seq = front.seq;  // 跳过 gap
                        }
                    }
                }
            }
        }
        
        // 尝试发送 expected 位置的消息
        try_send_expected(&mut buffer, &mut expected);
    }
}
```

---

## 8. MessageBatcher（推送聚合器）

### 8.1 设计目的

当高频推送大量消息时（如重连后同步、批量消息推送），逐条处理会导致 UI 频繁刷新。MessageBatcher 将消息聚批后统一处理。

### 8.2 常量定义

```go
// Go SDK message_batcher.go L11-L18
const (
    maxBatchMessages     = 400          // 单批最大消息数
    minAggregationDelay  = 50ms         // 最小聚合延迟
    maxAggregationDelay  = 1s           // 最大聚合延迟
    lowLoadWindow        = 10s          // 低负载检测窗口
    lowLoadMessageLimit  = 20           // 低负载消息数阈值
    highLoadMessageLimit = 200          // 高负载消息数阈值
)
```

### 8.3 核心数据结构

```go
// Go SDK message_batcher.go L25-L35
type MessageBatcher struct {
    mutex         sync.Mutex
    buffer        *sdkws.PushMessages       // 聚合缓冲区
    contexts      []context.Context         // 对应的上下文列表
    handler       func([]context.Context, *sdkws.PushMessages)  // 处理回调
    flushTimer    *time.Timer               // 定时刷出计时器
    nextFlushAt   time.Time                 // 下次计划刷出时间
    arrivals      []arrivalRecord           // 到达记录（用于负载检测）
    recentTotal   int                       // 近期消息总数
    firstBuffered time.Time                 // 缓冲开始时间
}
```

### 8.4 负载感知算法

```
消息到达
    │
    ▼
计算 10s 窗口内的消息总数 (recent)
    │
    ├── recent < 20（低负载）
    │   └── 立即刷出：先刷出缓冲区，再直接分发当前批次
    │
    ├── recent >= 200（高负载）
    │   └── 最大延迟：聚合到 maxAggregationDelay (1s) 或 maxBatchMessages (400)
    │
    └── 20 <= recent < 200（中等负载）
        └── 线性插值：计算目标延迟
            delay = minAggregationDelay + (recent - 20) / (200 - 20) × (maxAggregationDelay - minAggregationDelay)
            delay = clamp(delay, 50ms, 1s)
```

### 8.5 Enqueue 流程

```go
// Go SDK message_batcher.go L185-L238（简化）
func (b *MessageBatcher) Enqueue(ctx context.Context, batch *sdkws.PushMessages) {
    b.mutex.Lock()
    now := time.Now()
    addedCount := countMessages(batch)
    recent := b.recordArrivalLocked(now, addedCount)
    
    if recent < lowLoadMessageLimit {
        // 低负载：立即刷出
        toFlush, toCtxs := b.consumeLocked()
        b.cancelTimerLocked()
        b.mutex.Unlock()
        b.dispatch(toCtxs, toFlush)       // 刷出旧缓冲
        b.dispatch([]context.Context{ctx}, batch)  // 处理当前批次
        return
    }
    
    // 中/高负载：聚合
    b.mergeLocked(batch)
    pendingCount := b.pendingCountLocked()
    
    if pendingCount >= maxBatchMessages && recent < highLoadMessageLimit {
        // 缓冲已满 → 刷出
        toFlush, toCtxs := b.consumeLocked()
        b.cancelTimerLocked()
    } else {
        // 计算目标延迟，设置计时器
        elapsed := now.Sub(b.firstBuffered)
        totalDelay := b.computeDelayLocked(recent)
        if elapsed >= maxAggregationDelay || elapsed >= totalDelay {
            toFlush, toCtxs = b.consumeLocked()
        } else {
            b.ensureTimerLocked(b.firstBuffered.Add(totalDelay))
        }
    }
    b.mutex.Unlock()
    b.dispatch(toCtxs, toFlush)
}
```

### 8.6 消息合并

```go
// Go SDK message_batcher.go L77-L120
func (b *MessageBatcher) mergeLocked(batch *sdkws.PushMessages) int {
    total := 0
    total += b.mergePullsLocked(batch.Msgs, true)         // 合并普通消息
    total += b.mergePullsLocked(batch.NotificationMsgs, false)  // 合并通知消息
    return total
}

func (b *MessageBatcher) mergePullsLocked(source map[string]*sdkws.PullMsgs, isMessage bool) int {
    // 按 conversationID 合并：已有则追加消息列表，无则新建
    for conversationID, pulls := range source {
        if existing, ok := destination[conversationID]; ok {
            existing.Msgs = append(existing.Msgs, pulls.Msgs...)
            existing.IsEnd = pulls.IsEnd
            existing.EndSeq = pulls.EndSeq
        } else {
            destination[conversationID] = pulls
        }
    }
}
```

---

## 9. Rust 实现状态

### 9.1 已实现

| 功能 | 文件 | 状态 | 说明 |
|------|------|------|------|
| 基本发送 | `sdk/client/message.rs` | ✅ 已实现 | `send_msg` + `do_send_message` |
| 消息插入（乐观更新） | `sdk/client/message.rs` | ✅ 已实现 | 发送前插入 DB |
| 媒体上传 | `sdk/client/message.rs` | ✅ 已实现 | `process_media_content` |
| 超时重试 | `sdk/client/message.rs` | ✅ 已实现 | 超时后二次确认 DB 状态 |
| 发送失败处理 | `sdk/client/message.rs` | ✅ 已实现 | 更新状态 + 发布事件 |
| 发送成功处理 | `sdk/client/message.rs` | ✅ 已实现 | 更新 DB + 清理 sending_messages |
| 去重检查 | `sdk/client/message.rs` | ✅ 已实现 | 发送前检查 clientMsgID |
| 类型消息 API | `sdk/client/message.rs` | ✅ 已实现 | send_text/send_image/send_file 等 |
| 登录清理 | `sdk/client/message.rs` | ✅ 已实现 | cleanup_sending_messages |

### 9.2 未实现 / 待完善

| 功能 | 对标 Go SDK | 优先级 | 说明 |
|------|-------------|--------|------|
| Worker Pool 并发发送 | `send_queue.go` L52-L67 | 🔴 高 | 当前为同步发送，缺少并发 Worker Pool |
| 双 Lane 保序 | `send_queue.go` L83-L111 | 🔴 高 | 缺少 Text Lane / Media Lane 有序发送 |
| 动态阈值估计器 | `send_queue.go` L164-L205 | 🔴 高 | 缺少媒体消息保序阈值动态调整 |
| SendTask 抽象 | `send_queue.go` L29-L39 | 🟡 中 | 缺少统一的发送任务结构体 |
| SendOrder 注册 | `send_queue.go` L106 | 🟡 中 | 缺少 LongConnMgr 注册发送顺序 |
| 写泵超时处理 | 写泵逻辑 | 🟡 中 | 缺少有序消息 gap 超时跳过机制 |
| MessageBatcher | `message_batcher.go` | 🟡 中 | 缺少推送消息聚合器 |
| 重试队列（失败重发） | 未在 Go SDK 实现 | 🟢 低 | 可考虑自动重试失败消息 |

---

## 10. 测试用例

### 10.1 测试矩阵

| 测试用例 | 描述 | 已实现 | 文件 |
|----------|------|--------|------|
| `test_basic_send_text` | 基本文本消息发送 | ✅ | message.rs |
| `test_send_duplicate_rejected` | 重复发送被拒绝 | ✅ | message.rs |
| `test_send_media_upload` | 媒体消息上传后发送 | ✅ | message.rs |
| `test_send_timeout_recovery` | 超时后二次确认 | ✅ | message.rs |
| `test_cleanup_sending_on_login` | 登录清理发送中消息 | ✅ | message.rs |
| `test_text_message_ordering` | 文本消息保序 | ❌ | - |
| `test_media_message_threshold` | 媒体消息阈值判断 | ❌ | - |
| `test_send_timeout` | 有序消息超时跳过 | ❌ | - |
| `test_worker_concurrent` | Worker 并发执行 | ❌ | - |
| `test_batcher_aggregation` | 推送聚合器延迟聚合 | ❌ | - |
| `test_estimator_update` | 阈值估计器 EMA 更新 | ❌ | - |
| `test_estimator_clamp` | 阈值钳制在 [4KB, 8MB] | ❌ | - |
| `test_enqueue_retry_full` | 队列满时入队重试 | ❌ | - |

### 10.2 缺失测试详细说明

#### test_text_message_ordering

```rust
// 测试场景：文本消息保序
// 1. 快速提交 10 条文本消息（msg_1 到 msg_10）
// 2. 验证 Worker 按 seq 顺序执行（1 → 2 → 3 → ... → 10）
// 3. 验证回调按相同顺序触发
// 
// 实现要点：
// - 使用 mpsc channel 保证 FIFO
// - Text Lane 的 seq 由 AtomicI64 递增保证
// - 通过收集 (seq, timestamp) 对验证顺序
```

#### test_media_message_threshold

```rust
// 测试场景：媒体消息阈值判断
// 1. 初始化 estimator (default=16KB)
// 2. 发送 1MB 图片，耗时 0.5s → 阈值应更新为 ~3.66MB
// 3. 下次发送 3MB 图片 → shouldKeepMediaOrdered=true（3MB < 3.66MB）
// 4. 下次发送 5MB 图片 → shouldKeepMediaOrdered=false（5MB > 3.66MB）
//
// 实现要点：
// - 阈值初始 16KB
// - EMA: newValue = 0.6 × target + 0.4 × oldValue
// - target = bytesPerSec × 3.0
```

#### test_send_timeout

```rust
// 测试场景：有序消息超时跳过
// 1. 提交 seq=1 的消息（正常发送）
// 2. 不提交 seq=2 的消息（模拟丢失）
// 3. 提交 seq=3 的消息
// 4. 等待 3 秒（sendChainMaxWait）
// 5. 验证 seq=3 在超时后被正常发送
// 6. 验证 expected 从 2 推进到 3
//
// 实现要点：
// - 写泵检测到 gap（expected=2, buffer front=3）
// - 等待 deadline（enqueueAt + 3s）
// - 超时后跳过 seq=2，expected=3
```

#### test_worker_concurrent

```rust
// 测试场景：Worker 并发执行
// 1. 创建 4 个 Worker 的 MessageSender
// 2. 同时提交 20 个发送任务（每个耗时约 100ms）
// 3. 验证总耗时约 500ms（20 / 4 × 100ms）而非 2000ms
// 4. 验证所有任务都执行完毕
//
// 实现要点：
// - tokio mpsc channel 天然 FIFO（单 Worker 保序）
// - 多 Worker 并发处理不同任务
// - 有序消息通过 seq 保证在单 Worker 内顺序
```

#### test_batcher_aggregation

```rust
// 测试场景：推送聚合器按负载动态延迟
// 1. 低负载（10s 内 < 20 条）→ 应立即分发
// 2. 高负载（10s 内 > 200 条）→ 应聚合到 1s 延迟
// 3. 中等负载 → 线性插值延迟
// 4. 缓冲满 400 条 → 应立即刷出
//
// 实现要点：
// - recordArrivalLocked 记录到达时间戳
// - recentTotal 维护 10s 滑动窗口计数
// - computeDelayLocked 线性插值
// - ensureTimerLocked 设置定时器
```

#### test_estimator_update

```rust
// 测试场景：阈值估计器 EMA 更新
// 1. 初始值 = 16KB
// 2. 第一次更新：size=1MB, elapsed=0.5s
//    bytesPerSec = 2MB/s, target = 6MB
//    newValue = 0.6 × 6MB + 0.4 × 16KB ≈ 3.66MB
// 3. 第二次更新：size=500KB, elapsed=1s
//    bytesPerSec = 500KB/s, target = 1.5MB
//    newValue = 0.6 × 1.5MB + 0.4 × 3.66MB ≈ 2.36MB
// 4. 验证每次更新后的 Current() 值
```

#### test_estimator_clamp

```rust
// 测试场景：阈值钳制
// 1. 初始值 = 16KB
// 2. 发送极小文件：size=100B, elapsed=10s → target ≈ 30B → 钳制到 4KB
// 3. 验证 Current() == 4KB (minMediaOrderedBytes)
// 4. 发送极大文件：size=100MB, elapsed=1s → target = 300MB → 钳制到 8MB
// 5. 验证 Current() == 8MB (maxMediaOrderedBytes)
```

---

## 11. Rust 实现文件索引

| 文件 | 职责 |
|------|------|
| `rust/src/sdk/client/message.rs` | SDK 层消息发送 API（send_msg、send_text、send_image 等） |
| `rust/src/domain/model/msg_struct.rs` | MsgStruct 消息结构体定义 |
| `rust/src/core/message/types.rs` | 消息类型工具（is_text、is_media、is_notification） |
| `rust/src/core/message/service.rs` | 消息服务（撤回、删除、标记已读） |
| `rust/src/core/message/handler.rs` | 消息处理器（接收侧，配合发送结果更新） |
| `rust/src/infra/database/message_dao.rs` | 消息 DAO（update_send_status、update_after_send_success） |
| `rust/src/infra/database/sending_message_dao.rs` | 发送中消息追踪 |
| `rust/src/infra/file/uploader.rs` | 文件上传器 |
| `rust/src/domain/event/types.rs` | 事件定义（MessageSent、MessageSendFailed） |

---

## 12. Rust 实现建议

### 12.1 SendTask 结构体

```rust
pub struct SendTask {
    pub ctx: SendContext,
    pub msg: MsgStruct,
    pub ordered: bool,
    pub lane: SendOrderLane,
    pub seq: i64,
    pub media_size: i64,
    pub deadline: Instant,
    pub enqueue_at: Instant,
}

pub enum SendOrderLane {
    Text = 1,
    Media = 2,
}

pub struct SendContext {
    pub callback: Option<Box<dyn SendMsgCallback>>,
    pub send_order_info: Option<SendOrderInfo>,
}
```

### 12.2 MessageSender 完整结构

```rust
pub struct MessageSender {
    tx: mpsc::Sender<SendTask>,
    text_seq: AtomicI64,
    media_seq: AtomicI64,
    estimator: Arc<ThresholdEstimator>,
    worker_count: usize,
}

impl MessageSender {
    pub fn new(worker_count: usize) -> Self { ... }
    pub async fn submit(&self, task: SendTask) -> Result<()> { ... }
    fn decorate(&self, task: &mut SendTask) { ... }
    fn should_keep_media_ordered(&self, size: i64) -> bool { ... }
    async fn run_task(task: SendTask) { ... }
}
```

### 12.3 MessageBatcher 完整结构

```rust
pub struct MessageBatcher {
    buffer: Option<PushMessages>,
    contexts: Vec<Context>,
    handler: Arc<dyn Fn(Vec<Context>, PushMessages) + Send + Sync>,
    flush_timer: Option<tokio::time::Interval>,
    arrivals: VecDeque<ArrivalRecord>,
    recent_total: AtomicI32,
    first_buffered: Option<Instant>,
}

impl MessageBatcher {
    pub fn new(handler: Arc<dyn Fn(Vec<Context>, PushMessages) + Send + Sync>) -> Self { ... }
    pub async fn enqueue(&self, ctx: Context, batch: PushMessages) { ... }
    pub fn close(&self) { ... }
}
```

### 12.4 注意事项

1. **保序与并发的平衡**：同一 Lane 内的消息必须按 seq 顺序发送，但不同 Lane 可以并行。使用 `tokio::sync::Semaphore` 控制并发度。

2. **阈值估计器的线程安全**：`ThresholdEstimator` 可能被多个 Worker 同时调用 `Update`，需要使用 `Arc<Mutex<ThresholdEstimator>>` 或 `AtomicF64`（nightly）。

3. **写泵 gap 跳过**：在 Rust 中可以使用 `tokio::select!` + `tokio::time::timeout` 实现超时检测，无需手动管理 deadline map。

4. **MessageBatcher 的生命周期**：`Close()` 时需确保刷出剩余缓冲数据并释放 timer。

5. **媒体大小估算的一致性**：`estimateMediaSize` 的取值逻辑必须与 Go SDK 完全一致，否则会导致保序判断偏差。
