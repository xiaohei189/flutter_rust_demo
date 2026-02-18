//! 消息构建：仅组装 content_type + content（JSON），不发送；与 Go CreateTextMessage/CreateImageMessage 等语义对齐。
//! 调用方设置 recv_id/group_id/session_type 后交给 `IMClient::send_message` 发送。

use openim_protocol::constant;
use openim_protocol::sdkws;
use serde::Serialize;

use super::message::{
    CustomElem, FileElem, LocationElem, MsgStruct, PictureBaseInfo, PictureElem, QuoteElem, SoundElem, TextElem,
    VideoElem,
};

fn msg_data_with_content(content_type: i32, content: Vec<u8>) -> sdkws::MsgData {
    let mut msg = sdkws::MsgData::default();
    msg.content_type = content_type;
    msg.content = content;
    msg
}

/// 构建文本消息 MsgData（content_type=TEXT）。发送前需设置 recv_id/group_id、session_type。
pub fn create_text_message(text: &str) -> sdkws::MsgData {
    let elem = TextElem {
        content: text.to_string(),
    };
    let content = serde_json::to_vec(&elem).unwrap_or_default();
    msg_data_with_content(constant::TEXT, content)
}

/// 构建自定义消息 MsgData（content_type=CUSTOM）。
pub fn create_custom_message(data: &str, extension: &str, description: &str) -> sdkws::MsgData {
    let elem = CustomElem {
        data: data.to_string(),
        extension: extension.to_string(),
        description: description.to_string(),
    };
    let content = serde_json::to_vec(&elem).unwrap_or_default();
    msg_data_with_content(constant::CUSTOM, content)
}

/// 构建引用消息 MsgData（content_type=QUOTE）。`quoted_message_json` 为被引用消息的 MsgStruct JSON（可由 `local_chat_log_to_msg_struct` + `serde_json::to_string` 得到）。
pub fn create_quote_message(text: &str, quoted_message_json: &str) -> sdkws::MsgData {
    let quote_message = serde_json::from_str::<MsgStruct>(quoted_message_json)
        .ok()
        .map(Box::new);
    let elem = QuoteElem {
        text: Some(text.to_string()),
        quote_message,
    };
    let content = serde_json::to_vec(&elem).unwrap_or_default();
    msg_data_with_content(constant::QUOTE, content)
}

/// 图片基础信息（仅 URL/尺寸等，不读本地文件）
#[derive(Debug, Clone, Serialize)]
pub struct PictureBaseInfoInput {
    pub uuid: String,
    pub r#type: String,
    pub size: i64,
    pub width: i32,
    pub height: i32,
    pub url: String,
}

/// 按 URL 构建图片消息 MsgData（content_type=PICTURE）。不读本地文件，由上层先上传拿到 URL 再调用。
pub fn create_image_message_by_url(
    source_path: &str,
    source_picture: PictureBaseInfoInput,
    big_picture: PictureBaseInfoInput,
    snapshot_picture: PictureBaseInfoInput,
) -> sdkws::MsgData {
    let to_base = |p: &PictureBaseInfoInput| PictureBaseInfo {
        uuid: p.uuid.clone(),
        r#type: p.r#type.clone(),
        size: p.size,
        width: p.width,
        height: p.height,
        url: p.url.clone(),
    };
    let elem = PictureElem {
        source_path: source_path.to_string(),
        source_picture: to_base(&source_picture),
        big_picture: to_base(&big_picture),
        snapshot_picture: to_base(&snapshot_picture),
    };
    let content = serde_json::to_vec(&elem).unwrap_or_default();
    msg_data_with_content(constant::PICTURE, content)
}

/// 简化：单张图 URL + 宽高，生成 source/big/snapshot 三份相同 PictureBaseInfo（便于仅 URL 场景）。
pub fn create_image_message_simple(url: &str, width: i32, height: i32) -> sdkws::MsgData {
    let base = PictureBaseInfoInput {
        uuid: String::new(),
        r#type: String::new(),
        size: 0,
        width,
        height,
        url: url.to_string(),
    };
    create_image_message_by_url("", base.clone(), base.clone(), base)
}

/// 构建视频消息 MsgData（content_type=VIDEO）。仅组 VideoElem JSON，不读文件；由上层上传后传入 URL。
pub fn create_video_message(
    video_path: &str,
    video_uuid: &str,
    video_url: &str,
    video_type: &str,
    video_size: i64,
    duration: i64,
    snapshot_path: &str,
    snapshot_uuid: &str,
    snapshot_size: i64,
    snapshot_url: &str,
    snapshot_width: i32,
    snapshot_height: i32,
) -> sdkws::MsgData {
    let elem = VideoElem {
        video_path: video_path.to_string(),
        video_uuid: video_uuid.to_string(),
        video_url: video_url.to_string(),
        video_type: video_type.to_string(),
        video_size,
        duration,
        snapshot_path: snapshot_path.to_string(),
        snapshot_uuid: snapshot_uuid.to_string(),
        snapshot_size,
        snapshot_url: snapshot_url.to_string(),
        snapshot_width,
        snapshot_height,
    };
    let content = serde_json::to_vec(&elem).unwrap_or_default();
    msg_data_with_content(constant::VIDEO, content)
}

/// 构建语音消息 MsgData（content_type=VOICE）。
pub fn create_sound_message(
    uuid: &str,
    sound_path: &str,
    source_url: &str,
    data_size: i64,
    duration: i64,
) -> sdkws::MsgData {
    let elem = SoundElem {
        uuid: uuid.to_string(),
        sound_path: sound_path.to_string(),
        source_url: source_url.to_string(),
        data_size,
        duration,
    };
    let content = serde_json::to_vec(&elem).unwrap_or_default();
    msg_data_with_content(constant::VOICE, content)
}

/// 构建文件消息 MsgData（content_type=FILE）。
pub fn create_file_message(file_path: &str, uuid: &str, source_url: &str, file_name: &str, file_size: i64) -> sdkws::MsgData {
    let elem = FileElem {
        file_path: file_path.to_string(),
        uuid: uuid.to_string(),
        source_url: source_url.to_string(),
        file_name: file_name.to_string(),
        file_size,
    };
    let content = serde_json::to_vec(&elem).unwrap_or_default();
    msg_data_with_content(constant::FILE, content)
}

/// 构建位置消息 MsgData（content_type=LOCATION）。
pub fn create_location_message(description: &str, longitude: f64, latitude: f64) -> sdkws::MsgData {
    let elem = LocationElem {
        description: description.to_string(),
        longitude,
        latitude,
    };
    let content = serde_json::to_vec(&elem).unwrap_or_default();
    msg_data_with_content(constant::LOCATION, content)
}
