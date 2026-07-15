# operationID Span 全覆盖方案

## 目标

在已有 `#[tracing::instrument]` span 的基础上，确保每个 span 都显式包含 `operationID` 字段，实现全链路日志可串联。

## 现状分析

### 当前各层 span 覆盖情况

| 文件 | Span 名称 | operationID 字段 | 状态 |
|------|-----------|-----------------|------|
| `api/login.rs` | `login` | `fields(operationID = operation_id)` | ✅ 已有 |
| `api/message.rs` | `send_message` | `fields(operationID = operation_id)` | ✅ 已有 |
| `api/message.rs` | 其他函数 (revoke, mark_read 等) | 无 | ❌ 缺失 |
| `client.rs` | `send_ws_message` | `fields(operation_id = %req.operation_id)` | ⚠️ 命名不一致 |
| `message_batcher.rs` | `send` | 无 | ❌ 缺失 |
| `ws_client.rs` | `send_text` | 无 | ❌ 缺失 |
| `ws_client.rs` | `WsClient::connect` | 无 | ❌ 缺失 |
| `manager.rs` | `send_ws_message` | 手动创建 span（无 field） | ⚠️ 非 instrument 宏 |
| `manager.rs` | `on_ws_message` | 通过 `span.enter()` 关联 | ⚠️ 非独立 span |
| `websocket_listener.rs` | `handle_message` | 无 span | ❌ 缺失 |
| `dispatcher.rs` | `dispatch_response` | 无 span | ❌ 缺失 |

### 关键数据结构

```
WsMessage { message_type, data: Vec<u8> }     // 原始 WebSocket 消息
WsRequest { req_id, operation_id, url, data }  // 请求
WsResponse { req_id, operation_id, data, current_span }  // 响应
```

### 核心问题

1. **命名不统一**：`operationID` vs `operation_id`
2. **中间层 span 缺少 operationID**：message_batcher, ws_client, websocket_listener, dispatcher
3. **manager.rs 手动 span 不便于观测**：手动创建的 span 没有 field，只有 event 中的 key=value
4. **websocket_listener 缺少 span**：push 消息、通知等被动接收的消息没有 span 覆盖

## 修改方案

### 1. 统一命名：全部使用 `operationID`（驼峰，与 Go SDK 对齐）

### 2. 文件修改详情

#### 2.1 `client.rs:59` — 统一字段名

```diff
-     operation_id = %req.operation_id,
+     operationID = %req.operation_id,
```

#### 2.2 `message_batcher.rs:37` — 添加 operationID

```diff
- #[tracing::instrument(level = "debug", skip(self, req), fields(req_id = %req.req_id))]
+ #[tracing::instrument(level = "debug", skip(self, req), fields(
+     operationID = %req.operation_id,
+     req_id = %req.req_id
+ ))]
```

#### 2.3 `ws_client.rs:62` — `send_text` 添加 operation_id 参数

当前 `send_text(&self, msg: String)` 无法拿到 operationID。

方案：修改签名为 `send_text(&self, msg: String, operation_id: String)`，在 `#[instrument]` 中添加 field。

调用方变更（仅 `message_batcher.rs` 一处）：
```diff
- self.ws_client.send_text(json).await
+ self.ws_client.send_text(json, req.operation_id.clone()).await
```

#### 2.4 `ws_client.rs` — `connect` 添加 span

在 `connect` 方法上添加 `#[instrument]`（无 operationID，因为连接时还没有请求上下文）。

#### 2.5 `websocket_listener.rs` — `handle_message` 添加 span

`WsMessage` 是原始字节，无法直接拿到 operationID，需要在解析后补充。策略：

- 添加 `#[tracing::instrument(level = "debug", skip(self, msg), fields(msg_type = %msg.message_type))]`
- 在解析出 `WsResponse` 后，如果 `resp` 带有 `current_span`，则 `enter()` 该 span

**实际上**，`handle_message` 调用链是：
```
handle_message → manager.on_ws_message → dispatcher.dispatch_response
```

`manager.on_ws_message` 已经处理了 `resp.current_span.enter()`，所以 `handle_message` 的 span 只需要覆盖消息接收和解析阶段即可。对于 push 消息（没有 operationID），`handle_message` span 本身就可以作为追踪锚点。

#### 2.6 `dispatcher.rs:83` — `dispatch_response` 添加 span

```diff
+ #[tracing::instrument(level = "debug", skip(self, resp), fields(
+     operationID = %resp.operation_id,
+     req_id = %resp.req_id
+ ))]
  pub async fn dispatch_response(&self, resp: WsResponse) -> Result<(), SDKError> {
```

#### 2.7 `manager.rs:75-77` — `send_ws_message` 改用 `#[instrument]`

当前手动创建 span：
```rust
let current_span = tracing::Span::current();
resp.current_span = Some(current_span);
```

改为在方法上添加 `#[instrument]`：
```rust
#[tracing::instrument(level = "debug", skip(self, req), fields(
    operationID = %req.operation_id,
    req_id = %req.req_id,
    url = %req.url,
    msg_len = req.data.len()
))]
pub async fn send_ws_message(&self, req: WsRequest) -> Result<WsResponse, SDKError> {
    // 内部直接用 Span::current() 获取 instrument 自动创建的 span
    let current_span = tracing::Span::current();
    resp.current_span = Some(current_span);
}
```

#### 2.8 `api/message.rs` — 补充其他 API 函数的 span

为 `send_message_through_ws`、`revoke_message`、`mark_read` 等函数添加 `#[instrument]`。

### 3. 修改文件清单

| 序号 | 文件 | 修改内容 |
|------|------|----------|
| 1 | `client.rs` | `operation_id` → `operationID` |
| 2 | `message_batcher.rs` | 添加 `operationID` field |
| 3 | `ws_client.rs` | `send_text` 加 `operation_id` 参数 + span field；`connect` 加 span |
| 4 | `websocket_listener.rs` | `handle_message` 添加 span |
| 5 | `dispatcher.rs` | `dispatch_response` 添加 span |
| 6 | `manager.rs` | `send_ws_message` 改用 `#[instrument]` 宏 |
| 7 | `api/message.rs` | 补充其他函数的 span |

### 4. 预期效果

完成后，任意一个 `login` 请求的 JSON 日志输出：

```json
{"span":"login","fields":{"operationID":"abc123"},"message":"Starting login"}
{"span":"send_ws_message","fields":{"operationID":"abc123","req_id":"req_001","url":"/auth/login"}}
{"span":"send","fields":{"operationID":"abc123","req_id":"req_001"}}
{"span":"send_text","fields":{"operationID":"abc123","msg_len":256}}
{"span":"send_ws_message","fields":{"operationID":"abc123","req_id":"req_001"},"message":"Received ws response"}
{"span":"dispatch_response","fields":{"operationID":"abc123","req_id":"req_001"}}
{"span":"login","fields":{"operationID":"abc123"},"message":"Login completed"}
```

每条日志都可以通过 `operationID` 串联。

### 5. 验证

```bash
cd rust && cargo check
```
