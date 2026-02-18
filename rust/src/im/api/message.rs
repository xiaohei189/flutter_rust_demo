//! 消息 HTTP API，路径与 openim-sdk-core pkg/api/api.go 完全一致
use crate::im::api::routes;
use crate::im::http::{extract_data, make_client, HttpClient};
use crate::im::model::message::{
    BatchSendMsgReq, CheckMsgIsSendSuccessReq, CheckMsgIsSendSuccessResp, ClearConversationsMsgReq, DeleteMsgPhysicalBySeqReq, DeleteMsgPhysicalReq, DeleteMsgsReq, EmptyResp,
    GetConversationsHasReadAndMaxSeqReq, GetConversationsHasReadAndMaxSeqResp, GetNewestSeqReq, GetNewestSeqResp, MarkConversationAsReadReq, MarkMsgsAsReadReq, PullMessageBySeqsReq,
    PullMessageBySeqsResp, RevokeMsgReq, SearchMessageReq, SearchMessageResp, SendMsgReq, SendMsgResp, ServerTimeResp, SetConversationHasReadSeqReq, UserClearAllMsgReq,
};
use anyhow::Result;

#[derive(Clone)]
pub struct MessageApi {
    client: HttpClient,
    api_base_url: String,
    user_id: String,
}

impl MessageApi {
    pub fn new(client: reqwest::Client, api_base_url: String, user_id: String, token: &str) -> Self {
        Self {
            client: make_client(client, token),
            api_base_url,
            user_id,
        }
    }

    /// RevokeMsg = "/msg/revoke_msg"
    pub async fn revoke_message(&self, req: RevokeMsgReq) -> Result<EmptyResp> {
        self.post_json(routes::MSG_REVOKE_MSG, req).await
    }

    /// MarkMsgsAsRead = "/msg/mark_msgs_as_read"
    pub async fn mark_msgs_as_read(&self, req: MarkMsgsAsReadReq) -> Result<EmptyResp> {
        self.post_json(routes::MSG_MARK_MSGS_AS_READ, req).await
    }

    /// MarkConversationAsRead = "/msg/mark_conversation_as_read"
    pub async fn mark_conversation_as_read(&self, req: MarkConversationAsReadReq) -> Result<EmptyResp> {
        self.post_json(routes::MSG_MARK_CONVERSATION_AS_READ, req).await
    }

    /// 历史消息搜索（服务端路由，非 Go api 定义）
    pub async fn search_msg(&self, req: SearchMessageReq) -> Result<SearchMessageResp> {
        self.post_json("/msg/search_msg", req).await
    }

    /// 拉取最新 seq（服务端路由）
    pub async fn get_newest_seq(&self) -> Result<GetNewestSeqResp> {
        let payload = GetNewestSeqReq { user_id: self.user_id.clone() };
        self.post_json("/msg/newest_seq", payload).await
    }

    /// 按 seq 拉消息（服务端路由）
    pub async fn pull_msg_by_seqs(&self, payload: PullMessageBySeqsReq) -> Result<PullMessageBySeqsResp> {
        self.post_json("/msg/pull_msg_by_seq", payload).await
    }

    /// SetConversationHasReadSeq = "/msg/set_conversation_has_read_seq"
    pub async fn set_conversation_has_read_seq(&self, payload: SetConversationHasReadSeqReq) -> Result<EmptyResp> {
        self.post_json(routes::MSG_SET_CONVERSATION_HAS_READ_SEQ, payload).await
    }

    /// ClearConversationMsg = "/msg/clear_conversation_msg"
    pub async fn clear_conversation_msg(&self, payload: ClearConversationsMsgReq) -> Result<EmptyResp> {
        self.post_json(routes::MSG_CLEAR_CONVERSATION_MSG, payload).await
    }

    /// ClearAllMsg = "/msg/user_clear_all_msg"
    pub async fn user_clear_all_msg(&self, payload: UserClearAllMsgReq) -> Result<EmptyResp> {
        self.post_json(routes::MSG_USER_CLEAR_ALL_MSG, payload).await
    }

    /// DeleteMsgs = "/msg/delete_msgs"
    pub async fn delete_msgs(&self, payload: DeleteMsgsReq) -> Result<EmptyResp> {
        self.post_json(routes::MSG_DELETE_MSGS, payload).await
    }

    /// 物理删除消息（服务端路由）
    pub async fn delete_msg_physical(&self, payload: DeleteMsgPhysicalReq) -> Result<EmptyResp> {
        self.post_json("/msg/delete_msg_physical", payload).await
    }

