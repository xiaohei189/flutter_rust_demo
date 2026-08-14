//! 消息构造器 FFI —— 对齐 Go SDK `Create*Message` 系列
//!
//! Go SDK 的消息发送是两步式：先 Create*Message 构造 MsgStruct，再 SendMessage 发送。
//! 本模块把模型层 `MsgStruct::create_*`（rust/src/model/msg_struct.rs）暴露给 Dart，
//! 支持转发、草稿、多选转发等"构造后暂存、二次确认再发"的场景。
//!
//! FromFullPath 变体对齐 Go SDK create_message.go：
//! - 图片：SDK 读本地文件宽高（Go getImageInfo）
//! - 语音/文件：SDK 读文件大小（os.Stat），duration 由调用方传入
//! - 视频：duration/videoType 由调用方传入

use crate::model::msg_struct::{AtInfo, CardElem, FileElem, MessageEntity, MsgStruct, PictureBaseInfo, SoundElem, VideoElem};
use anyhow::{anyhow, Result};
use std::fs;
use std::path::Path;

// ============================================================================
// 文本类
// ============================================================================

/// 构造文本消息（contentType=101，对齐 Go SDK `CreateTextMessage`）
#[flutter_rust_bridge::frb]
pub fn create_text_message(text: String) -> MsgStruct {
    MsgStruct::create_text_message(&text)
}

/// 构造 @ 消息（contentType=106，对齐 Go SDK `CreateTextAtMessage`）
#[flutter_rust_bridge::frb]
pub fn create_at_text_message(text: String, at_user_list: Vec<String>, at_users_info: Vec<AtInfo>, quote_msg: Option<Box<MsgStruct>>) -> MsgStruct {
    MsgStruct::create_at_text_message(&text, at_user_list, at_users_info, quote_msg)
}

/// 构造富文本消息（contentType=111，对齐 Go SDK `CreateAdvancedTextMessage`）
#[flutter_rust_bridge::frb]
pub fn create_advanced_text_message(text: String, message_entity_list: Vec<MessageEntity>) -> MsgStruct {
    MsgStruct::create_advanced_text_message(&text, message_entity_list)
}

/// 构造 Markdown 消息（contentType=112，对齐 Go SDK `CreateMarkdownMessage`）
#[flutter_rust_bridge::frb]
pub fn create_markdown_message(text: String) -> MsgStruct {
    MsgStruct::create_markdown_message(&text)
}

// ============================================================================
// 图片
// ============================================================================

/// 构造图片消息（contentType=102，对齐 Go SDK `CreateImageMessage`）
#[flutter_rust_bridge::frb]
pub fn create_image_message(source_path: String, source_picture: PictureBaseInfo, big_picture: PictureBaseInfo, snapshot_picture: PictureBaseInfo) -> MsgStruct {
    MsgStruct::create_image_message(&source_path, source_picture, big_picture, snapshot_picture)
}

/// 按 URL 构造图片消息（对齐 Go SDK `CreateImageMessageByURL`）
///
/// 内容已上传完成，sourcePicture/bigPicture/snapshotPicture 由调用方提供，
/// 发送时不再走 OSS 上传。
#[flutter_rust_bridge::frb]
pub fn create_image_message_by_url(source_path: String, source_picture: PictureBaseInfo, big_picture: PictureBaseInfo, snapshot_picture: PictureBaseInfo) -> MsgStruct {
    MsgStruct::create_image_message(&source_path, source_picture, big_picture, snapshot_picture)
}

