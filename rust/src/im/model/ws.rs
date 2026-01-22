use anyhow::{Context, Result};
use serde::{Deserialize, Serialize};
use tokio::sync::oneshot;

/// WebSocket 消息类型标识符
pub mod msg_type {
    // 1001/1002/1005：客户端请求拉取消息；响应同样带这些 code
    // - 1001 GetNewestSeq：获取当前用户各会话最新 seq
    // - 1002 PullMsgByRange：按范围拉取消息（长连增量同步）
    // - 1005 PullMsgBySeqList：按 seq 列表拉取消息
    pub const WS_GET_NEWEST_SEQ: i32 = 1001;
    pub const WS_PULL_MSG_BY_RANGE: i32 = 1002;
    pub const WS_PULL_MSG_BY_SEQ_LIST: i32 = 1005;

    // 1003：客户端通过 WS 发送消息时携带；服务端回执同样用 1003
    // 典型流程：send_text_message / send_rich_message 走 WS RPC，响应 errCode/errMsg 填在 OpenIMResp
    pub const WS_SEND_MSG: i32 = 1003;

    // 2001：服务端主动推送新消息（PushMessages），不是请求响应，只在下行通知出现
    pub const WS_PUSH_MSG: i32 = 2001;

    // 2002：被踢下线推送；2003：登出推送
    pub const WS_KICK_ONLINE_MSG: i32 = 2002;
    pub const WS_LOGOUT_MSG: i32 = 2003;

    // 3001：自定义——仿 Go 的 SendMessageNotOss，客户端请求与服务端回执均用此 code
    pub const WS_SEND_MSG_NOT_OSS: i32 = 3001;
}

/// OpenIM 请求结构
#[derive(Debug, Serialize, Deserialize)]
pub struct OpenIMReq {
    /// 请求标识，使用 msg_type 下的操作码（如 1003 发送消息、1001 拉 seq）
    #[serde(rename = "reqIdentifier")]
    pub req_identifier: i32,
    /// 鉴权 token（与登录返回一致），服务端按此校验会话
    pub token: String,
    /// 发送方用户 ID（与 token 对应），Go 客户端同名字段
    #[serde(rename = "sendID")]
    pub send_id: String,
    /// 请求级别的 operationID，用于链路追踪与日志，服务端原样回传
    #[serde(rename = "operationID")]
    pub operation_id: String,
    /// WS 消息内自增序号（客户端维护），用于服务端回包时做匹配
    #[serde(rename = "msgIncr")]
    pub msg_incr: String,
    /// 业务二进制负载（protobuf bytes），随 reqIdentifier 具体含义变化
    #[serde(default)]
    pub data: Vec<u8>,
}

/// OpenIM 响应结构（用于二进制消息）
#[derive(Debug, Deserialize, Serialize, Clone)]
pub struct OpenIMResp {
    /// 与请求相同的操作码（如 1003/2001），用于区分业务类型
    #[serde(rename = "reqIdentifier")]
    pub req_identifier: i32,
    /// 与请求中的 msgIncr 对应，用于匹配 pending RPC
    #[serde(rename = "msgIncr")]
    pub msg_incr: String,
    /// 与请求一致的 operationID，便于追踪
    #[serde(rename = "operationID")]
    pub operation_id: String,
    /// 业务错误码（0 为成功），Go 服务端在回包时填充
    #[serde(rename = "errCode")]
    pub err_code: i32,
    /// 业务错误信息（可空），与 errCode 对应
    #[serde(rename = "errMsg")]
    pub err_msg: String,
    /// 业务二进制负载（protobuf bytes，Base64 传输），需根据 reqIdentifier 解码
    #[serde(default, deserialize_with = "crate::im::serialization::deserialize_base64")]
    pub data: Vec<u8>,
}

/// 长连接 RPC 通用封装：请求 + 可选 oneshot 响应
#[derive(Debug)]
pub struct WsRpcEnvelope {
    pub req: OpenIMReq,
    /// None 表示 fire-and-forget，有值则等待响应
    pub resp: Option<tokio::sync::oneshot::Sender<anyhow::Result<OpenIMResp>>>,
}

/// WebSocket 连接响应结构（文本消息）
/// 用于 WebSocket 连接时的文本响应，包含 errDlt 字段
#[derive(Debug, Deserialize)]
pub struct WebSocketConnectResp {
    #[serde(rename = "errCode")]
    pub err_code: i32,
    #[serde(rename = "errMsg")]
    pub err_msg: String,
    #[serde(rename = "errDlt", default)]
    pub err_dlt: String,
    /// data 字段可能为 null、缺失或包含实际数据
    #[serde(default)]
    pub data: Option<serde_json::Value>,
}

pub enum ConnectionCommand {
    Rpc { req: Option<OpenIMReq>, resp: oneshot::Sender<OpenIMResp> },
    Text(String),
    Binary(Vec<u8>),
    Ping,
    Disconnect(String),
}
