use crate::domain::constant::types::content_type;

/// 消息内容类型统一工具 — 项目中唯一的 content_type 分类/命名中心
///
/// 所有对 content_type 的命名、分类、判断都应通过此结构体，
/// 避免在各模块中重复定义映射关系。
pub struct ContentTypeUtils;

impl ContentTypeUtils {
    /// 媒体消息类型常量（图片/语音/视频/文件）
    pub const MEDIA_TYPES: [i32; 4] = [102, 103, 104, 105];

    // ========================================================================
    // 命名
    // ========================================================================

    /// 英文可读名称（用于 debug 日志）
    pub fn display_name(ct: i32) -> &'static str {
        match ct {
            101 => "Text", 102 => "Picture", 103 => "Sound", 104 => "Video",
            105 => "File", 106 => "AtText", 107 => "Merger", 108 => "Card",
            109 => "Location", 110 => "Custom", 113 => "Typing", 114 => "Quote",
            115 => "Face", 117 => "AdvancedText", 118 => "MarkdownText",
            119 => "CustomNotTrigger", 120 => "CustomOnlineOnly",
            121 => "ReactionModifier", 122 => "ReactionDeleter",
            1000..=5000 => "Notification",
            _ => "Unknown",
        }
    }

    /// 中文可读名称（用于用户可见的日志/描述）
    pub fn display_name_zh(ct: i32) -> &'static str {
        match ct {
            101 => "文本",
            102 => "图片",
            103 => "语音",
            104 => "视频",
            105 => "文件",
            106 => "@消息",
            107 => "合并转发",
            108 => "名片",
            109 => "位置",
            110 => "自定义",
            113 => "正在输入",
            114 => "引用",
            115 => "表情",
            117 => "富文本",
            118 => "Markdown",
            119 => "自定义(不触发会话)",
            120 => "自定义(仅在线)",
            121 => "消息回应",
            122 => "删除回应",
            2101 => "撤回",
            2102 => "删除消息",
            2200 => "已读回执",
            1000..=5000 => "通知",
            _ => "未知",
        }
    }

    // ========================================================================
    // 分类谓词
    // ========================================================================

    /// 判断是否为文本类消息
    pub fn is_text(ct: i32) -> bool {
        matches!(ct, 101 | 106 | 113 | 114 | 115 | 117 | 118)
    }

    /// 判断是否为媒体消息（图片/语音/视频/文件）
    pub fn is_media(ct: i32) -> bool {
        Self::MEDIA_TYPES.contains(&ct)
    }

    /// 判断是否为通知消息（1000-5000 范围）
    pub fn is_notification(ct: i32) -> bool {
        ct >= content_type::NOTIFICATION_BEGIN && ct <= content_type::NOTIFICATION_END
    }

    /// 判断是否为 tip 消息（等同通知范围，对齐 Go SDK isTipMessage）
    pub fn is_tip(ct: i32) -> bool {
        Self::is_notification(ct)
    }

    /// 判断消息是否应存储到本地数据库
    ///
    /// 排除：通知(tip)、正在输入、仅在线消息
    pub fn should_store(ct: i32) -> bool {
        !Self::is_tip(ct)
            && ct != content_type::TYPING
            && ct != content_type::CUSTOM_MSG_ONLINE_ONLY
    }

    /// 判断消息是否应触发会话更新（latestMsg / unreadCount）
    ///
    /// 排除：不触发会话的自定义消息
    pub fn should_update_conversation(ct: i32) -> bool {
        Self::should_store(ct)
            && ct != content_type::CUSTOM_MSG_NOT_TRIGGER_CONVERSATION
    }
}

/// 向后兼容别名（逐步迁移后可删除）
pub type MessageTypeUtils = ContentTypeUtils;

#[cfg(test)]
mod tests {
    use super::*;

    // ========================================================================
    // display_name 测试
    // ========================================================================

    #[test]
    fn test_display_name_known_types() {
        assert_eq!(ContentTypeUtils::display_name(101), "Text");
        assert_eq!(ContentTypeUtils::display_name(102), "Picture");
        assert_eq!(ContentTypeUtils::display_name(103), "Sound");
        assert_eq!(ContentTypeUtils::display_name(104), "Video");
        assert_eq!(ContentTypeUtils::display_name(105), "File");
        assert_eq!(ContentTypeUtils::display_name(106), "AtText");
        assert_eq!(ContentTypeUtils::display_name(113), "Typing");
        assert_eq!(ContentTypeUtils::display_name(114), "Quote");
        assert_eq!(ContentTypeUtils::display_name(119), "CustomNotTrigger");
        assert_eq!(ContentTypeUtils::display_name(120), "CustomOnlineOnly");
    }

    #[test]
    fn test_display_name_unknown() {
        assert_eq!(ContentTypeUtils::display_name(0), "Unknown");
        assert_eq!(ContentTypeUtils::display_name(999), "Unknown");
        assert_eq!(ContentTypeUtils::display_name(-1), "Unknown");
    }

