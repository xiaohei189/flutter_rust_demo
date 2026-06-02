use serde::{Deserialize, Serialize};
use std::time::{SystemTime, UNIX_EPOCH};
use crate::infra::database::models::LocalChatLog;
use crate::protocol::sdkws::MsgData;

/// 生成消息 ID（对齐 Go SDK utils.GetMsgID）
/// Go: MD5(nanoTime + sendID + random)
pub fn get_msg_id(send_id: &str) -> String {
    use std::collections::hash_map::DefaultHasher;
    use std::hash::{Hash, Hasher};

    let now = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap()
        .as_nanos();
    let mut hasher = DefaultHasher::new();
    now.hash(&mut hasher);
    send_id.hash(&mut hasher);
    let hash = hasher.finish();
    format!("{:x}{:x}", now, hash)
}

/// 文本消息元素（对齐 Go SDK TextElem）
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct TextElem {
    pub content: String,
}

/// 图片基础信息
#[derive(Clone, Debug, Serialize, Deserialize, Default)]
pub struct PictureBaseInfo {
    pub width: i32,
    pub height: i32,
    #[serde(rename = "type")]
    pub picture_type: String,
    pub size: i64,
    pub url: String,
    pub uuid: String,
}

/// 图片消息元素（对齐 Go SDK PictureElem）
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct PictureElem {
    pub source_path: String,
    pub source_picture: PictureBaseInfo,
    pub big_picture: PictureBaseInfo,
    pub snapshot_picture: PictureBaseInfo,
}

/// 语音消息元素（对齐 Go SDK SoundElem）
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct SoundElem {
    pub uuid: String,
    pub sound_path: String,
    pub source_url: String,
    pub data_size: i64,
    pub duration: i64,
    pub sound_type: String,
}

/// 视频消息元素（对齐 Go SDK VideoElem）
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct VideoElem {
    pub video_path: String,
    pub video_uuid: String,
    pub video_url: String,
    pub video_type: String,
    pub video_size: i64,
    pub duration: i64,
    pub snapshot_path: String,
    pub snapshot_uuid: String,
    pub snapshot_size: i64,
    pub snapshot_url: String,
    pub snapshot_width: i32,
    pub snapshot_height: i32,
    pub snapshot_type: String,
}

/// 文件消息元素（对齐 Go SDK FileElem）
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct FileElem {
    pub file_path: String,
    pub uuid: String,
    pub source_url: String,
    pub file_name: String,
    pub file_size: i64,
    pub file_type: String,
}

/// @ 消息元素（对齐 Go SDK AtTextElem）
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct AtTextElem {
    pub text: String,
    pub at_user_list: Vec<String>,
    pub at_users_info: Vec<AtInfo>,
    pub quote_message: Option<Box<MsgStruct>>,
}

/// @ 用户信息
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct AtInfo {
    pub at_user_id: String,
    pub group_nickname: String,
}

/// 引用消息元素（对齐 Go SDK QuoteElem）
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct QuoteElem {
    pub text: String,
    pub quote_message: Option<Box<MsgStruct>>,
}

/// 合并转发元素（对齐 Go SDK MergeElem）
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct MergeElem {
    pub title: String,
    pub abstract_list: Vec<String>,
    pub multi_message: Vec<MsgStruct>,
}

/// 名片元素（对齐 Go SDK CardElem）
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct CardElem {
    pub user_id: String,
    pub nickname: String,
    pub face_url: String,
    pub ex: String,
}

/// 位置元素（对齐 Go SDK LocationElem）
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct LocationElem {
    pub description: String,
    pub longitude: f64,
    pub latitude: f64,
}

/// 表情元素（对齐 Go SDK FaceElem）
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct FaceElem {
    pub index: i32,
    pub data: String,
}

/// 自定义元素（对齐 Go SDK CustomElem）
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct CustomElem {
    pub data: String,
    pub extension: String,
    pub description: String,
}

/// 富文本元素（对齐 Go SDK AdvancedTextElem）
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct AdvancedTextElem {
    pub text: String,
    pub message_entity_list: Vec<MessageEntity>,
}

/// Markdown 文本元素（对齐 Go SDK MarkdownTextElem）
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct MarkdownTextElem {
    pub content: String,
}

