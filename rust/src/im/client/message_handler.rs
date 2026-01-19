use anyhow::Result;
use futures_util::StreamExt;
use openim_protocol::sdkws;
use serde_json;
use tokio_tungstenite::tungstenite::Message as WsMessage;
use tracing::{debug, error, warn};

use super::OpenIMClient;
use crate::im::client::client::WsReader;

impl OpenIMClient {
    /// 将 MsgData 转换为 JSON 字符串（用于日志和调试）
    pub(crate) fn msg_data_to_json(&self, msg: &sdkws::MsgData) -> String {
        use crate::im::message::handler::MessageHandler;
        MessageHandler::msg_data_to_json(msg)
    }
}
