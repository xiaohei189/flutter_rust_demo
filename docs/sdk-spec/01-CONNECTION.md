# 连接管理器模块详细设计 (ConnectionManager)

> 模块路径: `rust/src/core/connection/manager.rs`
> Go SDK 对标: `internal/interaction/long_conn_mgr.go` (974 行)

---

## 1. 模块职责

连接管理器是 IM SDK 的网络基础层，负责维护与 OpenIM 服务端的 WebSocket 长连接，核心职责包括：

| 职责 | 说明 |
|------|------|
| WebSocket 长连接管理 | 建立、维护、关闭 WebSocket 连接 |
| 心跳保活 | 按固定间隔发送 Ping 帧，检测连接活性 |
| 断线重连 | 指数退避策略自动重连，最大 300 次 |
| RPC 请求-响应匹配 | 通过 msgIncr 唯一标识匹配请求与响应 |
| 推送消息接收与分发 | 接收服务端推送，路由到 MessageBatcher / MsgSyncer |
| 连接状态管理 | 状态机：Disconnected → Connecting → Connected |

---

## 2. Go SDK 对标分析

### 2.1 核心结构 LongConnMgr

Go SDK 的 `LongConnMgr` 是一个重量级结构体，包含以下关键字段：

```go
type LongConnMgr struct {
    w          sync.Mutex              // 连接状态互斥锁
    connStatus int                     // 连接状态
    conn       LongConn                // WebSocket 连接（gorilla/websocket）
    listener   func() OnConnListener   // 连接状态回调
    userOnline func(map[string][]int32) // 在线状态变更回调
    send       chan Message             // 发送通道（buffered, cap=10）
    pushMsgAndMaxSeqCh chan Cmd2Value   // 推送消息通道
    conversationCh     chan Cmd2Value   // 会话事件通道
    loginMgrCh         chan Cmd2Value   // 登录管理通道
    closedErr          error            // 关闭错误原因
    IsCompression      bool             // 是否启用 gzip 压缩
    Syncer             *WsRespAsyn      // RPC 响应异步匹配器
    encoder            Encoder          // 编码器（GobEncoder）
    compressor         Compressor       // 压缩器（GzipCompressor）
    reconnectStrategy  ReconnectStrategy // 重连策略（循环指数退避）
    connWrite          *sync.Mutex      // 写操作互斥锁
    sub                *subscription    // 在线状态订阅管理
    mb                 *MessageBatcher  // 推送消息批处理器
}
```

### 2.2 关键常量

```go
const (
    writeWait            = 10 * time.Second       // 写超时
    pongWait             = 30 * time.Second       // Pong 等待超时
    pingPeriod           = (pongWait * 8) / 10    // Ping 间隔 = 24s
    maxMessageSize       = 1024 * 1024            // 最大消息体 1MB
    maxReconnectAttempts = 300                    // 最大重连次数
    sendAndWaitTime      = 10 * time.Second       // RPC 响应等待超时
    sendChainMaxWait     = 3 * time.Second        // 有序发送链路最大等待
)
```

### 2.3 连接状态定义

```go
const (
    DefaultNotConnect = iota  // 0 - 未连接
    Closed                    // 1 - 已关闭
    Connecting                 // 2 - 连接中
    Connected                  // 3 - 已连接
)
```

### 2.4 重连策略（循环指数退避）

Go SDK 使用 `ExponentialRetry` 实现循环退避：

```go
type ExponentialRetry struct {
    attempts []int  // [1, 2, 4, 8, 16]
    index    int    // -1 起始
}

func (rs *ExponentialRetry) GetSleepInterval() time.Duration {
    rs.index++
    interval := rs.index % len(rs.attempts)  // 循环取模
    return time.Second * time.Duration(rs.attempts[interval])
}
```

退避序列：1s → 2s → 4s → 8s → 16s → 1s → 2s → ...（循环），成功后 Reset。

---

## 3. Rust 实现架构图

