//! WebSocket RPC API 模块
//!
//! 提供基于 WebSocket 的消息相关 RPC 接口

use std::collections::HashMap;

use anyhow::Result;
use openim_protocol::sdkws;
use openim_protocol::Message as ProtobufMessage;
use tokio::time::Duration;

use crate::im::model::message::{MsgStruct, SeqRange as SeqRangeModel};
use crate::im::model::msg_type;
use crate::im::serialization::generate_msg_id;

/// WebSocket RPC 客户端接口
#[allow(async_fn_in_trait)]
pub trait WsRpcClient: Send + Sync {
    /// 发送请求并等待响应（核心方法）
    async fn send_request_and_wait(&self, req_identifier: i32, data: Vec<u8>, timeout_duration: Option<Duration>) -> Result<crate::im::model::OpenIMResp>;
}

/// WebSocket 消息发送上下文
pub struct WsMessageSendContext {
    pub user_id: String,
    pub platform_id: i32,
}

/// WebSocket 消息 RPC API
pub struct WsMessageRpc<'a, C: WsRpcClient> {
    client: &'a C,
    user_id: String,
    send_ctx: Option<WsMessageSendContext>,
}

impl<'a, C: WsRpcClient> WsMessageRpc<'a, C> {
    pub fn new(client: &'a C, user_id: String) -> Self {
        Self { client, user_id, send_ctx: None }
    }

    /// 创建带发送上下文的 RPC API（用于发送消息）
    pub fn with_send_context(client: &'a C, user_id: String, platform_id: i32) -> Self {
        Self {
            client,
            user_id: user_id.clone(),
            send_ctx: Some(WsMessageSendContext { user_id, platform_id }),
        }
    }

    /// WebSocket：获取最新序列号（reqIdentifier=1001）
    pub async fn get_newest_seq(&self) -> Result<sdkws::GetMaxSeqResp> {
        let req = sdkws::GetMaxSeqReq { user_id: self.user_id.clone() };
        self.proto_call_by_ws(msg_type::WS_GET_NEWEST_SEQ, req).await
    }

    /// WebSocket：按区间拉取消息（reqIdentifier=1002）
    pub async fn pull_msg_by_range(&self, ranges: Vec<SeqRangeModel>, order: i32) -> Result<sdkws::PullMessageBySeqsResp> {
        let seq_ranges: Vec<sdkws::SeqRange> = ranges
            .into_iter()
            .map(|r| sdkws::SeqRange {
                conversation_id: r.conversation_id,
                begin: r.begin,
                end: r.end,
                num: r.num,
            })
            .collect();

        let req: sdkws::PullMessageBySeqsReq = sdkws::PullMessageBySeqsReq {
            user_id: self.user_id.clone(),
            seq_ranges,
            order,
        };
        self.proto_call_by_ws(msg_type::WS_PULL_MSG_BY_RANGE, req).await
    }

    /// WebSocket：按序列号列表拉取消息（reqIdentifier=1003）
    pub async fn pull_msg_by_seq_list(&self, conversation_id: String, seq_list: Vec<i64>) -> Result<sdkws::PullMessageBySeqsResp> {
        let seq_ranges = vec![sdkws::SeqRange {
            conversation_id,
            begin: 0,
            end: 0,
            num: seq_list.len() as i64,
        }];

        let req = sdkws::PullMessageBySeqsReq {
            user_id: self.user_id.clone(),
            seq_ranges,
            order: 0,
        };
        self.proto_call_by_ws(msg_type::WS_PULL_MSG_BY_SEQ_LIST, req).await
    }

    /// WebSocket：发送文本消息
    pub async fn send_text_message(&self, recv_id: String, text: String, session_type: i32) -> Result<()> {
        let content_json = serde_json::json!({ "content": text });
        let content_str = serde_json::to_string(&content_json)?;
        self.send_rich_message(recv_id, session_type, openim_protocol::constant::TEXT, content_str.into_bytes(), None, false)
            .await
    }

    /// WebSocket：发送图片消息
    pub async fn send_picture_message(&self, recv_id: String, picture: crate::im::model::message::PictureElem, session_type: i32) -> Result<()> {
        let content_str = serde_json::to_string(&picture)?;
        self.send_rich_message(recv_id, session_type, openim_protocol::constant::PICTURE, content_str.into_bytes(), None, false)
            .await
    }

    /// WebSocket：发送语音消息
    pub async fn send_sound_message(&self, recv_id: String, sound: crate::im::model::message::SoundElem, session_type: i32) -> Result<()> {
        let content_str = serde_json::to_string(&sound)?;
        self.send_rich_message(recv_id, session_type, openim_protocol::constant::VOICE, content_str.into_bytes(), None, false)
            .await
    }

