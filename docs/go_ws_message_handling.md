# OpenIM Go SDK WebSocket 消息处理技术文档

> 源码基准：`../openim-sdk-core/`
> 核心包：`internal/interaction/`
> 本文档梳理 Go SDK 从 WebSocket 接收到消息落库/UI 通知的全链路逻辑，作为 Rust SDK 实现的对齐参考。

---

## 一、全链路时序总览

```
握手认证(URL query, reConn:820) → DispatchConnected(881) ─┐
                                                          ↓
readPump(219) ── ReadMessage(259) ── switch messageType(267)
   └─ MessageBinary → handleMessage(649)
         ├─ DecompressWithPool[gzip](compressor.go:88)
         ├─ encoder.Decode[gob] → GeneralWsResp(encoder.go:43)
         ├─ ctx = WithValue("operationID", wsResp.OperationID)(664)
         └─ switch ReqIdentifier(667)
              ├─ PushMsg(2001) → doPushMsg(885) → proto.Unmarshal → PushMessages
              │      → mb.Enqueue(892) ─ MessageBatcher 自适应聚合(message_batcher.go)
              │           └─ doBatch(896) 拼 Batch_op1$op2 → DispatchPushMsg(917)
              │                → pushMsgAndMaxSeqCh(trigger_channel.go:78)
              │                   → MsgSyncer.DoListener(msg_sync.go:173)
              │                      → handlePushMsgAndEvent → CmdPushMsg(216)
              │                         → doPushMsg(372) → pushTriggerAndSync(378)
              │                            → triggerConversation/Notification → 存储/UI
              ├─ RPC类(1001-1007,1003/1004,2004) → Syncer.NotifyResp(699)
              │      → 按 msgIncr 回填 pending channel(ws_resp_asyn.go:120)
              │         → 唤醒 SendReqWaitResp/sendAndWaitResp(178/538)
              ├─ Logout(2003) → NotifyResp + mb.Close + ErrLoginOut(672)
              ├─ KickOnline(2002) → mb.Close + OnError + ErrTokenKicked(678)
              ├─ WsSubUserOnlineStatus(2005) → handlerUserOnlineChange(704)
              └─ default → ErrMsgBinaryTypeNotSupport(708)
```

---

## 二、WS 连接建立与认证

**文件：`internal/interaction/long_conn_mgr.go`，方法 `reConn`（812-883 行）**

OpenIM 没有独立的首条认证消息，认证信息全部拼进 URL query，在 HTTP 握手阶段完成：

```go
// long_conn_mgr.go:820-826
url := fmt.Sprintf("%s?sendID=%s&token=%s&platformID=%d&operationID=%s&isBackground=%t&sdkVersion=%s",
    ccontext.Info(ctx).WsAddr(), ccontext.Info(ctx).UserID(), ccontext.Info(ctx).Token(),
    ccontext.Info(ctx).PlatformID(), ccontext.Info(ctx).OperationID(), c.GetBackground(),
    version.Version)
if c.IsCompression {
    url += fmt.Sprintf("&compression=%s", "gzip")
}
resp, err := c.conn.Dial(url, nil)   // 828 行
```

- **Dial 实现**：`ws_default.go:72-79`，用 `websocket.DefaultDialer.Dial`。
- **认证失败处理**（828-863 行）：握手返回 HTTP 响应体时，解析 `errCode/errMsg/errDlt`；Token 类错误（Expired/Invalid/Malformed/NotValidYet/Unknown/NotExist/Kicked）返回 `needRecon=false` 终止重连。
- **握手成功**（864-882 行）：`writeConnFirstSubMsg` 发首条在线状态订阅 → `OnConnectSuccess` → `SetConnectionStatus(Connected)` → 注册 Pong/Ping handler → **`DispatchConnected` 向 `pushMsgAndMaxSeqCh` 推 `CmdConnSuccesss`，触发 MsgSyncer 拉最新 seq**（881 行）。

**三条 goroutine**（`long_conn_mgr.go:167-171`）：`readPump` / `writePump` / `heartbeat`。

---

## 三、读消息循环（readPump）

**文件：`internal/interaction/long_conn_mgr.go:219-283`**

主循环每轮：生成新 operationID（246 行）→ `reConn`（247 行）→ 设置读限制与超时（257-258 行）→ `c.conn.ReadMessage()`（259 行）。