```
┌─────────────────────────────────────────────────────────────────┐
│                      ConnectionManager                          │
│                                                                 │
│  ┌──────────────────┐    ┌──────────────────────────────┐      │
│  │   State Machine   │    │      WebSocket Stream        │      │
│  │                   │    │  ┌────────┐   ┌──────────┐  │      │
│  │  Disconnected ──► │    │  │  Read  │   │  Write   │  │      │
│  │  Connecting   ──► │    │  │  Pump  │   │  Pump    │  │      │
│  │  Connected    ──► │    │  │ (task) │   │ (manual) │  │      │
│  │  Reconnecting ──► │    │  └───┬────┘   └────┬─────┘  │      │
│  │  Kicked       ──► │    │      │              │        │      │
│  └──────────────────┘    └──────┼──────────────┼────────┘      │
│                                  │              │                │
│  ┌──────────────────┐           │              │                │
│  │  Heartbeat Task   │ ◄────────┤              │                │
│  │  (24s interval)   │          │              │                │
│  └──────────────────┘           │              │                │
│                                  ▼              ▲                │
│  ┌──────────────────┐    ┌──────────────┐      │                │
│  │  Pending Requests │    │  Send Queue   │──────┘                │
│  │  msg_incr → oneshot│   │  (mpsc chan)  │                      │
│  └──────────────────┘    └──────────────┘                        │
│                                  │                                │
│  ┌──────────────────┐           ▼                                │
│  │  Reconnect Task   │    ┌──────────────┐                      │
│  │  (cyclic backoff)  │    │  EventBus     │──── SdkEvent::     │
│  │  [1,2,4,8,16]循环  │    │              │     Connected       │
│  │  max=300次         │    │              │──── SdkEvent::      │
│  └──────────────────┘    │              │     PushMessage      │
│                           │              │──── SdkEvent::       │
│                           │              │     KickedOffline    │
│                           └──────────────┘──── SdkEvent::       │
│                                                 Disconnected    │
└─────────────────────────────────────────────────────────────────┘
```

---

## 4. 核心流程

### 4.1 连接流程 (connect / do_connect)

```
用户调用 connect(ws_url, token, user_id, platform_id)
  │
  ├─ 1. 保存连接参数到 RwLock 字段
  ├─ 2. 重置 reconnect_attempts = 0
  ├─ 3. is_manual_disconnect = false
  │
  └─ 调用 do_connect()
       │
       ├─ 1. 设置状态 → Connecting
       ├─ 2. 发布 SdkEvent::Connecting
       ├─ 3. 构建完整 URL:
       │      ws_url/?token=X&sendID=X&platformID=X&operationID=X&isBackground=false&isMsgResp=true&sdkType=js
       ├─ 4. tokio_tungstenite::connect_async(url)
       │      └─ 失败 → 返回 SdkError::connection
       ├─ 5. ws_stream.split() → (write, read)
       ├─ 6. 保存 WsWriter 到 Arc<RwLock<Option<WsWriter>>>
       ├─ 7. 设置状态 → Connected
       ├─ 8. 发布 SdkEvent::Connected
       ├─ 9. 重置 reconnect_attempts = 0
       ├─ 10. spawn_read_loop(read)     ← 独立 tokio task
       ├─ 11. spawn_heartbeat()         ← 独立 tokio task
       └─ 12. spawn_reconnect_loop()    ← 独立 tokio task
```

**与 Go SDK 的差异：**
- Go SDK 连接成功后写入首次订阅消息 `writeConnFirstSubMsg`
- Go SDK 设置 `PongHandler` 和 `PingHandler` 重置读超时
- Go SDK 连接成功后调用 `DispatchConnected` 通知 MsgSyncer

### 4.2 RPC 请求-响应流程 (send_rpc)

