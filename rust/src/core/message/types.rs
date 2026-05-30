use crate::domain::constant::types::content_type;

/// 消息类型工具
pub struct MessageTypeUtils;

impl MessageTypeUtils {
    /// 判断是否为文本消息
    pub fn is_text(content_type: i32) -> bool {
        matches!(content_type, 101 | 106 | 113 | 114 | 115 | 117 | 118)
    }

    /// 判断是否为媒体消息
    pub fn is_media(content_type: i32) -> bool {
        !Self::is_text(content_type)
    }

    /// 判断是否为通知消息
    pub fn is_notification(content_type: i32) -> bool {
        content_type >= content_type::NOTIFICATION_BEGIN
            && content_type <= content_type::NOTIFICATION_END
    }
}