消息类型区分（267-281 行）：

```go
switch messageType {
case MessageBinary:              // 业务消息，进入解码
    err := c.handleMessage(message)
case MessageText:                // 不支持，直接断开
    c.closedErr = ErrNotSupportMessageProtocol
    return
case CloseMessage:               // 服务端关闭
    c.closedErr = ErrClientClosed
    return
default:
}
```

类型常量（`internal/interaction/constant.go`）：

| 常量 | 值 | 说明 |
|------|----|----|
| `MessageText` | 1 | UTF-8 文本（不支持） |
| `MessageBinary` | 2 | 二进制业务消息 |
| `CloseMessage` | 8 | 关闭帧 |
| `PingMessage` | 9 | Ping |
| `PongMessage` | 10 | Pong |

**Ping/Pong 不在 readPump 的 switch 中处理**，由 gorilla 底层控制帧回调：
- `pingHandler`（947-953 行）→ 重置读超时 → `writePongMsg`（964-974 行）。
- `pongHandler`（956-962 行）→ 重置读超时。
- 主动 Ping 由 `heartbeat`（436-466 行）按 `pingPeriod`（=pongWait*8/10）定时调用 `sendPingMessage`（468-483 行）。

---

## 四、二进制消息解码

**文件：`internal/interaction/long_conn_mgr.go:649-663`，方法 `handleMessage`**

```go
func (c *LongConnMgr) handleMessage(message []byte) error {
    if c.IsCompression {
        message, decompressErr = c.compressor.DecompressWithPool(message)  // Gzip 解压
    }
    var wsResp GeneralWsResp
    err := c.encoder.Decode(message, &wsResp)                              // Gob 解码
    ctx := context.WithValue(c.ctx, "operationID", wsResp.OperationID)     // 见第八节
    switch wsResp.ReqIdentifier { ... }
}
```

- **Gzip 解压**：`compressor.go` `GzipCompressor.DecompressWithPool`（88-106 行），用 `sync.Pool` 复用 `gzip.Reader`，`reader.Reset` + `io.ReadAll`。
- **解码为 GeneralWsResp**：用 **Gob 编码器**（非 protobuf）。`encoder.go` `GobEncoder.Decode`（43-51 行）用 `gob.NewDecoder`。构造注入：`long_conn_mgr.go:145` `encoder: NewGobEncoder()`。
- **`GeneralWsResp` 结构**（`ws_resp_asyn.go:29-36`）：含 `ReqIdentifier / ErrCode / ErrMsg / MsgIncr / OperationID / Data`。`Data` 是 protobuf 编码的业务负载，在具体分支里再 `proto.Unmarshal`。

> ⚠️ **与 Rust 差异**：Go 用 Gob 编码 WS 层，Rust 用 JSON（`serde_json::from_slice`）。业务负载 `Data` 两边都是 protobuf。

---

## 五、reqIdentifier 分发

**文件：`internal/interaction/long_conn_mgr.go:667-709`**
**常量值：`pkg/constant/constant.go:182-193`**

```go
switch wsResp.ReqIdentifier {
case constant.PushMsg:               // 2001
    c.doPushMsg(ctx, wsResp)                              // 669 行
case constant.LogoutMsg:             // 2003
    c.Syncer.NotifyResp(ctx, wsResp)                      // 673 行，先通知等待方
    c.mb.Close()                                          // 676 行，flush 并关闭批处理器
    return sdkerrs.ErrLoginOut                            // 677 行，终止 readPump
case constant.KickOnlineMsg:         // 2002
    c.mb.Close()                                          // 680 行
    err = errs.ErrTokenKicked.WrapMsg("...kicked offline")
    ccontext.GetApiErrCodeCallback(ctx).OnError(ctx, err) // 682 行
    return err                                            // 683 行，终止 readPump
case constant.GetNewestSeq:          // 1001
    fallthrough
case constant.PullMsgByRange:        // 1002
    fallthrough
case constant.PullMsgBySeqList:      // 1005
    fallthrough
case constant.GetConvMaxReadSeq:     // 1006
    fallthrough
case constant.PullConvLastMessage:   // 1007
    fallthrough
case constant.SendMsg:               // 1003
    fallthrough
case constant.SendSignalMsg:         // 1004
    fallthrough
case constant.SetBackgroundStatus:   // 2004
    c.Syncer.NotifyResp(ctx, wsResp)                      // 699 行，RPC 响应回填
case constant.WsSubUserOnlineStatus: // 2005
    c.handlerUserOnlineChange(ctx, wsResp)                // 704 行
default:
    return sdkerrs.ErrMsgBinaryTypeNotSupport             // 708 行
}
```

