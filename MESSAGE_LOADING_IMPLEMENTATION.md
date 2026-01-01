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


Rust 与 Go 版本功能对比
一、会话处理功能对比
已实现（Rust）
获取会话列表（分页/全部）
增量同步会话
标记会话已读
会话监听器
缺失（Rust）
会话管理
GetOneConversation：根据会话类型和源ID获取单个会话
GetMultipleConversation：批量获取会话
HideConversation：隐藏会话
HideAllConversations：隐藏所有会话
SetConversationDraft：设置会话草稿
SetConversation：设置会话属性（置顶、免打扰等）
会话同步
SyncAllConversationHashReadSeqs：同步所有会话的已读序列号
会话差异计算（diff）：更精细的会话更新逻辑
二、消息处理功能对比
已实现（Rust）
发送消息（文本、图片、语音、视频、文件等）
创建消息（各种类型）
获取历史消息（GetAdvancedHistoryMessageList）
批量插入/更新消息
消息去重
消息撤回
删除消息（本地/服务器）
标记消息已读
消息监听器
缺失（Rust）
消息完整性检查
validateAndFillInternalGaps：检查并填充消息块内部间隙
validateAndFillInterBlockGaps：检查并填充消息块之间的间隙
validateAndFillEndBlockContinuity：检查并填充消息块末尾连续性
checkEndBlock：检查消息块是否结束
fetchAndMergeMissingMessages：获取并合并缺失消息
MaxSeqRecorder（最大序列号记录器）
MaxSeqRecorder：跟踪每个会话的最大序列号
IsNewMsg：判断是否为新消息（用于未读数计算）
Incr：递增序列号
Get/Set：获取/设置序列号
消息内容解析
msgHandleByContentType：根据内容类型解析消息（TextElem、PictureElem 等）
消息内容反序列化逻辑
消息状态管理
updateMsgStatusAndTriggerConversation：更新消息状态并触发会话更新
waitForMessageSyncSeq：等待消息同步序列号
handleExceptionMessages：处理异常消息（重复消息等）
已读回执处理
doReadDrawing：处理已读回执
getAsReadMsgMapAndList：获取已读消息映射和列表
doUnreadCount：处理未读数计算
unreadChangeTrigger：未读数变更触发
消息拉取优化
messagePullForwardEndSeqMap：前向拉取结束序列号映射
messagePullReverseEndSeqMap：反向拉取结束序列号映射
handleEndSeq：处理结束序列号
fetchMessagesWithGapCheck：带间隙检查的消息拉取
用户信息处理
faceURLAndNicknameHandle：处理头像和昵称
singleHandle：单聊消息处理（填充用户信息）
groupHandle：群聊消息处理（填充群组信息）
其他功能
GetActiveConversations：获取活跃会话
getConversationMaxSeq/MinSeq：获取会话最大/最小序列号
setConversationMinSeq：设置会话最小序列号
pullMessageIntoTable：拉取消息到表
三、核心差异总结
1. 消息完整性保证
Go：通过三层检查（内部、块间、块尾）确保消息连续性，自动填充缺失消息
Rust：仅实现基础历史消息拉取，缺少间隙检测与自动填充
2. 未读数计算
Go：使用 MaxSeqRecorder 判断新消息，精确计算未读数
Rust：简化处理，未实现 MaxSeqRecorder，未读数计算不准确
3. 消息内容解析
Go：完整的 msgHandleByContentType，支持所有消息类型解析
Rust：部分实现，缺少完整的内容类型解析逻辑
4. 会话管理
Go：完整的会话管理（隐藏、草稿、属性设置等）
Rust：仅基础会话列表和已读标记
5. 性能优化
Go：使用映射缓存拉取结束序列号，避免重复拉取
Rust：未实现序列号缓存机制
四、优先级建议
高优先级：
MaxSeqRecorder：未读数计算必需
msgHandleByContentType：消息内容解析必需
消息完整性检查：保证消息连续性
中优先级：
会话管理功能（隐藏、草稿等）
已读回执处理优化
用户信息填充（头像、昵称）
低优先级：
消息拉取优化（序列号缓存）
其他辅助功能
以上为当前对比结果，Rust 版本在基础功能上已实现，但在消息完整性、未读数计算和会话管理方面仍需完善