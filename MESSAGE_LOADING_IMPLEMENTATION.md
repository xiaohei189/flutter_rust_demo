# 消息加载实现说明

## Go SDK 实现方式

根据 `openim-sdk-core` 的代码分析，Go SDK 的消息加载实现如下：

### 1. API 入口

- **`GetAdvancedHistoryMessageList`**: 获取历史消息（正序，从新到旧）
- **`GetAdvancedHistoryMessageListReverse`**: 获取历史消息（倒序，从旧到新）

### 2. 参数结构 (`GetAdvancedHistoryMessageListParams`)

```go
type GetAdvancedHistoryMessageListParams struct {
    ConversationID   string `json:"conversationID"`   // 会话ID
    StartClientMsgID string `json:"startClientMsgID"` // 起始消息ID（用于翻页）
    Count            int    `json:"count"`            // 每次加载的消息数量
    ViewType         int    `json:"viewType"`        // 视图类型
}
```

### 3. 返回结构 (`GetAdvancedHistoryMessageListCallback`)

```go
type GetAdvancedHistoryMessageListCallback struct {
    MessageList []*sdk_struct.MsgStruct `json:"messageList"` // 消息列表
    IsEnd       bool                    `json:"isEnd"`       // 是否已到末尾
    ErrCode     int32                   `json:"errCode"`     // 错误码
    ErrMsg      string                  `json:"errMsg"`     // 错误信息
}
```

### 4. 核心实现逻辑

1. **数据库查询** (`GetMessageList`):
   - 支持 `isReverse` 参数控制正序/倒序
   - 使用 `startTime`, `startSeq`, `startClientMsgID` 进行翻页
   - 按 `send_time` 和 `seq` 排序

2. **消息连续性检查**:
   - `validateAndFillInternalGaps`: 检查内部连续性
   - `validateAndFillInterBlockGaps`: 检查块间连续性
   - `validateAndFillEndBlockContinuity`: 检查末尾块连续性

3. **自动补全缺失消息**:
   - 如果检测到消息序列不连续，会自动从服务器拉取缺失的消息

### 5. 进入会话时的加载流程

1. 首次进入会话时，`StartClientMsgID` 为空
2. 从数据库获取最新的 `count` 条消息
3. 如果消息数量不足，会递归获取更多消息
4. 返回消息列表和 `IsEnd` 标志

### 6. 翻页加载流程

1. 使用上一次加载的最后一条消息的 `ClientMsgID` 作为 `StartClientMsgID`
2. 从数据库获取比该消息更早的消息
3. 返回消息列表和 `IsEnd` 标志

## Rust 实现对应

### 已实现的功能

1. ✅ `MessageStore::get_history_messages`: 数据库查询方法
2. ✅ `OpenIMClient::get_history_messages`: 客户端方法
3. ✅ `OpenIMBridgeClient::get_history_messages`: 桥接方法

### 参数设计

```rust
pub async fn get_history_messages(
    &self,
    conversation_id: &str,
    count: i32,
    start_time: Option<i64>,  // 用于翻页，获取比这个时间更早的消息
) -> Result<Vec<LocalChatLog>>
```

### 与 Go SDK 的差异

1. **参数简化**: Rust 版本使用 `start_time` 而不是 `startClientMsgID`，更简单但功能相同
2. **缺少连续性检查**: Rust 版本目前没有实现消息连续性检查和自动补全
3. **返回结构**: Rust 版本直接返回 `Vec<LocalChatLog>`，而不是包含 `IsEnd` 的结构

### 建议改进

1. 添加 `IsEnd` 标志到返回结构
2. 实现消息连续性检查（可选，根据需求）
3. 支持 `isReverse` 参数（可选）

## Dart 实现

### 当前状态

- ✅ `MessageService::loadHistoryMessages`: 已实现加载方法框架
- ⚠️ 需要等待代码生成，使 `getHistoryMessages` API 可用
- ⏳ `ChatDetailScreen`: 需要实现滚动加载逻辑

### 使用方式

```dart
// 首次加载
final hasMore = await messageService.loadHistoryMessages(
  conversationId,
  count: 20,
);

// 翻页加载（使用最后一条消息的时间戳）
final lastMessage = messages.first;
final hasMore = await messageService.loadHistoryMessages(
  conversationId,
  count: 20,
  startTime: lastMessage.timestamp.millisecondsSinceEpoch,
);
```