```
调用方: send_rpc<T, R>(req_identifier, data)
  │
  ├─ 1. data.encode_to_vec()  → Protobuf 序列化
  ├─ 2. 生成 msg_incr = "rpc_{atomic_counter}"
  ├─ 3. 构建 OpenIMReq { req_identifier, token, send_id, operation_id, msg_incr, data }
  ├─ 4. 创建 oneshot::channel<OpenIMResp>
  ├─ 5. pending_requests.insert(msg_incr, PendingRequest { tx, timer })
  ├─ 6. JSON 序列化 OpenIMReq → WsMessage::Binary
  ├─ 7. writer.write().send(WsMessage::Binary(...))
  │      └─ 失败 → 移除 pending_requests，返回错误
  │
  └─ 8. tokio::time::timeout(RPC_TIMEOUT=30s, rx).await
         │
         ├─ Ok(Ok(resp)) → resp.is_success()?
         │    ├─ Yes  → R::decode(resp.data) → 返回反序列化结果
         │    └─ No   → 返回 SdkError::api(err_code, err_msg)
         ├─ Ok(Err(_)) → 返回 SdkError::connection("channel closed")
         └─ Err(_)     → 返回 SdkError::timeout("rpc timeout")
```

**与 Go SDK 的差异：**

Go SDK 使用 `WsRespAsyn` 管理 channel 映射：

```go
// Go SDK 的 sendAndWaitResp
func (c *LongConnMgr) sendAndWaitResp(msg *GeneralWsReq) (*GeneralWsResp, error) {
    tempChan, err := c.writeBinaryMsgAndRetry(msg)  // 注册 channel + 重试写入
    defer c.Syncer.DelCh(msg.MsgIncr)               // 确保清理
    select {
    case resp := <-tempChan:
        return resp, nil
    case <-time.After(sendAndWaitTime):  // 10s 超时
        return nil, sdkerrs.ErrNetworkTimeOut
    }
}
```

**关键差异点：**
| 特性 | Go SDK | Rust 当前实现 |
|------|--------|---------------|
| 超时时间 | 10s | 30s |
| 写入重试 | 最多 300 次（关闭连接重连） | 无重试 |
| 编码格式 | Gob + Gzip 压缩 | JSON (Text) |
| 连接检查 | GetNewestSeq 不重试 | 无特殊处理 |

### 4.3 心跳流程 (heartbeat / spawn_heartbeat)

```
spawn_heartbeat() → tokio task
  │
  ├─ ticker = interval(24s)  // pingPeriod = (30s * 8) / 10 = 24s
  │
  └─ loop {
       select {
         ├─ cancel_token.cancelled() → break
         │
         └─ ticker.tick() →
              ├─ 检查状态是否为 Connected
              │    └─ 否 → continue
              ├─ writer.write().send(WsMessage::Ping)
              │    └─ 失败 → 设置 Disconnected, 发布 SdkEvent::Disconnected
              └─ （读侧通过 tungstenite 自动回复 Pong）
       }
     }
```

**与 Go SDK 的差异：**

| 特性 | Go SDK | Rust 当前实现 |
|------|--------|---------------|
| Ping 间隔 | 24s (pongWait * 0.8) | 30s |
| Pong 超时 | 30s (pongWait) 未收到则断开 | 无 Pong 超时检测 |
| Ping 内容 | OperationID 字符串 | 空 `vec![]` |
| PingHandler | 收到 Ping → 重置读超时 + 发送 Pong | 自动回复（tungstenite 默认） |
| PongHandler | 收到 Pong → 重置读超时 | 仅 debug log |

**改进建议：** 应按 Go SDK 实现 Pong 超时检测（30s 未收到 Pong 则断开连接）。

### 4.4 重连流程 (spawn_reconnect_loop)

```
spawn_reconnect_loop() → tokio task
  │
  └─ loop {
       ├─ 等待状态变为 Disconnected 或 Reconnecting
       │    └─ 检查 is_manual_disconnect → true 则退出
       │
       ├─ attempts = reconnect_attempts.fetch_add(1)
       ├─ if attempts >= 300 → 发布 SdkEvent::Disconnected, break
       │
       ├─ delay = calculate_reconnect_delay(attempts)
       │    ├─ attempt < 5  → 2^attempt 秒 (1,2,4,8,16)
       │    ├─ attempt < 10 → 16 + (attempt-5)*4 秒
       │    └─ attempt ≥ 10 → 60 秒
       │    └─ 取 min(delay, RECONNECT_MAX_DELAY=60s)
       │
       ├─ 等待 delay（可被 cancel_token 打断）
       ├─ 检查 is_manual_disconnect
       ├─ do_connect() →
       │    ├─ 成功 → 重置 reconnect_attempts = 0
       │    └─ 失败 → 状态 → Disconnected, 发布 Disconnected 事件
       └─ }
```

