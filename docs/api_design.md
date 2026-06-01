# Rust SDK API 交互设计

> Flutter 侧只调一个方法，内部两步（创建 + 发送）由 Rust 封装

---

## 设计原则

1. **Flutter 侧简洁**：每个消息类型一个方法，不暴露内部细节
2. **Rust 侧对齐 Go**：内部实现 `CreateXxxMessage` + `SendMessage` 两步走
3. **clientMsgID 自动生成**：用户不需要关心
4. **内容结构化**：每种消息类型有独立参数，Rust 内部序列化

---

## Flutter 侧 API

```dart
// === 消息发送（Rust 封装一步） ===

/// 发送文本消息
Future<void> sendTextMessage({
  required String text,
  required String recvId,
  required SessionType sessionType,
});

/// 发送图片消息
Future<void> sendImageMessage({
  required String imagePath,
  required String recvId,
  required SessionType sessionType,
});

/// 发送 Markdown 消息
Future<void> sendMarkdownMessage({
  required String text,
  required String recvId,
  required SessionType sessionType,
});

/// 发送 @ 消息
Future<void> sendAtTextMessage({
  required String text,
  required List<String> atUserIds,
  required String recvId,
  required String groupId,
  required SessionType sessionType,
});

// === 消息操作 ===

/// 撤回消息
Future<void> revokeMessage({
  required String conversationId,
  required int seq,
  required String clientMsgId,
  required SessionType sessionType,
});

// === 历史消息 ===

/// 加载历史消息（分页）
Future<GetHistoryMessagesResult> getHistoryMessages({
  required String conversationId,
  String startClientMsgId = '',
  int count = 20,
});

// === 会话 ===

/// 标记会话已读
Future<void> markConversationAsRead({
  required String conversationId,
  required int readSeq,
});
```

---

## Rust SDK 内部实现

```rust
// ====== 模块一：消息创建 ======

/// 创建文本消息（生成 clientMsgID 等基础字段）
pub fn create_text_message(&self, text: &str) -> MsgStruct {
    let mut msg = MsgStruct::new();
    msg.init_basic_info(ContentType::Text, MsgFrom::User);
    msg.text_elem = Some(TextElem { content: text.into() });
    msg.content = serde_json::to_string(&msg.text_elem).unwrap();
    msg
}

/// 创建图片消息
pub fn create_image_message(&self, path: &str) -> MsgStruct {
    let mut msg = MsgStruct::new();
    msg.init_basic_info(ContentType::Picture, MsgFrom::User);
    msg.picture_elem = Some(PictureElem { source_path: path.into(), .. });
    msg.content = serde_json::to_string(&msg.picture_elem).unwrap();
    msg
}

/// 初始化基础字段（对齐 Go SDK initBasicInfo）
impl MsgStruct {
    pub fn init_basic_info(&mut self, content_type: ContentType, msg_from: MsgFrom) {
        let now = SystemTime::now().duration_since(UNIX_EPOCH).unwrap().as_millis() as i64;
        self.client_msg_id = get_msg_id(&self.send_id);   // MD5 哈希 UUID
        self.create_time = now;
        self.send_time = now;
        self.status = 1;  // MsgStatusSending
        self.is_read = false;
        self.content_type = content_type;
        self.msg_from = msg_from;
        self.send_id = self.user_id.clone();
        self.sender_platform_id = self.platform_id;
        // senderNickname / senderFaceURL 从缓存中取
    }
}

// ====== 模块二：消息发送 ======

/// 发送消息（真正去发）
pub async fn send_message(&self, msg: MsgStruct, recv_id: &str, group_id: &str) -> Result<MsgData, SdkError> {
    // 1. 插入数据库
    // 2. 走 WebSocket 发送
    // 3. 返回 MsgData
}

// ====== 对外暴露的一步 API（Flutter 调用） ======

pub async fn send_text_message(&self, text: &str, recv_id: &str, session_type: SessionType) -> Result<MsgData, SdkError> {
    let msg = self.create_text_message(text);
    self.send_message(msg, recv_id, "").await
}

pub async fn send_image_message(&self, image_path: &str, recv_id: &str, session_type: SessionType) -> Result<MsgData, SdkError> {
    let msg = self.create_image_message(image_path);
    self.send_message(msg, recv_id, "").await
}
```

---

## MsgStruct 定义

```rust
/// 消息结构体（对齐 Go SDK sdk_struct.MsgStruct）
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct MsgStruct {
    pub client_msg_id: String,
    pub server_msg_id: String,
    pub create_time: i64,
    pub send_time: i64,
    pub session_type: i32,
    pub send_id: String,
    pub recv_id: String,
    pub msg_from: i32,
    pub content_type: i32,
    pub sender_platform_id: i32,
    pub sender_nickname: String,
    pub sender_face_url: String,
    pub group_id: String,
    pub content: String,
    pub seq: i64,
    pub is_read: bool,
    pub status: i32,
    pub attached_info: String,
    pub ex: String,
    pub local_ex: String,       // ← 新增
    pub offline_push: String,   // ← 新增

    // 结构化消息元素（仅在创建时使用，序列化后存入 content）
    pub text_elem: Option<TextElem>,
    pub picture_elem: Option<PictureElem>,
    pub markdown_text_elem: Option<MarkdownTextElem>,
    pub at_text_elem: Option<AtTextElem>,
    pub quote_elem: Option<QuoteElem>,
    // ...
}
```

---

## Flutter 调用链路

```
Flutter (Dart)                  Rust SDK                  OpenIM Server
─────────────                  ────────                  ─────────────
sendTextMessage()
  │
  ├─ FRB bridge ──────────────► send_text_message()
  │                               │
  │                               ├─ create_text_message()
  │                               │   ├─ get_msg_id()          ← UUID
  │                               │   ├─ init_basic_info()
  │                               │   └─ 填充 TextElem
  │                               │
  │                               ├─ send_message()
  │                               │   ├─ DB: insert(status=1)
  │                               │   ├─ WS: SendMsg ────────► 服务器
  │                               │   └─ 更新 status=2
  │                               │
  │                               └─ 返回 MsgData
  │                                   │
  ├─ FRB bridge ◄───────────────────┘
  │
  └─ UI 更新
```