### 分支语义对照

| reqIdentifier | 值 | 处理 | 是否终止 readPump |
|---------------|----|----|----|
| `PushMsg` | 2001 | `doPushMsg` → 批处理聚合 | 否 |
| `LogoutMsg` | 2003 | `NotifyResp` + `mb.Close` | 是（ErrLoginOut） |
| `KickOnlineMsg` | 2002 | `mb.Close` + `OnError` 回调 | 是（ErrTokenKicked） |
| `GetNewestSeq` 等 8 个 | 1001-1007, 2004 | `NotifyResp`（RPC 响应回填） | 否 |
| `WsSubUserOnlineStatus` | 2005 | `handlerUserOnlineChange` | 否 |
| 未知 | — | 返回 `ErrMsgBinaryTypeNotSupport` | 是 |

### WsSubUserOnlineStatus 处理

`handlerUserOnlineChange`（713-724 行）：`proto.Unmarshal` 成 `sdkws.SubUserOnlineStatusTips` → `c.sub.setUserState` → `callbackUserOnlineChange`（771-789 行）触发 `c.userOnline` 回调。

---

## 六、PushMsg 处理链路

### 6.1 doPushMsg（LongConnMgr 侧）

**文件：`internal/interaction/long_conn_mgr.go:885-894`**

```go
func (c *LongConnMgr) doPushMsg(ctx context.Context, wsResp GeneralWsResp) error {
    var msg sdkws.PushMessages
    err := proto.Unmarshal(wsResp.Data, &msg)   // protobuf 解码业务负载
    log.ZDebug(ctx, "recv push msg", "msgNum", len(msg.Msgs),
        "notificationNum", len(msg.NotificationMsgs), "msg", &msg)
    c.mb.Enqueue(ctx, &msg)                      // 892 行，进入批处理聚合器
    return nil
}
```

`PushMessages` 含 `Msgs` 与 `NotificationMsgs` 两个 `map[conversationID]*PullMsgs`。

### 6.2 MessageBatcher 自适应聚合

**文件：`internal/interaction/message_batcher.go`**
**构造：`long_conn_mgr.go:154` `l.mb = NewMessageBatcher(l.doBatch)`**

关键常量（11-18 行）：

| 常量 | 值 | 说明 |
|------|----|----|
| `maxBatchMessages` | 400 | 缓冲区上限 |
| `minAggregationDelay` | 50ms | 最小聚合延迟 |
| `maxAggregationDelay` | 1s | 最大聚合延迟 |
| `lowLoadWindow` | 10s | 负载统计窗口 |
| `lowLoadMessageLimit` | 20 | 低负载阈值 |
| `highLoadMessageLimit` | 200 | 高负载阈值 |

**Enqueue（185-238 行）自适应逻辑：**

1. **记录到达速率**：`recordArrivalLocked`（240-257 行）用 10s 滑动窗口统计近期消息总数 `recent`。
2. **低负载直通**（196-203 行）：`recent < 20` 时，先 flush 已缓冲的，再把当前 batch 立即单独 dispatch，不缓冲：
   ```go
   if recent < lowLoadMessageLimit {
       toFlush, toCtxs = b.consumeLocked()
       b.cancelTimerLocked()
       b.mutex.Unlock()
       b.dispatch(toCtxs, toFlush)
       b.dispatch([]context.Context{ctx}, batch)
       return
   }
   ```
3. **高负载缓冲**（205-234 行）：append ctx → `mergeLocked` 合并进 buffer（按 conversationID 归并 `Msgs`/`NotificationMsgs`）。判断 flush 时机：
   - `pendingCount >= 400` 且 `recent < 200` → 立即 flush；
   - 否则计算 `totalDelay = computeDelayLocked(recent)`，若 `elapsed >= 1s` 或 `elapsed >= totalDelay` → flush；否则 `ensureTimerLocked(targetFlush)` 设定时器。