**与 Go SDK 的差异（关键）：**

Go SDK 的重连发生在 `readPump` 内部，采用**循环指数退避**：

```go
// Go SDK reconnectStrategy = ExponentialRetry{attempts: [1,2,4,8,16]}
// 循环取模：1s → 2s → 4s → 8s → 16s → 1s → 2s → ...
```

Rust 当前实现采用**递增退避 + 线性增长**，最终稳定在 60s。这是不同的策略，需要确认是否需要对齐 Go SDK 的循环退避。

### 4.5 消息分发流程 (handleMessage → event_bus)

Go SDK 的 `handleMessage` 按 `reqIdentifier` 路由消息：

```
收到 WebSocket Binary/Text 消息
  │
  ├─ 解压缩（如果 IsCompression）
  ├─ Decoder.Decode(data) → GeneralWsResp
  │
  └─ switch wsResp.ReqIdentifier:
       │
       ├─ PushMsg (2001) → doPushMsg()
       │    └─ 解码 PushMessages → MessageBatcher.Enqueue()
       │         └─ 批量处理 → DispatchPushMsg → pushMsgAndMaxSeqCh
       │
       ├─ KickOnlineMsg (2002) → 
       │    └─ Mb.Close() + 回调 OnError(TokenKicked)
       │
       ├─ LogoutMsg (2003) →
       │    └─ NotifyResp() + Mb.Close() + 返回 ErrLoginOut
       │
       ├─ WsSubUserOnlineStatus (2005) →
       │    └─ 解码 SubUserOnlineStatusTips → subscription.setUserState()
       │
       └─ RPC 响应类 (1001-1007, 2004) →
            └─ Syncer.NotifyResp() → 按 msgIncr 查找 channel → 通知等待者
```

Rust 当前实现使用 EventBus 发布事件，由 `spawn_push_message_handler` 订阅处理。

---

## 5. RPC 请求-响应匹配机制

### 5.1 GeneralWsReq / GeneralWsResp 格式

```rust
// 请求格式
pub struct GeneralWsReq {
    pub req_identifier: i32,    // 请求标识（1001-1007）
    pub token: String,          // 认证 Token
    pub send_id: String,        // 发送者 ID
    pub operation_id: String,   // 操作 ID（用于追踪）
    pub msg_incr: String,       // 消息递增 ID（唯一标识，用于匹配响应）
    pub data: Vec<u8>,          // Protobuf 编码的请求数据
}

// 响应格式
pub struct GeneralWsResp {
    pub req_identifier: i32,    // 对应的请求标识
    pub err_code: i32,          // 错误码（0 表示成功）
    pub err_msg: String,        // 错误信息
    pub msg_incr: String,       // 对应请求的 msg_incr
    pub operation_id: String,   // 对应请求的 operation_id
    pub data: Vec<u8>,          // Protobuf 编码的响应数据
}
```

### 5.2 msgIncr 匹配机制

```
发送方 (writePump/send_rpc):
  1. 生成 msg_incr = "{user_id}_{operation_id}"
  2. pending_requests[msg_incr] = oneshot::Sender
  3. 序列化并发送 GeneralWsReq

接收方 (readPump):
  1. 解码 GeneralWsResp
  2. 查找 pending_requests[wsResp.msg_incr]
  3. 找到 → oneshot::send(resp) 通知等待方
  4. 未找到 → 作为推送消息处理
```

### 5.3 Go SDK WsRespAsyn 实现

