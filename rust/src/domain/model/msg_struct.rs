use serde::{Deserialize, Serialize};
use std::time::{SystemTime, UNIX_EPOCH};

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
}