/// 消息实体（用于富文本）
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct MessageEntity {
    #[serde(rename = "type")]
    pub entity_type: String,
    pub offset: i32,
    pub length: i32,
    pub url: String,
    pub ex: String,
}

/// 离线推送信息（对齐 Go SDK OfflinePushInfo）
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct OfflinePushInfo {
    pub title: String,
    pub desc: String,
    pub ex: String,
    pub ios_push_sound: String,
    pub ios_badge_count: bool,
    pub signal_info: String,
}

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
    pub local_ex: String,

    pub text_elem: Option<TextElem>,
    pub picture_elem: Option<PictureElem>,
    pub sound_elem: Option<SoundElem>,
    pub video_elem: Option<VideoElem>,
    pub file_elem: Option<FileElem>,
    pub at_text_elem: Option<AtTextElem>,
    pub quote_elem: Option<QuoteElem>,
    pub merge_elem: Option<MergeElem>,
    pub card_elem: Option<CardElem>,
    pub location_elem: Option<LocationElem>,
    pub face_elem: Option<FaceElem>,
    pub custom_elem: Option<CustomElem>,
    pub advanced_text_elem: Option<AdvancedTextElem>,
    pub markdown_text_elem: Option<MarkdownTextElem>,
    pub offline_push: Option<OfflinePushInfo>,
}

impl Default for MsgStruct {
    fn default() -> Self {
        Self {
            client_msg_id: String::new(),
            server_msg_id: String::new(),
            create_time: 0,
            send_time: 0,
            session_type: 0,
            send_id: String::new(),
            recv_id: String::new(),
            msg_from: 100,
            content_type: 0,
            sender_platform_id: 0,
            sender_nickname: String::new(),
            sender_face_url: String::new(),
            group_id: String::new(),
            content: String::new(),
            seq: 0,
            is_read: false,
            status: 0,
            attached_info: String::new(),
            ex: String::new(),
            local_ex: String::new(),
            text_elem: None,
            picture_elem: None,
            sound_elem: None,
            video_elem: None,
            file_elem: None,
            at_text_elem: None,
            quote_elem: None,
            merge_elem: None,
            card_elem: None,
            location_elem: None,
            face_elem: None,
            custom_elem: None,
            advanced_text_elem: None,
            markdown_text_elem: None,
            offline_push: None,
        }
    }
}

/// 消息发送状态常量（对齐 Go SDK constant.MsgStatusXxx）
pub const MSG_STATUS_SENDING: i32 = 1;
pub const MSG_STATUS_SEND_SUCCESS: i32 = 2;
pub const MSG_STATUS_SEND_FAILED: i32 = 3;
pub const MSG_STATUS_HAS_DELETED: i32 = 4;

/// 消息来源常量
pub const MSG_FROM_USER: i32 = 100;

impl MsgStruct {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn create_text_message(text: &str) -> MsgStruct {
        let mut msg = MsgStruct::new();
        msg.content_type = 101;
        msg.msg_from = MSG_FROM_USER;
        let elem = TextElem { content: text.to_string() };
        msg.content = serde_json::to_string(&elem).unwrap();
        msg.text_elem = Some(elem);
        msg
    }

    pub fn create_image_message(
        source_path: &str, source: PictureBaseInfo, big: PictureBaseInfo, snapshot: PictureBaseInfo,
    ) -> MsgStruct {
        let mut msg = MsgStruct::new();
        msg.content_type = 102;
        msg.msg_from = MSG_FROM_USER;
        let elem = PictureElem {
            source_path: source_path.to_string(),
            source_picture: source,
            big_picture: big,
            snapshot_picture: snapshot,
        };
        msg.content = serde_json::to_string(&elem).unwrap();
        msg.picture_elem = Some(elem);
        msg
    }

    pub fn create_sound_message(elem: SoundElem) -> MsgStruct {
        let mut msg = MsgStruct::new();
        msg.content_type = 103;
        msg.msg_from = MSG_FROM_USER;
        msg.content = serde_json::to_string(&elem).unwrap();
        msg.sound_elem = Some(elem);
        msg
    }

    pub fn create_video_message(elem: VideoElem) -> MsgStruct {
        let mut msg = MsgStruct::new();
        msg.content_type = 104;
        msg.msg_from = MSG_FROM_USER;
        msg.content = serde_json::to_string(&elem).unwrap();
        msg.video_elem = Some(elem);
        msg
    }