```go
type WsRespAsyn struct {
    wsNotification map[string]chan *GeneralWsResp  // msgIncr → channel
    wsMutex        sync.RWMutex
}

// AddCh: 创建唯一 msgIncr + channel
func (u *WsRespAsyn) AddCh(userID string) (string, chan *GeneralWsResp) {
    for {
        msgIncr := GenMsgIncr(userID)  // userID + "_" + OperationIDGenerator()
        ch := make(chan *GeneralWsResp, 1)
        if _, ok := u.wsNotification[msgIncr]; ok {
            continue  // 冲突则重试
        }
        u.wsNotification[msgIncr] = ch
        return msgIncr, ch
    }
}

// NotifyResp: 按 msgIncr 查找 channel 并通知
func (u *WsRespAsyn) NotifyResp(ctx context.Context, wsResp GeneralWsResp) error {
    ch := u.GetCh(wsResp.MsgIncr)
    if ch == nil {
        return errors.New("no channel found")
    }
    // 无限重试发送（1s 超时后重试）
    for {
        err := u.notifyCh(ch, &wsResp, 1)
        if err != nil {
            continue
        }
        return nil
    }
}

// DelCh: 请求完成后清理
func (u *WsRespAsyn) DelCh(msgIncr string) {
    ch, ok := u.wsNotification[msgIncr]
    if ok {
        close(ch)
        delete(u.wsNotification, msgIncr)
    }
}
```

### 5.4 超时处理

- **Go SDK**: `sendAndWaitTime = 10s`，select 等待 channel 或超时
- **Rust 当前**: `RPC_TIMEOUT = 30s`，tokio::time::timeout 等待 oneshot
- **差异**: 超时时间不同（10s vs 30s），Rust 侧偏保守

---

## 6. 推送消息处理

### 6.1 PushMsg (reqIdentifier = 2001)

```
handleMessage → PushMsg 分支
  │
  ├─ Proto.Unmarshal(wsResp.Data) → sdkws.PushMessages
  │    ├─ msgs: map[string]*PullMsgs          // 普通消息
  │    └─ notification_msgs: map[string]*PullMsgs  // 通知消息
  │
  └─ MessageBatcher.Enqueue(ctx, &pushMessages)
       │
       ├─ 低负载 (< 20条/10s) → 直接处理
       ├─ 高负载 → 聚合后处理 (50ms ~ 1s 延迟)
       │    ├─ 聚合 buffer: map[convID] → append(msgs)
       │    ├─ 缓冲达 400 条 → 强制 flush
       │    └─ 定时器触发 → flush
       │
       └─ doBatch(ctxs, msgs) → DispatchPushMsg → pushMsgAndMaxSeqCh
            └─ MsgSyncer.doPushMsg()
```

Go SDK 的 MessageBatcher 实现了自适应聚合：
- 低负载窗口 (10s 内 < 20 条)：直接处理，无延迟
- 高负载窗口：聚合 50ms ~ 1s，缓冲最多 400 条
- Rust 当前实现**未包含** MessageBatcher

### 6.2 KickOnlineMsg (reqIdentifier = 2002)

```
handleMessage → KickOnlineMsg 分支
  │
  ├─ MessageBatcher.Close()      // 关闭批处理器
  ├─ 回调 OnError(TokenKicked)   // 通知上层
  └─ return err                  // readPump 退出
```

Rust 当前实现：发布 `SdkEvent::KickedOffline`，设置状态为 `Kicked`，设置 `is_manual_disconnect = true`（阻止重连）。

### 6.3 LogoutMsg (reqIdentifier = 2003)

```
handleMessage → LogoutMsg 分支
  │
  ├─ Syncer.NotifyResp(ctx, wsResp)  // 通知等待方
  ├─ MessageBatcher.Close()
  └─ return ErrLoginOut              // readPump 退出
```

### 6.4 WsSubUserOnlineStatus (reqIdentifier = 2005)

```
handleMessage → WsSubUserOnlineStatus 分支
  │
  ├─ Proto.Unmarshal(wsResp.Data) → sdkws.SubUserOnlineStatusTips
  ├─ subscription.setUserState(tips.Subscribers) → map[userID]platformIDs
  └─ callbackUserOnlineChange(changedUsers)
       └─ userOnline(users)  // 通知上层 UI 更新
```

---

## 7. WebSocket 请求/响应标识符完整表