**computeDelayLocked（259-270 行）**：
- `recent >= 200` → 1s
- `recent <= 20` → 50ms
- 中间按 `(recent-20)/(200-20)` 线性插值于 [50ms, 1s]

**consumeLocked（122-132 行）**：返回 `(buffer, contexts)` 并清空缓冲。

**dispatch（57-65 行）**：空消息跳过，否则调用 `b.handler(ctxs, messages)`，即 `doBatch`。

### 6.3 doBatch（拼接 operationID）

**文件：`internal/interaction/long_conn_mgr.go:896-920`**

```go
func (c *LongConnMgr) doBatch(ctxs []context.Context, msg *sdkws.PushMessages) {
    var ctx context.Context
    switch len(ctxs) {
    case 0: return
    case 1: ctx = ctxs[0]
    default:
        var buf bytes.Buffer
        buf.WriteString("Batch_")
        for _, v := range ctxs {
            operationID := mcontext.GetOperationID(v)
            if operationID != "" {
                buf.WriteString(operationID)
                buf.WriteString("$")
            }
        }
        data := buf.Bytes()
        data = data[:len(data)-1]                     // 去掉末尾 $
        ctx = mcontext.SetOperationID(ctxs[0], string(data))  // Batch_op1$op2$op3
    }
    if err := common.DispatchPushMsg(ctx, msg, c.pushMsgAndMaxSeqCh); err != nil {
        log.ZError(ctx, "doBatch DispatchPushMsg", err, "msg", msg)
    }
}
```

多个 context 时把各自 operationID 拼成 `Batch_op1$op2$op3` 写回新 ctx，便于链路追踪。

### 6.4 DispatchPushMsg

**文件：`pkg/common/trigger_channel.go:78-80`**

```go
func DispatchPushMsg(ctx context.Context, msg *sdkws.PushMessages, queue chan Cmd2Value) error {
    return DispatchCmd(ctx, constant.CmdPushMsg, msg, queue)
}
```

- `DispatchCmd`（45-48 行）封装成 `Cmd2Value{Cmd: "pushMsg", Value: msg, Ctx: ctx}`。
- `sendCmdToChan`（143-157 行）带 10s 超时把 `Cmd2Value` 写入 channel。
- `queue` 即 `LongConnMgr.pushMsgAndMaxSeqCh`，与 `MsgSyncer.PushMsgAndMaxSeqCh` 是同一 channel。

### 6.5 MsgSyncer 消费

**文件：`internal/interaction/msg_sync.go`**

消费循环 `DoListener`（163-180 行）：
```go
case cmd := <-m.PushMsgAndMaxSeqCh:
    m.handlePushMsgAndEvent(cmd)
```

`handlePushMsgAndEvent`（192-219 行）按 `cmd.Cmd` 分发：
- `CmdConnSuccesss` → `startSync` + `doConnected`（拉 GetMaxSeq 并批量同步）
- `CmdWakeUpDataSync` → `doWakeupDataSync`
- `CmdIMMessageSync` → `doIMMessageSync`
- **`CmdPushMsg`（216-217 行）→ `m.doPushMsg(cmd.Ctx, cmd.Value.(*sdkws.PushMessages))`**

`MsgSyncer.doPushMsg`（372-376 行）：
```go
m.pushTriggerAndSync(ctx, push.Msgs, m.triggerConversation)
m.pushTriggerAndSync(ctx, push.NotificationMsgs, m.triggerNotification)
```

`pushTriggerAndSync`（378-426 行）核心：
- seq==0 的消息（信令）直接 trigger；
- 普通消息判断连续性——`lastSeq == syncedMaxSeq + len(storageMsgs)` 则直接放入并推进；有 gap 则记入 `needSyncSeqMap`，随后 `syncAndTriggerMsgs` 通过 `PullMsgByRange` RPC 补齐。

最终分发走 conversation 事件队列：
- `triggerConversation`（721-733 行）→ `DispatchNewMessage`（`CmdNewMsgCome`）
- `triggerNotification`（753-761 行）→ `DispatchNotification`（`CmdNotification`）

这些都推向 `m.conversationEventQueue`，由 conversation 模块落库并回调上层。

---

## 七、RPC 请求-响应匹配（NotifyResp / WaitResp）

