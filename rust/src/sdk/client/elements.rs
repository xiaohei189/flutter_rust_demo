use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct PictureBaseInfo {
    pub width: i32,
    pub height: i32,
    #[serde(rename = "type")]
    pub type_: String,
    pub size: i64,
    pub url: String,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct PictureElem {
    #[serde(rename = "sourcePath")]
    pub source_path: String,
    #[serde(rename = "sourcePicture")]
    pub source_picture: Option<PictureBaseInfo>,
    #[serde(rename = "bigPicture")]
    pub big_picture: Option<PictureBaseInfo>,
    #[serde(rename = "snapshotPicture")]
    pub snapshot_picture: Option<PictureBaseInfo>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct SoundElem {
    pub uuid: String,
    #[serde(rename = "sourceUrl")]
    pub source_url: String,
    #[serde(rename = "dataSize")]
    pub data_size: i64,
    pub duration: i64,
    #[serde(rename = "soundType")]
    pub sound_type: String,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct VideoElem {
    #[serde(rename = "videoUrl")]
    pub video_url: String,
    #[serde(rename = "videoType")]
    pub video_type: String,
    #[serde(rename = "videoSize")]
    pub video_size: i64,
    pub duration: i64,
    #[serde(rename = "snapshotUrl")]
    pub snapshot_url: String,
    #[serde(rename = "snapshotWidth")]
    pub snapshot_width: i32,
    #[serde(rename = "snapshotHeight")]
    pub snapshot_height: i32,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct FileElem {
    #[serde(rename = "sourceUrl")]
    pub source_url: String,
    #[serde(rename = "fileName")]
    pub file_name: String,
    #[serde(rename = "fileSize")]
    pub file_size: i64,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct AtTextElem {
    pub text: String,
    #[serde(rename = "atUserList")]
    pub at_user_list: Vec<String>,
    #[serde(rename = "isAtSelf")]
    pub is_at_self: bool,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct MergeElem {
    pub title: String,
    #[serde(rename = "abstractList")]
    pub abstract_list: Vec<String>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct CardElem {
    #[serde(rename = "userID")]
    pub user_id: String,
    pub nickname: String,
    #[serde(rename = "faceURL")]
    pub face_url: String,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct LocationElem {
    pub description: String,
    pub longitude: f64,
    pub latitude: f64,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct CustomElem {
    pub data: String,
    pub extension: String,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct QuoteElem {
    pub text: String,
    #[serde(rename = "quoteMessage")]
    pub quote_message: String,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct FaceElem {
    pub index: i32,
    pub data: String,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct MessageEntity {
    pub r#type: String,
    pub offset: i32,
    pub length: i32,
    pub url: String,
    pub ex: String,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct AdvancedTextElem {
    pub text: String,
    #[serde(rename = "messageEntityList")]
    pub message_entity_list: Vec<MessageEntity>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct MarkdownTextElem {
    pub text: String,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_picture_base_info() {
        let orig = PictureBaseInfo {
            width: 1920,
            height: 1080,
            type_: String::from("jpg"),
            size: 1024000,
            url: String::from("https://example.com/pic.jpg"),
        };
        let json = serde_json::to_string(&orig).unwrap();
        let decoded: PictureBaseInfo = serde_json::from_str(&json).unwrap();
        assert_eq!(decoded.width, 1920);
        assert_eq!(decoded.height, 1080);
        assert_eq!(decoded.type_, "jpg");
        assert_eq!(decoded.size, 1024000);
        assert_eq!(decoded.url, "https://example.com/pic.jpg");
    }

    #[test]
    fn test_picture_elem() {
        let orig = PictureElem {
            source_path: String::from("/tmp/photo.jpg"),
            source_picture: Some(PictureBaseInfo {
                width: 640,
                height: 480,
                type_: String::from("png"),
                size: 256000,
                url: String::from("https://example.com/source.png"),
            }),
            big_picture: None,
            snapshot_picture: None,
        };
        let json = serde_json::to_string(&orig).unwrap();
        let decoded: PictureElem = serde_json::from_str(&json).unwrap();
        assert_eq!(decoded.source_path, "/tmp/photo.jpg");
        assert!(decoded.source_picture.is_some());
        assert_eq!(decoded.source_picture.as_ref().unwrap().width, 640);
        assert_eq!(decoded.source_picture.as_ref().unwrap().height, 480);
        assert!(decoded.big_picture.is_none());
        assert!(decoded.snapshot_picture.is_none());
    }

    #[test]
    fn test_sound_elem() {
        let orig = SoundElem {
            uuid: String::from("a1b2c3d4"),
            source_url: String::from("https://example.com/audio.mp3"),
            data_size: 512000,
            duration: 30000,
            sound_type: String::from("mp3"),
        };
        let json = serde_json::to_string(&orig).unwrap();
        let decoded: SoundElem = serde_json::from_str(&json).unwrap();
        assert_eq!(decoded.uuid, "a1b2c3d4");
        assert_eq!(decoded.source_url, "https://example.com/audio.mp3");
        assert_eq!(decoded.data_size, 512000);
        assert_eq!(decoded.duration, 30000);
        assert_eq!(decoded.sound_type, "mp3");
    }

    #[test]
    fn test_video_elem() {
        let orig = VideoElem {
            video_url: String::from("https://example.com/video.mp4"),
            video_type: String::from("mp4"),
            video_size: 10485760,
            duration: 120000,
            snapshot_url: String::from("https://example.com/snapshot.jpg"),
            snapshot_width: 1920,
            snapshot_height: 1080,
        };
        let json = serde_json::to_string(&orig).unwrap();
        let decoded: VideoElem = serde_json::from_str(&json).unwrap();
        assert_eq!(decoded.video_url, "https://example.com/video.mp4");
        assert_eq!(decoded.video_type, "mp4");
        assert_eq!(decoded.video_size, 10485760);
        assert_eq!(decoded.duration, 120000);
        assert_eq!(decoded.snapshot_url, "https://example.com/snapshot.jpg");
        assert_eq!(decoded.snapshot_width, 1920);
        assert_eq!(decoded.snapshot_height, 1080);
    }

    #[test]
    fn test_file_elem() {
        let orig = FileElem {
            source_url: String::from("https://example.com/file.pdf"),
            file_name: String::from("document.pdf"),
            file_size: 2097152,
        };
        let json = serde_json::to_string(&orig).unwrap();
        let decoded: FileElem = serde_json::from_str(&json).unwrap();
        assert_eq!(decoded.source_url, "https://example.com/file.pdf");
        assert_eq!(decoded.file_name, "document.pdf");
        assert_eq!(decoded.file_size, 2097152);
    }

    #[test]
    fn test_at_text_elem() {
        let orig = AtTextElem {
            text: String::from("@Alice @Bob hello"),
            at_user_list: vec![
                String::from("user_001"),
                String::from("user_002"),
            ],
            is_at_self: true,
        };
        let json = serde_json::to_string(&orig).unwrap();
        let decoded: AtTextElem = serde_json::from_str(&json).unwrap();
        assert_eq!(decoded.text, "@Alice @Bob hello");
        assert_eq!(decoded.at_user_list, vec!["user_001", "user_002"]);
        assert!(decoded.is_at_self);
    }

    #[test]
    fn test_merge_elem() {
        let orig = MergeElem {
            title: String::from("Chat History"),
            abstract_list: vec![
                String::from("Alice: Hello"),
                String::from("Bob: Hi"),
            ],
        };
        let json = serde_json::to_string(&orig).unwrap();
        let decoded: MergeElem = serde_json::from_str(&json).unwrap();
        assert_eq!(decoded.title, "Chat History");
        assert_eq!(decoded.abstract_list, vec!["Alice: Hello", "Bob: Hi"]);
    }

    #[test]
    fn test_card_elem() {
        let orig = CardElem {
            user_id: String::from("user_123"),
            nickname: String::from("Alice"),
            face_url: String::from("https://example.com/avatar.png"),
        };
        let json = serde_json::to_string(&orig).unwrap();
        let decoded: CardElem = serde_json::from_str(&json).unwrap();
        assert_eq!(decoded.user_id, "user_123");
        assert_eq!(decoded.nickname, "Alice");
        assert_eq!(decoded.face_url, "https://example.com/avatar.png");
    }

    #[test]
    fn test_location_elem() {
        let orig = LocationElem {
            description: String::from("Beijing"),
            longitude: 116.4074,
            latitude: 39.9042,
        };
        let json = serde_json::to_string(&orig).unwrap();
        let decoded: LocationElem = serde_json::from_str(&json).unwrap();
        assert_eq!(decoded.description, "Beijing");
        assert!((decoded.longitude - 116.4074).abs() < 1e-10);
        assert!((decoded.latitude - 39.9042).abs() < 1e-10);
    }

    #[test]
    fn test_custom_elem() {
        let orig = CustomElem {
            data: String::from("{\"key\":\"value\"}"),
            extension: String::from("custom_ext"),
        };
        let json = serde_json::to_string(&orig).unwrap();
        let decoded: CustomElem = serde_json::from_str(&json).unwrap();
        assert_eq!(decoded.data, "{\"key\":\"value\"}");
        assert_eq!(decoded.extension, "custom_ext");
    }

    #[test]
    fn test_quote_elem() {
        let orig = QuoteElem {
            text: String::from("Original message"),
            quote_message: String::from("{\"content\":\"hello\"}"),
        };
        let json = serde_json::to_string(&orig).unwrap();
        let decoded: QuoteElem = serde_json::from_str(&json).unwrap();
        assert_eq!(decoded.text, "Original message");
        assert_eq!(decoded.quote_message, "{\"content\":\"hello\"}");
    }

    #[test]
    fn test_face_elem() {
        let orig = FaceElem {
            index: 1,
            data: String::from("[微笑]"),
        };
        let json = serde_json::to_string(&orig).unwrap();
        let decoded: FaceElem = serde_json::from_str(&json).unwrap();
        assert_eq!(decoded.index, 1);
        assert_eq!(decoded.data, "[微笑]");
    }

    #[test]
    fn test_message_entity() {
        let orig = MessageEntity {
            r#type: String::from("url"),
            offset: 0,
            length: 10,
            url: String::from("https://example.com"),
            ex: String::from("{}"),
        };
        let json = serde_json::to_string(&orig).unwrap();
        let decoded: MessageEntity = serde_json::from_str(&json).unwrap();
        assert_eq!(decoded.r#type, "url");
        assert_eq!(decoded.offset, 0);
        assert_eq!(decoded.length, 10);
        assert_eq!(decoded.url, "https://example.com");
        assert_eq!(decoded.ex, "{}");
    }

    #[test]
    fn test_advanced_text_elem() {
        let orig = AdvancedTextElem {
            text: String::from("Hello, click https://example.com"),
            message_entity_list: vec![
                MessageEntity {
                    r#type: String::from("url"),
                    offset: 13,
                    length: 19,
                    url: String::from("https://example.com"),
                    ex: String::from("{}"),
                },
            ],
        };
        let json = serde_json::to_string(&orig).unwrap();
        let decoded: AdvancedTextElem = serde_json::from_str(&json).unwrap();
        assert_eq!(decoded.text, "Hello, click https://example.com");
        assert_eq!(decoded.message_entity_list.len(), 1);
        assert_eq!(decoded.message_entity_list[0].r#type, "url");
        assert_eq!(decoded.message_entity_list[0].offset, 13);
        assert_eq!(decoded.message_entity_list[0].length, 19);
    }

    #[test]
    fn test_markdown_text_elem() {
        let orig = MarkdownTextElem {
            text: String::from("# Hello\nThis is **bold** text."),
        };
        let json = serde_json::to_string(&orig).unwrap();
        let decoded: MarkdownTextElem = serde_json::from_str(&json).unwrap();
        assert_eq!(decoded.text, "# Hello\nThis is **bold** text.");
    }
}