/// 从本地完整路径构造图片消息（对齐 Go SDK `CreateImageMessageFromFullPath`）
///
/// SDK 读取图片宽高与文件大小，类型取文件扩展名。
#[flutter_rust_bridge::frb]
pub fn create_image_message_from_full_path(image_full_path: String) -> Result<MsgStruct> {
    let path = Path::new(&image_full_path);
    if !path.exists() {
        return Err(anyhow!("图片文件不存在: {}", image_full_path));
    }

    let (width, height) = image::image_dimensions(path).map_err(|e| anyhow!("读取图片尺寸失败: {}", e))?;
    let size = fs::metadata(path).map_err(|e| anyhow!("读取图片文件信息失败: {}", e))?.len() as i64;
    let picture_type = path.extension().and_then(|e| e.to_str()).map(|s| s.to_string()).unwrap_or_default();

    Ok(MsgStruct::create_image_message(
        &image_full_path,
        PictureBaseInfo {
            width: width as i32,
            height: height as i32,
            picture_type: picture_type.clone(),
            size,
            url: String::new(),
            uuid: String::new(),
        },
        PictureBaseInfo {
            width: width as i32,
            height: height as i32,
            picture_type: picture_type.clone(),
            size,
            url: String::new(),
            uuid: String::new(),
        },
        PictureBaseInfo {
            width: width as i32,
            height: height as i32,
            picture_type,
            size,
            url: String::new(),
            uuid: String::new(),
        },
    ))
}

// ============================================================================
// 语音
// ============================================================================

/// 构造语音消息（contentType=103，对齐 Go SDK `CreateSoundMessage`）
#[flutter_rust_bridge::frb]
pub fn create_sound_message(elem: SoundElem) -> MsgStruct {
    MsgStruct::create_sound_message(elem)
}

/// 按 URL 构造语音消息（对齐 Go SDK `CreateSoundMessageByURL`）
#[flutter_rust_bridge::frb]
pub fn create_sound_message_by_url(elem: SoundElem) -> MsgStruct {
    MsgStruct::create_sound_message(elem)
}

/// 从本地完整路径构造语音消息（对齐 Go SDK `CreateSoundMessageFromFullPath`）
///
/// SDK 读取文件大小，类型取扩展名；duration 由调用方传入。
#[flutter_rust_bridge::frb]
pub fn create_sound_message_from_full_path(sound_path: String, duration: i64) -> Result<MsgStruct> {
    let path = Path::new(&sound_path);
    if !path.exists() {
        return Err(anyhow!("语音文件不存在: {}", sound_path));
    }
    let size = fs::metadata(path).map_err(|e| anyhow!("读取语音文件信息失败: {}", e))?.len() as i64;
    let sound_type = path.extension().and_then(|e| e.to_str()).map(|s| s.to_string()).unwrap_or_default();

    Ok(MsgStruct::create_sound_message(SoundElem {
        uuid: String::new(),
        sound_path,
        source_url: String::new(),
        data_size: size,
        duration,
        sound_type,
    }))
}

// ============================================================================
// 视频
// ============================================================================

/// 构造视频消息（contentType=104，对齐 Go SDK `CreateVideoMessage`）
#[flutter_rust_bridge::frb]
pub fn create_video_message(elem: VideoElem) -> MsgStruct {
    MsgStruct::create_video_message(elem)
}

/// 按 URL 构造视频消息（对齐 Go SDK `CreateVideoMessageByURL`）
#[flutter_rust_bridge::frb]
pub fn create_video_message_by_url(elem: VideoElem) -> MsgStruct {
    MsgStruct::create_video_message(elem)
}

/// 从本地完整路径构造视频消息（对齐 Go SDK `CreateVideoMessageFromFullPath`）
///
/// duration/videoType 由调用方传入，快照路径一并记录。
#[flutter_rust_bridge::frb]
pub fn create_video_message_from_full_path(video_full_path: String, video_type: String, duration: i64, snapshot_full_path: String) -> Result<MsgStruct> {
    let video_path = Path::new(&video_full_path);
    if !video_path.exists() {
        return Err(anyhow!("视频文件不存在: {}", video_full_path));
    }
    let video_size = fs::metadata(video_path).map_err(|e| anyhow!("读取视频文件信息失败: {}", e))?.len() as i64;
    let snapshot_size = if Path::new(&snapshot_full_path).exists() {
        fs::metadata(&snapshot_full_path).map(|m| m.len() as i64).unwrap_or(0)
    } else {
        0
    };

    Ok(MsgStruct::create_video_message(VideoElem {
        video_path: video_full_path,
        video_uuid: String::new(),
        video_url: String::new(),
        video_type,
        video_size,
        duration,
        snapshot_path: snapshot_full_path,
        snapshot_uuid: String::new(),
        snapshot_size,
        snapshot_url: String::new(),
        snapshot_width: 0,
        snapshot_height: 0,
        snapshot_type: String::new(),
    }))
}