    pub fn create_file_message(elem: FileElem) -> MsgStruct {
        let mut msg = MsgStruct::new();
        msg.content_type = 105;
        msg.msg_from = MSG_FROM_USER;
        msg.content = serde_json::to_string(&elem).unwrap();
        msg.file_elem = Some(elem);
        msg
    }

    pub fn create_at_text_message(
        text: &str, at_user_list: Vec<String>, at_users_info: Vec<AtInfo>,
        quote_msg: Option<Box<MsgStruct>>,
    ) -> MsgStruct {
        let mut msg = MsgStruct::new();
        msg.content_type = 106;
        msg.msg_from = MSG_FROM_USER;
        let mut at_msg = quote_msg.clone();
        if let Some(ref mut qm) = at_msg {
            if qm.content_type == 114 {
                qm.content_type = 101;
                qm.text_elem = Some(TextElem { content: qm.content.clone() });
                qm.quote_elem = None;
            }
        }
        let elem = AtTextElem {
            text: text.to_string(),
            at_user_list,
            at_users_info,
            quote_message: at_msg,
        };
        msg.content = serde_json::to_string(&elem).unwrap();
        msg.at_text_elem = Some(elem);
        msg
    }

    pub fn create_merger_message(
        messages: Vec<MsgStruct>, title: &str, summaries: Vec<String>,
    ) -> MsgStruct {
        let mut msg = MsgStruct::new();
        msg.content_type = 107;
        msg.msg_from = MSG_FROM_USER;
        let elem = MergeElem {
            title: title.to_string(),
            abstract_list: summaries,
            multi_message: messages,
        };
        msg.content = serde_json::to_string(&elem).unwrap();
        msg.merge_elem = Some(elem);
        msg
    }

    pub fn create_card_message(elem: CardElem) -> MsgStruct {
        let mut msg = MsgStruct::new();
        msg.content_type = 108;
        msg.msg_from = MSG_FROM_USER;
        msg.content = serde_json::to_string(&elem).unwrap();
        msg.card_elem = Some(elem);
        msg
    }

    pub fn create_location_message(
        description: &str, longitude: f64, latitude: f64,
    ) -> MsgStruct {
        let mut msg = MsgStruct::new();
        msg.content_type = 109;
        msg.msg_from = MSG_FROM_USER;
        let elem = LocationElem { description: description.to_string(), longitude, latitude };
        msg.content = serde_json::to_string(&elem).unwrap();
        msg.location_elem = Some(elem);
        msg
    }

    pub fn create_custom_message(
        data: &str, extension: &str, description: &str,
    ) -> MsgStruct {
        let mut msg = MsgStruct::new();
        msg.content_type = 110;
        msg.msg_from = MSG_FROM_USER;
        let elem = CustomElem {
            data: data.to_string(),
            extension: extension.to_string(),
            description: description.to_string(),
        };
        msg.content = serde_json::to_string(&elem).unwrap();
        msg.custom_elem = Some(elem);
        msg
    }

    pub fn create_quote_message(
        text: &str, quoted_msg: Box<MsgStruct>,
    ) -> MsgStruct {
        let mut msg = MsgStruct::new();
        msg.content_type = 114;
        msg.msg_from = MSG_FROM_USER;
        let mut qm = *quoted_msg.clone();
        if qm.content_type == 114 {
            qm.content_type = 101;
            qm.text_elem = Some(TextElem { content: qm.content.clone() });
            qm.quote_elem = None;
        }
        let elem = QuoteElem { text: text.to_string(), quote_message: Some(Box::new(qm)) };
        msg.content = serde_json::to_string(&elem).unwrap();
        msg.quote_elem = Some(elem);
        msg
    }

    pub fn create_face_message(index: i32, data: &str) -> MsgStruct {
        let mut msg = MsgStruct::new();
        msg.content_type = 115;
        msg.msg_from = MSG_FROM_USER;
        let elem = FaceElem { index, data: data.to_string() };
        msg.content = serde_json::to_string(&elem).unwrap();
        msg.face_elem = Some(elem);
        msg
    }