    #[test]
    fn test_display_name_zh() {
        assert_eq!(ContentTypeUtils::display_name_zh(101), "文本");
        assert_eq!(ContentTypeUtils::display_name_zh(102), "图片");
        assert_eq!(ContentTypeUtils::display_name_zh(2101), "撤回");
        assert_eq!(ContentTypeUtils::display_name_zh(2200), "已读回执");
        assert_eq!(ContentTypeUtils::display_name_zh(9999), "未知");
    }

    // ========================================================================
    // is_text 测试
    // ========================================================================

    #[test]
    fn test_is_text_true() {
        assert!(ContentTypeUtils::is_text(101)); // TEXT
        assert!(ContentTypeUtils::is_text(106)); // AT_TEXT
        assert!(ContentTypeUtils::is_text(113)); // TYPING
        assert!(ContentTypeUtils::is_text(114)); // QUOTE
        assert!(ContentTypeUtils::is_text(115)); // FACE
        assert!(ContentTypeUtils::is_text(117)); // ADVANCED_TEXT
        assert!(ContentTypeUtils::is_text(118)); // MARKDOWN_TEXT
    }

    #[test]
    fn test_is_text_false() {
        assert!(!ContentTypeUtils::is_text(102)); // PICTURE
        assert!(!ContentTypeUtils::is_text(103)); // SOUND
        assert!(!ContentTypeUtils::is_text(104)); // VIDEO
        assert!(!ContentTypeUtils::is_text(105)); // FILE
        assert!(!ContentTypeUtils::is_text(107)); // MERGER
        assert!(!ContentTypeUtils::is_text(110)); // CUSTOM
        assert!(!ContentTypeUtils::is_text(119)); // CUSTOM_NOT_TRIGGER
        assert!(!ContentTypeUtils::is_text(120)); // CUSTOM_ONLINE_ONLY
        assert!(!ContentTypeUtils::is_text(0));
        assert!(!ContentTypeUtils::is_text(-1));
    }

    // ========================================================================
    // is_media 测试
    // ========================================================================

    #[test]
    fn test_is_media() {
        assert!(ContentTypeUtils::is_media(102)); // PICTURE
        assert!(ContentTypeUtils::is_media(103)); // SOUND
        assert!(ContentTypeUtils::is_media(104)); // VIDEO
        assert!(ContentTypeUtils::is_media(105)); // FILE
        assert!(!ContentTypeUtils::is_media(101)); // TEXT
        assert!(!ContentTypeUtils::is_media(106)); // AT_TEXT
        assert!(!ContentTypeUtils::is_media(0));
    }

    // ========================================================================
    // is_notification / is_tip 测试
    // ========================================================================

    #[test]
    fn test_is_notification_boundaries() {
        assert!(!ContentTypeUtils::is_notification(999));
        assert!(ContentTypeUtils::is_notification(1000)); // NOTIFICATION_BEGIN
        assert!(ContentTypeUtils::is_notification(1203)); // FRIEND_APPLICATION
        assert!(ContentTypeUtils::is_notification(2101)); // REVOKE
        assert!(ContentTypeUtils::is_notification(2200)); // HAS_READ_RECEIPT
        assert!(ContentTypeUtils::is_notification(5000)); // NOTIFICATION_END
        assert!(!ContentTypeUtils::is_notification(5001));
    }

    #[test]
    fn test_is_tip_equals_notification() {
        for ct in [999, 1000, 1203, 2101, 5000, 5001, 101] {
            assert_eq!(ContentTypeUtils::is_tip(ct), ContentTypeUtils::is_notification(ct));
        }
    }

    // ========================================================================
    // should_store / should_update_conversation 测试
    // ========================================================================

    #[test]
    fn test_should_store() {
        // 普通消息应存储
        assert!(ContentTypeUtils::should_store(101)); // TEXT
        assert!(ContentTypeUtils::should_store(102)); // PICTURE
        assert!(ContentTypeUtils::should_store(114)); // QUOTE
        assert!(ContentTypeUtils::should_store(119)); // CUSTOM_NOT_TRIGGER
        // 通知不存储
        assert!(!ContentTypeUtils::should_store(1000));
        assert!(!ContentTypeUtils::should_store(2101));
        // TYPING 不存储
        assert!(!ContentTypeUtils::should_store(113));
        // ONLINE_ONLY 不存储
        assert!(!ContentTypeUtils::should_store(120));
    }

    #[test]
    fn test_should_update_conversation() {
        assert!(ContentTypeUtils::should_update_conversation(101)); // TEXT
        assert!(ContentTypeUtils::should_update_conversation(102)); // PICTURE
        // NOT_TRIGGER_CONVERSATION 不更新会话
        assert!(!ContentTypeUtils::should_update_conversation(119));
        // TYPING 不更新
        assert!(!ContentTypeUtils::should_update_conversation(113));
        // ONLINE_ONLY 不更新
        assert!(!ContentTypeUtils::should_update_conversation(120));
        // 通知不更新
        assert!(!ContentTypeUtils::should_update_conversation(1203));
    }
}