// ============================================================================
// 文件
// ============================================================================

/// 构造文件消息（contentType=105，对齐 Go SDK `CreateFileMessage`）
#[flutter_rust_bridge::frb]
pub fn create_file_message(elem: FileElem) -> MsgStruct {
    MsgStruct::create_file_message(elem)
}

/// 按 URL 构造文件消息（对齐 Go SDK `CreateFileMessageByURL`）
#[flutter_rust_bridge::frb]
pub fn create_file_message_by_url(elem: FileElem) -> MsgStruct {
    MsgStruct::create_file_message(elem)
}

/// 从本地完整路径构造文件消息（对齐 Go SDK `CreateFileMessageFromFullPath`）
///
/// SDK 读取文件大小。
#[flutter_rust_bridge::frb]
pub fn create_file_message_from_full_path(file_full_path: String, file_name: String) -> Result<MsgStruct> {
    let path = Path::new(&file_full_path);
    if !path.exists() {
        return Err(anyhow!("文件不存在: {}", file_full_path));
    }
    let size = fs::metadata(path).map_err(|e| anyhow!("读取文件信息失败: {}", e))?.len() as i64;

    Ok(MsgStruct::create_file_message(FileElem {
        file_path: file_full_path,
        uuid: String::new(),
        source_url: String::new(),
        file_name,
        file_size: size,
        file_type: String::new(),
    }))
}

// ============================================================================
// 引用 / 合并转发 / 名片 / 位置 / 自定义 / 表情
// ============================================================================

/// 构造引用消息（contentType=114，对齐 Go SDK `CreateQuoteMessage`）
#[flutter_rust_bridge::frb]
pub fn create_quote_message(text: String, quoted_msg: MsgStruct) -> MsgStruct {
    MsgStruct::create_quote_message(&text, Box::new(quoted_msg))
}

/// 构造高级引用消息（对齐 Go SDK `CreateAdvancedQuoteMessage`）
#[flutter_rust_bridge::frb]
pub fn create_advanced_quote_message(text: String, quoted_msg: MsgStruct, message_entity_list: Vec<MessageEntity>) -> MsgStruct {
    MsgStruct::create_advanced_quote_message(&text, Box::new(quoted_msg), message_entity_list)
}

/// 构造合并转发消息（contentType=107，对齐 Go SDK `CreateMergerMessage`）
#[flutter_rust_bridge::frb]
pub fn create_merger_message(messages: Vec<MsgStruct>, title: String, summaries: Vec<String>) -> MsgStruct {
    MsgStruct::create_merger_message(messages, &title, summaries)
}

/// 构造名片消息（contentType=108，对齐 Go SDK `CreateCardMessage`）
#[flutter_rust_bridge::frb]
pub fn create_card_message(elem: CardElem) -> MsgStruct {
    MsgStruct::create_card_message(elem)
}

/// 构造位置消息（contentType=109，对齐 Go SDK `CreateLocationMessage`）
#[flutter_rust_bridge::frb]
pub fn create_location_message(description: String, longitude: f64, latitude: f64) -> MsgStruct {
    MsgStruct::create_location_message(&description, longitude, latitude)
}

/// 构造自定义消息（contentType=110，对齐 Go SDK `CreateCustomMessage`）
#[flutter_rust_bridge::frb]
pub fn create_custom_message(data: String, extension: String, description: String) -> MsgStruct {
    MsgStruct::create_custom_message(&data, &extension, &description)
}

/// 构造表情消息（contentType=115，对齐 Go SDK `CreateFaceMessage`）
#[flutter_rust_bridge::frb]
pub fn create_face_message(index: i32, data: String) -> MsgStruct {
    MsgStruct::create_face_message(index, &data)
}

// ============================================================================
// 工具
// ============================================================================

/// 获取 @所有人 标签（对齐 Go SDK `GetAtAllTag`，返回常量 "@All"）
#[flutter_rust_bridge::frb]
pub fn get_at_all_tag() -> String {
    crate::constant::AT_ALL_TAG.to_string()
}
