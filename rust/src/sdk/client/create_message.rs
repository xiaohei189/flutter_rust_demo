use super::elements::{
    AdvancedTextElem, AtTextElem, FaceElem, MessageEntity, PictureBaseInfo, PictureElem, QuoteElem,
};
use super::types::SendMessageReq;
use super::OpenIMClient;
use crate::domain::constant::enums::{ContentType, SessionType};
use crate::domain::error::types::SdkError;
use openim_protocol::sdkws::MsgData;

impl OpenIMClient {
    pub fn create_text_message(text: &str) -> SendMessageReq {
        let content = serde_json::json!({ "content": text });
        SendMessageReq {
            recv_id: String::new(),
            group_id: String::new(),
            session_type: SessionType::SingleChat,
            content_type: ContentType::Text,
            content: serde_json::to_string(&content).unwrap_or_default(),
            client_msg_id: None,
        }
    }

    pub fn create_image_message_by_url(
        source: PictureBaseInfo,
        big: Option<PictureBaseInfo>,
        snapshot: Option<PictureBaseInfo>,
    ) -> SendMessageReq {
        let elem = PictureElem {
            source_path: String::new(),
            source_picture: Some(source),
            big_picture: big,
            snapshot_picture: snapshot,
        };
        SendMessageReq {
            recv_id: String::new(),
            group_id: String::new(),
            session_type: SessionType::SingleChat,
            content_type: ContentType::Picture,
            content: serde_json::to_string(&elem).unwrap_or_default(),
            client_msg_id: None,
        }
    }

    pub fn create_advanced_text_message(
        text: &str,
        entities: Vec<MessageEntity>,
    ) -> SendMessageReq {
        let elem = AdvancedTextElem {
            text: text.to_string(),
            message_entity_list: entities,
        };
        SendMessageReq {
            recv_id: String::new(),
            group_id: String::new(),
            session_type: SessionType::SingleChat,
            content_type: ContentType::AdvancedText,
            content: serde_json::to_string(&elem).unwrap_or_default(),
            client_msg_id: None,
        }
    }

    pub fn create_quote_message(text: &str, quote_msg: &str) -> SendMessageReq {
        let elem = QuoteElem {
            text: text.to_string(),
            quote_message: quote_msg.to_string(),
        };
        SendMessageReq {
            recv_id: String::new(),
            group_id: String::new(),
            session_type: SessionType::SingleChat,
            content_type: ContentType::Quote,
            content: serde_json::to_string(&elem).unwrap_or_default(),
            client_msg_id: None,
        }
    }

    pub async fn create_and_send_image_message(
        &self,
        file_path: String,
        recv_id: String,
        group_id: String,
        session_type: SessionType,
    ) -> std::result::Result<MsgData, SdkError> {
        let upload_result = self
            .file_uploader
            .upload_image(&file_path)
            .await
            .map_err(|e| SdkError::unknown(format!("upload image failed: {}", e)))?;

        let source = PictureBaseInfo {
            width: 0,
            height: 0,
            type_: String::new(),
            size: upload_result.size as i64,
            url: upload_result.url,
        };

        let elem = PictureElem {
            source_path: file_path,
            source_picture: Some(source),
            big_picture: None,
            snapshot_picture: None,
        };

        let req = SendMessageReq {
            recv_id,
            group_id,
            session_type,
            content_type: ContentType::Picture,
            content: serde_json::to_string(&elem).unwrap_or_default(),
            client_msg_id: None,
        };

        self.send_message(req).await
    }

    pub fn create_at_text_message(text: &str, at_users: Vec<String>) -> SendMessageReq {
        let elem = AtTextElem {
            text: text.to_string(),
            at_user_list: at_users,
            is_at_self: false,
        };
        SendMessageReq {
            recv_id: String::new(),
            group_id: String::new(),
            session_type: SessionType::SingleChat,
            content_type: ContentType::AtText,
            content: serde_json::to_string(&elem).unwrap_or_default(),
            client_msg_id: None,
        }
    }

    pub fn create_face_message(index: i32, data: &str) -> SendMessageReq {
        let elem = FaceElem { index, data: data.to_string() };
        SendMessageReq {
            recv_id: String::new(),
            group_id: String::new(),
            session_type: SessionType::SingleChat,
            content_type: ContentType::Face,
            content: serde_json::to_string(&elem).unwrap_or_default(),
            client_msg_id: None,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_create_text_message() {
        let req = OpenIMClient::create_text_message("hello");
        assert_eq!(req.content_type, ContentType::Text);
        let content: serde_json::Value = serde_json::from_str(&req.content).unwrap();
        assert_eq!(content["content"], "hello");
    }

    #[test]
    fn test_create_image_message_by_url() {
        let source = PictureBaseInfo {
            width: 100,
            height: 200,
            type_: "jpg".to_string(),
            size: 1024,
            url: "https://example.com/image.jpg".to_string(),
        };
        let req = OpenIMClient::create_image_message_by_url(source, None, None);
        assert_eq!(req.content_type, ContentType::Picture);
        let content: serde_json::Value = serde_json::from_str(&req.content).unwrap();
        assert!(content.get("sourcePicture").is_some());
    }

    #[test]
    fn test_create_advanced_text_message() {
        let entity = MessageEntity {
            r#type: "url".to_string(),
            offset: 0,
            length: 5,
            url: "https://example.com".to_string(),
            ex: String::new(),
        };
        let req = OpenIMClient::create_advanced_text_message("hello", vec![entity]);
        assert_eq!(req.content_type, ContentType::AdvancedText);
        let content: serde_json::Value = serde_json::from_str(&req.content).unwrap();
        assert!(content.get("messageEntityList").is_some());
    }

    #[test]
    fn test_create_quote_message() {
        let req = OpenIMClient::create_quote_message("reply text", "original msg");
        assert_eq!(req.content_type, ContentType::Quote);
        let content: serde_json::Value = serde_json::from_str(&req.content).unwrap();
        assert_eq!(content["text"], "reply text");
        assert_eq!(content["quoteMessage"], "original msg");
    }

    #[test]
    fn test_create_at_text_message() {
        let req = OpenIMClient::create_at_text_message("@user hello", vec!["user1".to_string()]);
        assert_eq!(req.content_type, ContentType::AtText);
        let content: serde_json::Value = serde_json::from_str(&req.content).unwrap();
        assert!(content.get("atUserList").is_some());
        assert_eq!(content["atUserList"][0], "user1");
    }

    #[test]
    fn test_create_face_message() {
        let req = OpenIMClient::create_face_message(1, "smile");
        assert_eq!(req.content_type, ContentType::Face);
        let content: serde_json::Value = serde_json::from_str(&req.content).unwrap();
        assert_eq!(content["index"], 1);
        assert_eq!(content["data"], "smile");
    }
}