| ReqIdentifier | 值 | 方向 | 说明 | 请求类型 | 响应类型 |
|---------------|------|------|------|----------|----------|
| `GetNewestSeq` | 1001 | C→S | 获取服务端最新 Seq | `GetMaxSeqReq` | `GetMaxSeqResp` |
| `PullMsgByRange` | 1002 | C→S | 按范围拉取消息 | `PullMessageBySeqsReq` | `PullMessageBySeqsResp` |
| `SendMsg` | 1003 | C→S | 发送消息 | `MsgData` | `UserSendMsgResp` |
| `SendSignalMsg` | 1004 | C→S | 发送信令消息 | `MsgData` | `UserSendMsgResp` |
| `PullMsgBySeqList` | 1005 | C→S | 按 Seq 列表拉取消息 | `PullMessageBySeqsReq` | `PullMessageBySeqsResp` |
| `GetConvMaxReadSeq` | 1006 | C→S | 获取会话已读/最大 Seq | `GetConversationsHasReadAndMaxSeqReq` | `GetConversationsHasReadAndMaxSeqResp` |
| `PullConvLastMessage` | 1007 | C→S | 获取会话最后一条消息 | `GetLastMessageReq` | `GetLastMessageResp` |
| `PushMsg` | 2001 | S→C | 服务端推送新消息 | — | `PushMessages` (protobuf) |
| `KickOnlineMsg` | 2002 | S→C | 被踢下线 | — | — |
| `LogoutMsg` | 2003 | S→C | 登出消息 | — | — |
| `SetBackgroundStatus` | 2004 | C→S | 设置前后台状态 | — | — |
| `WsSubUserOnlineStatus` | 2005 | C↔S | 订阅用户在线状态 | `SubUserOnlineStatus` | `SubUserOnlineStatusTips` |

---

## 8. Rust 当前实现 vs Go SDK 对比

### 8.1 已实现的功能

| 功能 | 状态 | 说明 |
|------|------|------|
| WebSocket 连接 | ✅ 已实现 | 使用 `tokio-tungstenite` |
| 读消息循环 | ✅ 已实现 | `spawn_read_loop`，支持 Text/Binary/Ping/Pong/Close |
| 心跳发送 | ⚠️ 部分实现 | 间隔 30s（Go SDK 24s），无 Pong 超时检测 |
| RPC 请求-响应 | ✅ 已实现 | oneshot channel + 30s 超时 |
| 推送消息接收 | ✅ 已实现 | EventBus 分发 PushMessages / PushNotificationMessages |
| 踢下线处理 | ✅ 已实现 | SdkEvent::KickedOffline |
| 断线重连 | ⚠️ 策略不同 | 独立 task + 递增退避（Go SDK 循环退避） |
| 连接状态管理 | ✅ 已实现 | 枚举状态机 + Arc<RwLock> |

### 8.2 缺失的功能

| 功能 | 说明 | 优先级 |
|------|------|--------|
| Gob 编码 + Gzip 压缩 | Go SDK 使用 GobEncoder + GzipCompressor，Rust 用 JSON | 高 |
| MessageBatcher | Go SDK 的自适应聚合推消息批处理器，Rust 未实现 | 中 |
| Pong 超时检测 | Go SDK 收到 Ping 重置 30s 读超时，Rust 无此机制 | 高 |
| 订阅管理 (subscription) | Go SDK 管理在线状态订阅的增删，Rust 由 OnlineStatusManager 处理 | 低 |
| WritePump 有序发送 | Go SDK 支持 Text/Media 双通道有序发送，Rust 无此机制 | 低 |
| 首次连接订阅 | Go SDK 连接成功后写入 `writeConnFirstSubMsg` | 中 |

### 8.3 需要修改的部分