    /// WebSocket：发送视频消息
    pub async fn send_video_message(&self, recv_id: String, video: crate::im::model::message::VideoElem, session_type: i32) -> Result<()> {
        let content_str = serde_json::to_string(&video)?;
        self.send_rich_message(recv_id, session_type, openim_protocol::constant::VIDEO, content_str.into_bytes(), None, false)
            .await
    }

    /// WebSocket：发送文件消息
    pub async fn send_file_message(&self, recv_id: String, file: crate::im::model::message::FileElem, session_type: i32) -> Result<()> {
        let content_str = serde_json::to_string(&file)?;
        self.send_rich_message(recv_id, session_type, openim_protocol::constant::FILE, content_str.into_bytes(), None, false)
            .await
    }

    /// WebSocket：发送消息（通用方法，支持 MsgStruct）
    pub async fn send_message(&self, recv_id: String, group_id: String, message: MsgStruct, offline_push_info: Option<sdkws::OfflinePushInfo>, is_online_only: bool, not_oss: bool) -> Result<()> {
        let send_ctx = self.send_ctx.as_ref().ok_or_else(|| anyhow::anyhow!("发送上下文未初始化"))?;

        let content = message.content.clone().map(|s| s.into_bytes()).unwrap_or_default();
        let session_type = if !group_id.is_empty() { 2 } else { 1 };

        let now = chrono::Utc::now().timestamp_millis();
        let msg_data = sdkws::MsgData {
            send_id: send_ctx.user_id.clone(),
            recv_id: recv_id.clone(),
            group_id: group_id.clone(),
            client_msg_id: message.client_msg_id.clone().unwrap_or_else(|| generate_msg_id(&send_ctx.user_id)),
            server_msg_id: message.server_msg_id.clone().unwrap_or_default(),
            sender_platform_id: send_ctx.platform_id,
            sender_nickname: message.sender_nickname.clone().unwrap_or_default(),
            sender_face_url: message.sender_face_url.clone().unwrap_or_default(),
            session_type,
            msg_from: message.msg_from,
            content_type: message.content_type,
            content,
            seq: message.seq,
            send_time: if message.send_time > 0 { message.send_time } else { now },
            create_time: if message.create_time > 0 { message.create_time } else { now },
            status: message.status,
            is_read: message.is_read,
            options: HashMap::new(),
            offline_push_info,
            at_user_id_list: vec![],
            attached_info: message.attached_info.clone().unwrap_or_default(),
            ex: message.ex.clone().unwrap_or_default(),
        };

        let mut pb_data = Vec::new();
        msg_data.encode(&mut pb_data)?;

        let msg_type = if not_oss || is_online_only { msg_type::WS_SEND_MSG_NOT_OSS } else { msg_type::WS_SEND_MSG };

        self.client.send_request_and_wait(msg_type, pb_data, None).await?;
        Ok(())
    }

    /// WebSocket：发送富文本消息（通用方法）
    async fn send_rich_message(&self, recv_id: String, session_type: i32, content_type: i32, content: Vec<u8>, offline_push_info: Option<sdkws::OfflinePushInfo>, is_online_only: bool) -> Result<()> {
        let send_ctx = self.send_ctx.as_ref().ok_or_else(|| anyhow::anyhow!("发送上下文未初始化"))?;

        let now = chrono::Utc::now().timestamp_millis();

        let msg_data = sdkws::MsgData {
            send_id: send_ctx.user_id.clone(),
            recv_id: recv_id.clone(),
            group_id: if session_type == 2 { recv_id.clone() } else { String::new() },
            client_msg_id: generate_msg_id(&send_ctx.user_id),
            server_msg_id: String::new(),
            sender_platform_id: send_ctx.platform_id,
            sender_nickname: String::new(),
            sender_face_url: String::new(),
            session_type,
            msg_from: 100, // UserMsgType
            content_type,
            content,
            seq: 0,
            send_time: 0,
            create_time: now,
            status: 1,
            is_read: false,
            options: HashMap::new(),
            offline_push_info,
            at_user_id_list: vec![],
            attached_info: String::new(),
            ex: String::new(),
        };

        let mut pb_data = Vec::new();
        msg_data.encode(&mut pb_data)?;

        let msg_type = if is_online_only { msg_type::WS_SEND_MSG_NOT_OSS } else { msg_type::WS_SEND_MSG };

        self.client.send_request_and_wait(msg_type, pb_data, None).await?;
        Ok(())
    }

    /// 通用：发送 protobuf 请求并解析回执为 protobuf 响应
    async fn proto_call_by_ws<Req, Resp>(&self, msg_type: i32, req: Req) -> Result<Resp>
    where
        Req: ProtobufMessage,
        Resp: ProtobufMessage + Default,
    {
        let req_data = req.encode_to_vec();
        let resp = self.client.send_request_and_wait(msg_type, req_data, None).await?;
        let resp_data = resp.data;
        let decoded = Resp::decode(resp_data.as_slice())?;
        Ok(decoded)
    }
}
