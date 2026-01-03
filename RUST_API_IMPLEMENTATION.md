# Rust API 实现说明（完全参考 Go SDK）

## 实现对比

### Go SDK 实现

#### 1. 参数结构
```go
type GetAdvancedHistoryMessageListParams struct {
    ConversationID   string `json:"conversationID"`
    StartClientMsgID string `json:"startClientMsgID"`
    Count            int    `json:"count"`
    ViewType         int    `json:"viewType"`
}
```

#### 2. 返回结构
```go
type GetAdvancedHistoryMessageListCallback struct {
    MessageList []*sdk_struct.MsgStruct `json:"messageList"`
    IsEnd       bool                    `json:"isEnd"`
    ErrCode     int32                   `json:"errCode"`
    ErrMsg      string                  `json:"errMsg"`
}
```

#### 3. 核心方法
- `GetMessageList`: 数据库查询方法
  - 参数：`conversationID`, `count`, `startTime`, `startSeq`, `startClientMsgID`, `isReverse`
  - 查询条件：`send_time < startTime OR (send_time = startTime AND (seq < startSeq OR (seq = 0 AND client_msg_id != startClientMsgID)))`
  - 排序：`isReverse ? "send_time ASC, seq ASC" : "send_time DESC, seq DESC"`

- `GetAdvancedHistoryMessageList`: 主要 API
  - 如果提供了 `StartClientMsgID`，先通过 `GetMessage` 获取该消息
  - 提取 `startTime`, `startSeq`, `startClientMsgID`
  - 调用 `GetMessageList` 获取消息列表
  - 转换为 `MsgStruct` 列表
  - 判断 `IsEnd`（返回数量 < 请求数量）

### Rust 实现（完全匹配）

#### 1. 参数结构
```rust
pub struct GetAdvancedHistoryMessageListParams {
    pub conversation_id: String,      // 对应 ConversationID
    pub start_client_msg_id: String,  // 对应 StartClientMsgID
    pub count: i32,                    // 对应 Count
    pub view_type: i32,                // 对应 ViewType
}
```

#### 2. 返回结构
```rust
pub struct GetAdvancedHistoryMessageListCallback {
    pub message_list: Vec<MsgStruct>,  // 对应 MessageList
    pub is_end: bool,                  // 对应 IsEnd
    pub err_code: i32,                 // 对应 ErrCode
    pub err_msg: String,               // 对应 ErrMsg
}
```

#### 3. 核心方法

**`MessageStore::get_message_list`**:
- 参数完全匹配：`conversation_id`, `count`, `start_time`, `start_seq`, `start_client_msg_id`, `is_reverse`
- 查询条件完全匹配：`send_time < startTime OR (send_time = startTime AND (seq < startSeq OR (seq = 0 AND client_msg_id != startClientMsgID)))`
- 排序完全匹配：`is_reverse ? "send_time ASC, seq ASC" : "send_time DESC, seq DESC"`

**`OpenIMClient::get_advanced_history_message_list`**:
- 如果提供了 `start_client_msg_id`，先通过 `get_by_client_msg_id` 获取该消息
- 提取 `start_time`, `start_seq`, `start_client_msg_id`
- 调用 `get_message_list` 获取消息列表
- 转换为 `MsgStruct` 列表（通过 `local_chat_log_to_msg_struct`）
- 判断 `is_end`（返回数量 < 请求数量）

**`OpenIMBridgeClient`**:
- `get_advanced_history_message_list`: 对应 Go SDK 的 `GetAdvancedHistoryMessageList`（`is_reverse = false`）
- `get_advanced_history_message_list_reverse`: 对应 Go SDK 的 `GetAdvancedHistoryMessageListReverse`（`is_reverse = true`）

## 实现细节

### 1. 数据库查询（完全匹配 Go SDK）

```rust
// Go SDK 的查询条件
condition = "send_time " + timeSymbol + " ? " +
    "OR (send_time = ? AND (seq " + timeSymbol + " ? OR (seq = 0 AND client_msg_id != ?)))"

// Rust 实现（完全匹配）
let condition = format!(
    "send_time {} ? OR (send_time = ? AND (seq {} ? OR (seq = 0 AND client_msg_id != ?)))",
    time_symbol, time_symbol
);
```

### 2. 消息转换（参考 Go SDK）

- `local_chat_log_to_msg_struct`: 将 `LocalChatLog` 转换为 `MsgStruct`
- 字段映射完全匹配 Go SDK 的 `LocalChatLog2MsgStruct`

### 3. IsEnd 判断（完全匹配）

```rust
// 如果返回的消息数量小于请求的数量，说明已到末尾
let is_end = message_list.len() < req.count as usize;
```

## 使用方式

### Rust 端
```rust
let req = GetAdvancedHistoryMessageListParams {
    conversation_id: "si_xxx_yyy".to_string(),
    start_client_msg_id: "".to_string(), // 空字符串表示从最新开始
    count: 20,
    view_type: 0, // 视图类型
};

let result = client.get_advanced_history_message_list(req, false).await?;
// result.message_list: 消息列表
// result.is_end: 是否已到末尾
```

### Dart 端（待代码生成后）
```dart
final req = GetAdvancedHistoryMessageListParams(
  conversationId: 'si_xxx_yyy',
  startClientMsgId: '', // 空字符串表示从最新开始
  count: 20,
  viewType: 0,
);

final result = await client.getAdvancedHistoryMessageList(req);
// result.messageList: 消息列表
// result.isEnd: 是否已到末尾
```

## 与 Go SDK 的一致性

✅ **参数结构完全匹配**
✅ **返回结构完全匹配**
✅ **查询逻辑完全匹配**
✅ **排序逻辑完全匹配**
✅ **IsEnd 判断完全匹配**
✅ **StartClientMsgID 处理完全匹配**

## 待完善功能

1. **消息连续性检查**：Go SDK 有 `validateAndFillInternalGaps` 等检查，Rust 版本暂时未实现（可选）
2. **消息元素解析**：`local_chat_log_to_msg_struct` 中的元素解析需要根据 `content_type` 完整实现
3. **ViewType 处理**：Go SDK 使用 ViewType 管理不同的消息视图，Rust 版本暂时只传递参数