| 修改项 | 当前实现 | Go SDK 对标 | 说明 |
|--------|----------|-------------|------|
| 心跳间隔 | 30s | 24s | 改为 `pongWait * 0.8` |
| RPC 超时 | 30s | 10s | 改为 10s |
| 重连策略 | 递增退避(最大60s) | 循环退避[1,2,4,8,16] | 改为循环指数退避 |
| 写入重试 | 无 | 最多 300 次 | send_rpc 失败时应重试 |
| 消息编码 | JSON Text | Gob + Gzip Binary | 改为 Binary + 编码/压缩 |
| 重连时状态 | 设置为 Reconnecting | 在 readPump 中同步 | 对齐 readPump 模式 |

---

## 9. 涉及的数据库表

连接管理器本身不直接操作数据库。连接状态和认证信息通过 `RuntimeContext` / `ClientConfig` 传递：

- Token、user_id、ws_url 等连接参数在登录时由上层设置
- 连接成功后触发 `SdkEvent::Connected`，由 MessageSyncer 读取数据库中的 seq 信息

---

## 10. 测试用例设计

| 测试用例 | 描述 | 预期结果 | 优先级 |
|----------|------|----------|--------|
| `test_connect_success` | 正常连接到 WebSocket 服务器 | 状态 → Connected，发布 SdkEvent::Connected | P0 |
| `test_connect_failure` | 连接失败（URL 无效/服务器不可达） | 状态保持 Disconnected，发布 SdkEvent::Disconnected | P0 |
| `test_rpc_success` | 发送 RPC 请求并收到正常响应 | 返回解码后的响应对象 | P0 |
| `test_rpc_timeout` | RPC 请求发出但无响应 | 30s 后返回 SdkError::timeout | P0 |
| `test_rpc_pending_cleanup` | RPC 超时后 pending_requests 被清理 | 超时后 pending_requests 中无残留条目 | P1 |
| `test_heartbeat_interval` | 验证心跳间隔为 24s | 每 24s 发送一次 Ping | P1 |
| `test_pong_timeout_triggers_reconnect` | Pong 超时（30s 未收到 Pong） | 触发断线重连 | P1 |
| `test_reconnect_cyclic_backoff` | 连接断开后重连退避策略 | 1s → 2s → 4s → 8s → 16s → 1s → ... 循环 | P0 |
| `test_reconnect_max_attempts` | 重连次数达到 300 次上限 | 发布 SdkEvent::Disconnected，停止重连 | P1 |
| `test_reconnect_success_resets_counter` | 重连成功后重置计数器 | reconnect_attempts = 0 | P1 |
| `test_kick_offline_handling` | 收到 KickOnlineMsg (2002) | 状态 → Kicked，发布 KickedOffline，不自动重连 | P0 |
| `test_token_expired_no_retry` | 连接失败原因 Token 过期 | 不重连，发布 TokenExpired 事件 | P0 |
| `test_manual_disconnect_no_reconnect` | 手动调用 disconnect() | 不触发自动重连 | P0 |
| `test_push_msg_distribution` | 收到 PushMsg (2001) | 正确解码 PushMessages，发布对应事件 | P0 |
| `test_connection_state_transitions` | 状态转换完整性 | Disconnected → Connecting → Connected → Disconnected | P1 |
| `test_concurrent_send_rpc` | 多个 RPC 并发发送 | 每个 RPC 通过 msgIncr 正确匹配响应 | P1 |

---

## 附录：相关文件索引

| 文件 | 说明 |
|------|------|
| `rust/src/core/connection/manager.rs` | Rust 连接管理器实现 |
| `rust/src/domain/constant/types.rs` | WS 标识符常量定义 |
| `rust/src/domain/event/types.rs` | SdkEvent 事件定义 |
| `rust/src/core/connection/ws.rs` | WebSocket 协议类型定义 |
| Go SDK: `internal/interaction/long_conn_mgr.go` | Go 连接管理器（974 行） |
| Go SDK: `internal/interaction/ws_resp_asyn.go` | Go RPC 异步匹配器 |
| Go SDK: `internal/interaction/reconnect.go` | Go 循环指数退避策略 |
| Go SDK: `internal/interaction/message_batcher.go` | Go 消息批处理器 |
| Go SDK: `internal/interaction/subscription.go` | Go 在线状态订阅管理 |
| Go SDK: `internal/interaction/encoder.go` | Go 编码器（Gob） |