    pub fn create_advanced_text_message(
        text: &str, entities: Vec<MessageEntity>,
    ) -> MsgStruct {
        let mut msg = MsgStruct::new();
        msg.content_type = 117;
        msg.msg_from = MSG_FROM_USER;
        let elem = AdvancedTextElem { text: text.to_string(), message_entity_list: entities };
        msg.content = serde_json::to_string(&elem).unwrap();
        msg.advanced_text_elem = Some(elem);
        msg
    }

    pub fn create_markdown_message(text: &str) -> MsgStruct {
        let mut msg = MsgStruct::new();
        msg.content_type = 118;
        msg.msg_from = MSG_FROM_USER;
        let elem = MarkdownTextElem { content: text.to_string() };
        msg.content = serde_json::to_string(&elem).unwrap();
        msg.markdown_text_elem = Some(elem);
        msg
    }

    /// 根据 content_type 从 content 字段恢复 typed elem（对齐 Go SDK PopulateMsgStructByContentType）
    pub fn populate_elem_by_content_type(&mut self) {
        let content = self.content.clone();
        match self.content_type {
            101 => { let _ = serde_json::from_str::<TextElem>(&content).map(|e| { self.text_elem = Some(e); }); }
            102 => { let _ = serde_json::from_str::<PictureElem>(&content).map(|e| { self.picture_elem = Some(e); }); }
            103 => { let _ = serde_json::from_str::<SoundElem>(&content).map(|e| { self.sound_elem = Some(e); }); }
            104 => { let _ = serde_json::from_str::<VideoElem>(&content).map(|e| { self.video_elem = Some(e); }); }
            105 => { let _ = serde_json::from_str::<FileElem>(&content).map(|e| { self.file_elem = Some(e); }); }
            106 => { let _ = serde_json::from_str::<AtTextElem>(&content).map(|e| { self.at_text_elem = Some(e); }); }
            107 => { let _ = serde_json::from_str::<MergeElem>(&content).map(|e| { self.merge_elem = Some(e); }); }
            108 => { let _ = serde_json::from_str::<CardElem>(&content).map(|e| { self.card_elem = Some(e); }); }
            109 => { let _ = serde_json::from_str::<LocationElem>(&content).map(|e| { self.location_elem = Some(e); }); }
            110 => { let _ = serde_json::from_str::<CustomElem>(&content).map(|e| { self.custom_elem = Some(e); }); }
            114 => { let _ = serde_json::from_str::<QuoteElem>(&content).map(|e| { self.quote_elem = Some(e); }); }
            115 => { let _ = serde_json::from_str::<FaceElem>(&content).map(|e| { self.face_elem = Some(e); }); }
            117 => { let _ = serde_json::from_str::<AdvancedTextElem>(&content).map(|e| { self.advanced_text_elem = Some(e); }); }
            118 => { let _ = serde_json::from_str::<MarkdownTextElem>(&content).map(|e| { self.markdown_text_elem = Some(e); }); }
            _ => {}
        }
    }

    /// MsgStruct → MsgData（对齐 Go SDK MsgStructToMsgData）
    /// 基础字段映射，content 转为 bytes
    pub fn to_msg_data(&self) -> MsgData {
        MsgData::from(self)
    }

    /// MsgData → MsgStruct（对齐 Go SDK MsgDataToMsgStruct）
    /// 基础字段映射，bytes 转回 content，自动恢复 typed elem
    pub fn from_msg_data(data: &MsgData) -> Self {
        MsgStruct::from(data)
    }

    /// MsgStruct → LocalChatLog（对齐 Go SDK MsgStructToLocalChatLog）
    /// 根据 ContentType 序列化 elem 到 content 字段（string 存储）
    pub fn to_local_chat_log(&self) -> LocalChatLog {
        LocalChatLog::from(self)
    }

    /// LocalChatLog → MsgStruct（对齐 Go SDK LocalChatLogToMsgStruct）
    /// 基础字段映射，自动恢复 typed elem
    pub fn from_local_chat_log(log: &LocalChatLog) -> Self {
        MsgStruct::from(log)
    }
}