    /// 按 seq 物理删除（服务端路由）
    pub async fn delete_msg_physical_by_seq(&self, payload: DeleteMsgPhysicalBySeqReq) -> Result<EmptyResp> {
        self.post_json("/msg/delete_msg_phsical_by_seq", payload).await
    }

    /// 批量发消息（服务端路由）
    pub async fn batch_send_msg(&self, payload: BatchSendMsgReq) -> Result<EmptyResp> {
        self.post_json("/msg/batch_send_msg", payload).await
    }

    /// 检查发送是否成功（服务端路由）
    pub async fn check_msg_is_send_success(&self, payload: CheckMsgIsSendSuccessReq) -> Result<CheckMsgIsSendSuccessResp> {
        self.post_json("/msg/check_msg_is_send_success", payload).await
    }

    /// GetServerTime = "/msg/get_server_time"
    pub async fn get_server_time(&self) -> Result<ServerTimeResp> {
        self.post_json(routes::MSG_GET_SERVER_TIME, serde_json::json!({})).await
    }

    /// GetConversationsHasReadAndMaxSeq = "/msg/get_conversations_has_read_and_max_seq"（对齐 Go api.GetConversationsHasReadAndMaxSeq）
    pub async fn get_conversations_has_read_and_max_seq(
        &self,
        req: GetConversationsHasReadAndMaxSeqReq,
    ) -> Result<GetConversationsHasReadAndMaxSeqResp> {
        self.post_json(routes::MSG_GET_CONVERSATIONS_HAS_READ_AND_MAX_SEQ, req).await
    }

    /// SendMsg = "/msg/send_msg"，与 Go api.SendMsg 对齐
    pub async fn send_msg(&self, req: SendMsgReq) -> Result<SendMsgResp> {
        self.post_json(routes::MSG_SEND_MSG, req).await
    }