**文件：`internal/interaction/ws_resp_asyn.go`**

核心机制：`WsRespAsyn` 用 `map[msgIncr]chan *GeneralWsResp` 做请求-响应配对（47-50 行）。

### 请求发起

- **`SendReqWaitResp`**（`long_conn_mgr.go:178-211`）：`proto.Marshal` 请求 → 组 `GeneralWsReq`（带 OperationID/SendID）→ 写入 `c.send` channel → 阻塞等 `msg.Resp` → `proto.Unmarshal(v.Data, resp)`。
- **`writeBinaryMsgAndRetry`**（554-573 行）：先 `Syncer.AddCh(msg.SendID)` 申请 `msgIncr` 与 pending channel，写入 `msg.MsgIncr`，再发送。
- **`sendAndWaitResp`**（538-552 行）：等待 channel，`sendAndWaitTime=10s` 超时返回 `ErrNetworkTimeOut`；`defer c.Syncer.DelCh` 清理。

### AddCh（60-72 行）

生成唯一 `msgIncr = userID + "_" + operationID`，创建缓冲为 1 的 channel 存入 map。

### NotifyResp（120-137 行）

由第五节 RPC 类分支调用：
```go
ch := u.GetCh(wsResp.MsgIncr)          // 按 msgIncr 找回 pending channel
if ch == nil { return ...no ch... }
for {
    err := u.notifyCh(ch, &wsResp, 1)  // 把响应写入 channel（1s 超时重试）
    if err != nil { continue }
    return nil
}
```

### 配对流程

```
请求端 AddCh 建立 msgIncr→ch
   ↓ 写入 msg.MsgIncr 发送
服务端响应回来
   ↓ readPump → RPC 分支
NotifyResp 按响应 MsgIncr 找到 ch 回填
   ↓
等待方 sendAndWaitResp/WaitResp 被唤醒
```

> ⚠️ **与 Rust 差异**：Rust 用 `HashMap<String, PendingRequest>` + `oneshot::channel` 实现，`msg_incr` 由 `AtomicU64` 自增生成（`rpc_{n}`），而非 Go 的 `userID_operationID`。

---

## 八、operationID 全链路传递

| 阶段 | 传递方式 | 位置 |
|------|---------|------|
| 握手 | 拼进 URL query | `long_conn_mgr.go:820-823` |
| readPump 每轮 | `WithOperationID` 生成新 opID | `long_conn_mgr.go:246` |
| 入站响应 | `context.WithValue("operationID", wsResp.OperationID)` | `long_conn_mgr.go:664` |
| 批处理拼接 | `GetOperationID`/`SetOperationID` 拼 `Batch_op1$op2$op3` | `long_conn_mgr.go:896-916` |
| 跨 channel | `Cmd2Value.Ctx` 携带 | `trigger_channel.go:38-43` |
| MsgSyncer 消费 | `cmd.Ctx` 贯穿 `doPushMsg`、后续 RPC | `msg_sync.go:217` |

Go 用 `context.Context` 携带 operationID 跨函数/跨 goroutine 传递，全链路可追踪。

> ⚠️ **与 Rust 差异**：Rust 无 context 机制，改用 tracing span + channel 携带 `Vec<String>`，在每个 async 边界重建 span（`ws_binary_resp` → `batch_dispatch` → `push_dispatch`）。

---

## 九、关键文件清单

| 文件 | 职责 |
|------|------|
| `internal/interaction/long_conn_mgr.go` | 连接/读写循环/分发/doPushMsg/doBatch |
| `internal/interaction/message_batcher.go` | 自适应批处理聚合 |
| `internal/interaction/ws_resp_asyn.go` | RPC 请求-响应匹配 |
| `internal/interaction/compressor.go` | gzip 解压 |
| `internal/interaction/encoder.go` | gob 编解码 |
| `internal/interaction/msg_sync.go` | MsgSyncer 消费与同步 |
| `internal/interaction/ws_default.go` + `long_connection.go` | gorilla WebSocket 底层与接口 |
| `internal/interaction/constant.go` | 消息类型常量 |
| `pkg/common/trigger_channel.go` | Cmd2Value 命令通道 |
| `pkg/constant/constant.go:182-193` | reqIdentifier 值定义 |
