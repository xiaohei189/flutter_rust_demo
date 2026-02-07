//! WebSocket RPC API 模块
//!
//! 原基于 send_request_and_wait 的 WsRpcClient / WsMessageRpc 已移除，
//! 发送与拉取请使用 send_raw_req 或其它通道（如 long_conn_mgr）自行管理请求与回执。