    async fn post_json<T: serde::Serialize, R: serde::de::DeserializeOwned>(&self, path: &str, payload: T) -> Result<R> {
        let url = format!("{}{}", self.api_base_url, path);
        let resp = self
            .client
            .post(&url)
            .header("Content-Type", "application/json")
            .json(&payload)
            .send()
            .await
            .map_err(|e| anyhow::anyhow!("HTTP request failed: {}", e))?;
        extract_data(resp).await
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::im::http::login_async;
    use crate::im::logger::logger::init_logger;
    use crate::im::model::message::{
        BatchSendMsgReq, CheckMsgIsSendSuccessReq, ClearConversationsMsgReq, DeleteMsgPhysicalBySeqReq, DeleteMsgPhysicalReq, DeleteMsgsReq, GetNewestSeqResp, MarkConversationAsReadReq,
        MarkMsgsAsReadReq, PullMessageBySeqsReq, RevokeMsgReq, SeqRange, SetConversationHasReadSeqReq, UserClearAllMsgReq,
    };
    use openim_protocol::constant;
    use serde_json::json;
    use test_context::{test_context, AsyncTestContext};
    use tokio::sync::OnceCell;
    use tracing::{error, info};

    static APP_CTX: OnceCell<AppCtx> = OnceCell::const_new();

    #[derive(Clone)]
    struct AppCtx {
        api: MessageApi,
        self_user: String,
    }

    impl AsyncTestContext for AppCtx {
        async fn setup() -> Self {
            APP_CTX
                .get_or_init(|| async {
                    init_logger("debug,sqlx=trace,hyper_util::client=info,reqwest=info");
                    let area_code = "+86".to_string();
                    let password = "284f3d09ea0695538e4ded1c1766d73a".to_string();
                    let platform = 5;
                    let token_info = login_async(area_code, "17764338283".to_string(), password, platform).await.expect("登录失败");
                    let api = MessageApi::new(reqwest::Client::new(), "http://localhost:10002".to_string(), token_info.user_id.clone(), &token_info.im_token);
                    AppCtx { api, self_user: token_info.user_id }
                })
                .await
                .clone()
        }

        async fn teardown(self) {
            let _ = self;
        }
    }

    #[test_context(AppCtx)]
    #[tokio::test]
    async fn test_send_text_message(ctx: &mut AppCtx) {
        let api = ctx.api.clone();
        let req = SendMsgReq {
            recv_id: Some(ctx.self_user.clone()),
            group_id: None,
            send_id: ctx.self_user.clone(),
            sender_nickname: None,
            sender_face_url: None,
            sender_platform_id: Some(5),
            content: json!({ "text": { "content": "hello from rust test" } }),
            content_type: constant::TEXT,
            session_type: constant::SINGLE_CHAT_TYPE,
            is_online_only: false,
            not_offline_push: false,
            send_time: None,
            offline_push_info: None,
            ex: None,
        };
        match api.send_message(req).await {
            Ok(v) => info!("send_message resp: {:?}", v),
            Err(e) => error!("send_message error: {:?}", e),
        }
    }

    #[test_context(AppCtx)]
    #[tokio::test]
    async fn test_revoke_message(ctx: &mut AppCtx) {
        let api = ctx.api.clone();
        let req = RevokeMsgReq {
            revoke_msg_client_id: "dummy-client-msg-id".to_string(),
            conversation_id: None,
            user_id: Some(ctx.self_user.clone()),
            seq: None,
            session_type: Some(constant::SINGLE_CHAT_TYPE),
        };
        match api.revoke_message(req).await {
            Ok(v) => info!("revoke_message resp: {:?}", v),
            Err(e) => error!("revoke_message error: {:?}", e),
        }
    }

    #[test_context(AppCtx)]
    #[tokio::test]
    async fn test_mark_msgs_as_read(ctx: &mut AppCtx) {
        let api = ctx.api.clone();
        let req = MarkMsgsAsReadReq {
            conversation_id: "dummy-conv-id".to_string(),
            seqs: vec![1, 2, 3],
            user_id: ctx.self_user.clone(),
        };
        match api.mark_msgs_as_read(req).await {
            Ok(v) => info!("mark_msgs_as_read resp: {:?}", v),
            Err(e) => error!("mark_msgs_as_read error: {:?}", e),
        }
    }

    #[test_context(AppCtx)]
    #[tokio::test]
    async fn test_mark_conversation_as_read(ctx: &mut AppCtx) {
        let api = ctx.api.clone();
        let req = MarkConversationAsReadReq {
            conversation_id: "dummy-conv-id".to_string(),
            user_id: ctx.self_user.clone(),
            has_read_seq: 10,
            seqs: vec![9, 10],
        };
        match api.mark_conversation_as_read(req).await {
            Ok(v) => info!("mark_conversation_as_read resp: {:?}", v),
            Err(e) => error!("mark_conversation_as_read error: {:?}", e),
        }
    }

    #[test_context(AppCtx)]
    #[tokio::test]
    async fn test_search_msg(ctx: &mut AppCtx) {
        let api = ctx.api.clone();
        let req = SearchMessageReq {
            conversation_id: Some("dummy-conv-id".to_string()),
            keyword_list: vec!["hello".to_string()],
            keyword_list_match_type: 0,
            sender_user_id_list: vec![],
            message_type_list: vec![],
            search_time_position: 0,
            search_time_period: 0,
            page_number: 1,
            count: 10,
            offset: 0,
            disable_group: false,
            disable_single: false,
        };
        match api.search_msg(req).await {
            Ok(v) => info!("search_msg resp: {:?}", v),
            Err(e) => error!("search_msg error: {:?}", e),
        }
    }

    #[test_context(AppCtx)]
    #[tokio::test]
    async fn test_get_server_time(ctx: &mut AppCtx) {
        let api = ctx.api.clone();
        match api.get_server_time().await {
            Ok(v) => info!("get_server_time resp: {:?}", v),
            Err(e) => error!("get_server_time error: {:?}", e),
        }
    }

    #[test_context(AppCtx)]
    #[tokio::test]
    async fn test_get_newest_seq(ctx: &mut AppCtx) {
        let api = ctx.api.clone();
        match api.get_newest_seq().await {
            Ok(GetNewestSeqResp { max_seqs }) => {
                info!("get_newest_seq resp count: {}", max_seqs.len())
            }
            Err(e) => error!("get_newest_seq error: {:?}", e),
        }
    }

    #[test_context(AppCtx)]
    #[tokio::test]
    async fn test_check_msg_is_send_success(ctx: &mut AppCtx) {
        let api = ctx.api.clone();
        let payload = CheckMsgIsSendSuccessReq {
            client_msg_id: "dummy-client-msg-id".to_string(),
            conversation_id: Some("dummy-conv-id".to_string()),
            user_id: Some(ctx.self_user.clone()),
        };
        match api.check_msg_is_send_success(payload).await {
            Ok(v) => info!("check_msg_is_send_success resp: {:?}", v),
            Err(e) => error!("check_msg_is_send_success error: {:?}", e),
        }
    }

    #[test_context(AppCtx)]
    #[tokio::test]
    async fn test_pull_msg_by_seqs(ctx: &mut AppCtx) {
        let api = ctx.api.clone();
        let payload = PullMessageBySeqsReq {
            user_id: ctx.self_user.clone(),
            seq_ranges: vec![SeqRange {
                conversation_id: "dummy-conv-id".to_string(),
                begin: 1,
                end: 10,
                num: 0,
            }],
            order: 0,
        };
        match api.pull_msg_by_seqs(payload).await {
            Ok(v) => info!("pull_msg_by_seqs resp: {:?}", v),
            Err(e) => error!("pull_msg_by_seqs error: {:?}", e),
        }
    }

    #[test_context(AppCtx)]
    #[tokio::test]
    async fn test_delete_msgs(ctx: &mut AppCtx) {
        let api = ctx.api.clone();
        let payload = DeleteMsgsReq {
            conversation_id: "dummy-conv-id".to_string(),
            seqs: vec![1, 2],
            user_id: ctx.self_user.clone(),
            delete_sync_opt: None,
        };
        match api.delete_msgs(payload).await {
            Ok(v) => info!("delete_msgs resp: {:?}", v),
            Err(e) => error!("delete_msgs error: {:?}", e),
        }
    }

    #[test_context(AppCtx)]
    #[tokio::test]
    async fn test_batch_send_msg(ctx: &mut AppCtx) {
        let api = ctx.api.clone();
        let payload = BatchSendMsgReq {
            recv_id_list: vec![ctx.self_user.clone()],
            msg_data: crate::im::model::message::MsgStruct {
                content: Some(json!({"text":{"content":"hello batch"}}).to_string()),
                send_id: Some(ctx.self_user.clone()),
                recv_id: Some(ctx.self_user.clone()),
                content_type: constant::TEXT,
                session_type: constant::SINGLE_CHAT_TYPE,
                sender_platform_id: 5,
                msg_from: 100,
                ..Default::default()
            },
        };
        match api.batch_send_msg(payload).await {
            Ok(v) => info!("batch_send_msg resp: {:?}", v),
            Err(e) => error!("batch_send_msg error: {:?}", e),
        }
    }

    #[test_context(AppCtx)]
    #[tokio::test]
    async fn test_set_conversation_has_read_seq(ctx: &mut AppCtx) {
        let api = ctx.api.clone();
        let payload = SetConversationHasReadSeqReq {
            conversation_id: "dummy-conv-id".to_string(),
            user_id: ctx.self_user.clone(),
            has_read_seq: 20,
            no_notification: false,
        };
        match api.set_conversation_has_read_seq(payload).await {
            Ok(v) => info!("set_conversation_has_read_seq resp: {:?}", v),
            Err(e) => error!("set_conversation_has_read_seq error: {:?}", e),
        }
    }

    #[test_context(AppCtx)]
    #[tokio::test]
    async fn test_clear_conversation_msg(ctx: &mut AppCtx) {
        let api = ctx.api.clone();
        let payload = ClearConversationsMsgReq {
            conversation_ids: vec!["dummy-conv-id".to_string()],
            user_id: ctx.self_user.clone(),
            delete_sync_opt: None,
        };
        match api.clear_conversation_msg(payload).await {
            Ok(v) => info!("clear_conversation_msg resp: {:?}", v),
            Err(e) => error!("clear_conversation_msg error: {:?}", e),
        }
    }

    #[test_context(AppCtx)]
    #[tokio::test]
    async fn test_user_clear_all_msg(ctx: &mut AppCtx) {
        let api = ctx.api.clone();
        let payload = UserClearAllMsgReq {
            user_id: ctx.self_user.clone(),
            delete_sync_opt: None,
        };
        match api.user_clear_all_msg(payload).await {
            Ok(v) => info!("user_clear_all_msg resp: {:?}", v),
            Err(e) => error!("user_clear_all_msg error: {:?}", e),
        }
    }

    #[test_context(AppCtx)]
    #[tokio::test]
    async fn test_delete_msg_physical(ctx: &mut AppCtx) {
        let api = ctx.api.clone();
        let payload = DeleteMsgPhysicalReq {
            conversation_ids: vec!["dummy-conv-id".to_string()],
            timestamp: 0,
        };
        match api.delete_msg_physical(payload).await {
            Ok(v) => info!("delete_msg_physical resp: {:?}", v),
            Err(e) => error!("delete_msg_physical error: {:?}", e),
        }
    }

    #[test_context(AppCtx)]
    #[tokio::test]
    async fn test_delete_msg_physical_by_seq(ctx: &mut AppCtx) {
        let api = ctx.api.clone();
        let payload = DeleteMsgPhysicalBySeqReq {
            conversation_id: "dummy-conv-id".to_string(),
            seqs: vec![1, 2],
        };
        match api.delete_msg_physical_by_seq(payload).await {
            Ok(v) => info!("delete_msg_physical_by_seq resp: {:?}", v),
            Err(e) => error!("delete_msg_physical_by_seq error: {:?}", e),
        }
    }

}

