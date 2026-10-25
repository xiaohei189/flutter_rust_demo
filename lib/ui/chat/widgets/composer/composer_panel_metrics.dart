/// 输入区各面板的「设计高度」。
///
/// 输入区按这些高度给面板占位，实际高度由外层 `Flexible` 收敛到可用空间；
/// 面板自身必须能在更小的高度下自适应（语音面板就曾因固定内容在小高度下溢出）。
const double kVoicePanelHeight = 300;
const double kEmojiPanelHeight = 300;
const double kAttachmentPanelHeight = 320;