/// MsgStruct → MsgData（对齐 Go SDK MsgStructToMsgData）
impl From<&MsgStruct> for MsgData {
    fn from(msg: &MsgStruct) -> Self {
        MsgData {
            send_id: msg.send_id.clone(),
            recv_id: msg.recv_id.clone(),
            group_id: msg.group_id.clone(),
            client_msg_id: msg.client_msg_id.clone(),
            server_msg_id: msg.server_msg_id.clone(),
            sender_platform_id: msg.sender_platform_id,
            sender_nickname: msg.sender_nickname.clone(),
            sender_face_url: msg.sender_face_url.clone(),
            session_type: msg.session_type,
            msg_from: msg.msg_from,
            content_type: msg.content_type,
            content: msg.content.as_bytes().to_vec(),
            seq: msg.seq,
            send_time: msg.send_time,
            create_time: msg.create_time,
            status: msg.status,
            is_read: msg.is_read,
            options: std::collections::HashMap::new(),
            offline_push_info: None,
            at_user_id_list: vec![],
            attached_info: msg.attached_info.clone(),
            ex: msg.ex.clone(),
        }
    }
}

/// MsgData → MsgStruct（对齐 Go SDK MsgDataToMsgStruct）
impl From<&MsgData> for MsgStruct {
    fn from(data: &MsgData) -> Self {
        let mut msg = MsgStruct {
            send_id: data.send_id.clone(),
            recv_id: data.recv_id.clone(),
            group_id: data.group_id.clone(),
            client_msg_id: data.client_msg_id.clone(),
            server_msg_id: data.server_msg_id.clone(),
            sender_platform_id: data.sender_platform_id,
            sender_nickname: data.sender_nickname.clone(),
            sender_face_url: data.sender_face_url.clone(),
            session_type: data.session_type,
            msg_from: data.msg_from,
            content_type: data.content_type,
            content: String::from_utf8_lossy(&data.content).to_string(),
            seq: data.seq,
            send_time: data.send_time,
            create_time: data.create_time,
            status: data.status,
            is_read: data.is_read,
            attached_info: data.attached_info.clone(),
            ex: data.ex.clone(),
            ..Default::default()
        };
        msg.populate_elem_by_content_type();
        msg
    }
}

/// MsgStruct → LocalChatLog（对齐 Go SDK MsgStructToLocalChatLog）
impl From<&MsgStruct> for LocalChatLog {
    fn from(msg: &MsgStruct) -> Self {
        let status = match msg.status {
            0 | 1 | 2 => msg.status,
            3 | 4 | 5 => 3,
            10 => 10,
            _ => 1,
        };
        LocalChatLog {
            conversation_id: String::new(),
            client_msg_id: msg.client_msg_id.clone(),
            server_msg_id: msg.server_msg_id.clone(),
            send_id: msg.send_id.clone(),
            recv_id: msg.recv_id.clone(),
            sender_platform_id: msg.sender_platform_id,
            sender_nick_name: msg.sender_nickname.clone(),
            sender_face_url: msg.sender_face_url.clone(),
            session_type: msg.session_type,
            msg_from: msg.msg_from,
            content_type: msg.content_type,
            content: msg.content.clone(),
            is_read: msg.is_read as i32,
            status,
            seq: msg.seq,
            send_time: msg.send_time,
            create_time: msg.create_time,
            attached_info: msg.attached_info.clone(),
            ex: msg.ex.clone(),
            local_ex: msg.local_ex.clone(),
            group_id: msg.group_id.clone(),
        }
    }
}

/// LocalChatLog → MsgStruct（对齐 Go SDK LocalChatLogToMsgStruct）
impl From<&LocalChatLog> for MsgStruct {
    fn from(log: &LocalChatLog) -> Self {
        let mut msg = MsgStruct {
            client_msg_id: log.client_msg_id.clone(),
            server_msg_id: log.server_msg_id.clone(),
            session_type: log.session_type,
            msg_from: log.msg_from,
            send_id: log.send_id.clone(),
            recv_id: log.recv_id.clone(),
            group_id: log.group_id.clone(),
            content_type: log.content_type,
            content: log.content.clone(),
            send_time: log.send_time,
            create_time: log.create_time,
            seq: log.seq,
            status: log.status,
            is_read: log.is_read != 0,
            attached_info: log.attached_info.clone(),
            ex: log.ex.clone(),
            local_ex: log.local_ex.clone(),
            sender_platform_id: log.sender_platform_id,
            sender_nickname: log.sender_nick_name.clone(),
            sender_face_url: log.sender_face_url.clone(),
            ..Default::default()
        };
        msg.populate_elem_by_content_type();
        msg
    }
}
