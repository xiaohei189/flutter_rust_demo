use crate::domain::error::types::{Result, SdkError};
use crate::domain::event::bus::EventBus;
use crate::domain::event::types::SdkEvent;
use crate::domain::model::friend::FriendInfo;
use crate::infra::http::client::HttpApiClient;
use crate::infra::http::routes::{
    ACCEPT_FRIEND_APPLICATION, ADD_BLACK, ADD_FRIEND, CHECK_FRIEND, DELETE_FRIEND,
    GET_BLACK_LIST, GET_FRIEND_APPLY_LIST, GET_FRIEND_ID_LIST, GET_FRIEND_LIST,
    GET_SELF_FRIEND_APPLY_LIST, GET_SELF_UNHANDLED_APPLY_COUNT, REFUSE_FRIEND_APPLICATION,
    REMOVE_BLACK, RESPOND_FRIEND_APPLY,
};
use serde::{Deserialize, Serialize};
use std::sync::Arc;
use tokio::sync::RwLock;
use tracing::info;

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct GetFriendListReq {
    #[serde(rename = "userID")]
    pub user_id: String,
    #[serde(rename = "pagination")]
    pub pagination: Pagination,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Pagination {
    #[serde(rename = "pageNumber")]
    pub page_number: i32,
    #[serde(rename = "showNumber")]
    pub show_number: i32,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct FriendUserInfo {
    #[serde(rename = "userID")]
    pub user_id: String,
    pub nickname: String,
    #[serde(rename = "faceURL")]
    pub face_url: String,
    pub ex: String,
    #[serde(rename = "createTime", default)]
    pub create_time: i64,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct FriendServerInfo {
    #[serde(rename = "ownerUserID")]
    pub owner_user_id: String,
    pub remark: String,
    #[serde(rename = "createTime", default)]
    pub create_time: i64,
    #[serde(rename = "friendUser")]
    pub friend_user: FriendUserInfo,
    #[serde(rename = "addSource", default)]
    pub add_source: i32,
    #[serde(rename = "operatorUserID", default)]
    pub operator_user_id: String,
    #[serde(default)]
    pub ex: String,
    #[serde(rename = "isPinned", default)]
    pub is_pinned: bool,
}

#[derive(Clone, Debug, Serialize, Deserialize, Default)]
pub struct GetFriendListResp {
    #[serde(rename = "friendsInfo", default)]
    pub friends_info: Option<Vec<FriendServerInfo>>,
    #[serde(rename = "total", default)]
    pub total: i32,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct AddFriendReq {
    #[serde(rename = "fromUserID")]
    pub from_user_id: String,
    #[serde(rename = "toUserID")]
    pub to_user_id: String,
    #[serde(rename = "reqMsg")]
    pub req_msg: Option<String>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct DeleteFriendReq {
    #[serde(rename = "toUserID")]
    pub to_user_id: String,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct GetFriendIdListResp {
    #[serde(rename = "friendIDs")]
    pub friend_ids: Vec<String>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct AddBlackReq {
    #[serde(rename = "toUserID")]
    pub to_user_id: String,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct RemoveBlackReq {
    #[serde(rename = "toUserID")]
    pub to_user_id: String,
}

#[derive(Clone, Debug, Serialize, Deserialize, Default)]
pub struct GetBlackListResp {
    #[serde(rename = "blacksInfo", default)]
    pub blacks_info: Vec<BlackServerInfo>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct BlackServerInfo {
    #[serde(rename = "userID")]
    pub user_id: String,
    pub nickname: String,
    #[serde(rename = "faceURL")]
    pub face_url: String,
    #[serde(rename = "createTime")]
    pub create_time: i64,
    pub ex: String,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct GetFriendApplyListReq {
    #[serde(rename = "fromUserID")]
    pub from_user_id: String,
    #[serde(rename = "pagination")]
    pub pagination: Pagination,
}

#[derive(Clone, Debug, Serialize, Deserialize, Default)]
pub struct GetFriendApplyListResp {
    #[serde(rename = "applyInfos", default)]
    pub apply_infos: Option<Vec<FriendApplyInfo>>,
    #[serde(rename = "total", default)]
    pub total: i32,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct FriendApplyInfo {
    #[serde(rename = "userID")]
    pub user_id: String,
    pub nickname: String,
    #[serde(rename = "faceURL")]
    pub face_url: String,
    pub gender: i32,
    #[serde(rename = "createTime")]
    pub create_time: i64,
    #[serde(rename = "addSource")]
    pub add_source: i32,
    pub ex: String,
    pub req_msg: Option<String>,
    pub handle_result: i32,
    pub handle_msg: Option<String>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct AcceptFriendApplicationReq {
    #[serde(rename = "toUserID")]
    pub to_user_id: String,
    #[serde(rename = "handleMsg")]
    pub handle_msg: Option<String>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct RefuseFriendApplicationReq {
    #[serde(rename = "toUserID")]
    pub to_user_id: String,
    #[serde(rename = "handleMsg")]
    pub handle_msg: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct CheckFriendResult {
    #[serde(rename = "userID")]
    pub user_id: String,
    #[serde(rename = "result")]
    pub result: i32,
}

pub struct FriendManager {
    http_client: Arc<HttpApiClient>,
    event_bus: Arc<EventBus>,
    user_id: Arc<RwLock<String>>,
    friends: Arc<RwLock<Vec<FriendInfo>>>,
    blacks: Arc<RwLock<Vec<String>>>,
}

impl FriendManager {
    pub fn new(http_client: Arc<HttpApiClient>, event_bus: Arc<EventBus>, user_id: String) -> Self {
        Self {
            http_client,
            event_bus,
            user_id: Arc::new(RwLock::new(user_id)),
            friends: Arc::new(RwLock::new(Vec::new())),
            blacks: Arc::new(RwLock::new(Vec::new())),
        }
    }

    pub async fn set_user_id(&self, user_id: String) {
        *self.user_id.write().await = user_id.clone();
        info!("FriendManager user_id 已更新为: {}", user_id);
    }

    pub async fn get_friend_list(&self) -> Vec<FriendInfo> {
        self.friends.read().await.clone()
    }

    pub async fn get_friend_id_list(&self) -> Vec<String> {
        self.friends
            .read()
            .await
            .iter()
            .map(|f| f.user_id.clone())
            .collect()
    }

    pub async fn sync_friends(&self) -> Result<()> {
        let user_id = self.user_id.read().await.clone();
        let req = GetFriendListReq {
            user_id,
            pagination: Pagination {
                page_number: 1,
                show_number: 1000,
            },
        };

        let resp: GetFriendListResp = self.http_client.post(GET_FRIEND_LIST, &req).await?;

        let friends: Vec<FriendInfo> = resp
            .friends_info
            .unwrap_or_default()
            .into_iter()
            .map(|s| server_to_friend(s))
            .collect();

        *self.friends.write().await = friends.clone();

        self.event_bus.publish(SdkEvent::FriendAdded {
            friends: friends.clone(),
        });

        info!("好友列表已同步, count={}", friends.len());
        Ok(())
    }

    pub async fn add_friend(&self, user_id: String, req_msg: Option<String>) -> Result<()> {
        let from_user_id = self.user_id.read().await.clone();
        let req = AddFriendReq {
            from_user_id,
            to_user_id: user_id.clone(),
            req_msg,
        };

        let _resp: serde_json::Value = self.http_client.post(ADD_FRIEND, &req).await?;

        info!("好友申请已发送: {}", user_id);
        Ok(())
    }

    pub async fn delete_friend(&self, user_id: String) -> Result<()> {
        let req = DeleteFriendReq {
            to_user_id: user_id.clone(),
        };

        let _resp: serde_json::Value = self.http_client.post(DELETE_FRIEND, &req).await?;

        self.friends.write().await.retain(|f| f.user_id != user_id);

        self.event_bus.publish(SdkEvent::FriendDeleted {
            friend_id: user_id.clone(),
        });

        info!("好友已删除: {}", user_id);
        Ok(())
    }

    pub async fn is_friend(&self, user_id: &str) -> bool {
        self.friends.read().await.iter().any(|f| f.user_id == user_id)
    }

    /// 批量检查好友关系状态（对齐 Go SDK CheckFriend）
    pub async fn check_friend(&self, user_ids: Vec<String>) -> Result<Vec<CheckFriendResult>> {
        let req = serde_json::json!({
            "userIDList": user_ids,
        });
        #[derive(Deserialize, Default)]
        struct CheckFriendResp {
            #[serde(rename = "resultInfo")]
            result_info: Vec<CheckFriendResult>,
        }
        let resp: CheckFriendResp = self.http_client.post(CHECK_FRIEND, &req).await?;
        Ok(resp.result_info)
    }

    pub async fn friend_count(&self) -> usize {
        self.friends.read().await.len()
    }

    pub async fn get_blacklist(&self) -> Vec<String> {
        self.blacks.read().await.clone()
    }

    pub async fn sync_blacks(&self) -> Result<()> {
        let resp: GetBlackListResp = self.http_client.post(GET_BLACK_LIST, &()).await?;

        let blacks: Vec<String> = resp.blacks_info.into_iter().map(|b| b.user_id).collect();

        *self.blacks.write().await = blacks.clone();

        info!("黑名单已同步, count={}", blacks.len());
        Ok(())
    }

    pub async fn add_black(&self, user_id: String) -> Result<()> {
        let req = AddBlackReq {
            to_user_id: user_id.clone(),
        };

        let _resp: serde_json::Value = self.http_client.post(ADD_BLACK, &req).await?;

        self.blacks.write().await.push(user_id.clone());

        self.event_bus.publish(SdkEvent::BlackAdded {
            user_id: user_id.clone(),
        });

        info!("已添加到黑名单: {}", user_id);
        Ok(())
    }

    pub async fn remove_black(&self, user_id: String) -> Result<()> {
        let req = RemoveBlackReq {
            to_user_id: user_id.clone(),
        };

        let _resp: serde_json::Value = self.http_client.post(REMOVE_BLACK, &req).await?;

        self.blacks.write().await.retain(|id| id != &user_id);

        self.event_bus.publish(SdkEvent::BlackDeleted {
            black_id: user_id.clone(),
        });

        info!("已从黑名单移除: {}", user_id);
        Ok(())
    }

    pub async fn is_in_blacklist(&self, user_id: &str) -> bool {
        self.blacks.read().await.iter().any(|id| id == user_id)
    }

    pub async fn get_friend_apply_list(&self) -> Result<GetFriendApplyListResp> {
        let user_id = self.user_id.read().await.clone();
        let req = GetFriendApplyListReq {
            from_user_id: user_id,
            pagination: Pagination {
                page_number: 1,
                show_number: 1000,
            },
        };
        let resp: GetFriendApplyListResp = self.http_client.post(GET_FRIEND_APPLY_LIST, &req).await?;
        Ok(resp)
    }

    /// 获取自己发出的好友申请列表（对齐 Go SDK GetFriendApplicationListAsApplicant）
    pub async fn get_friend_apply_list_as_applicant(&self) -> Result<GetFriendApplyListResp> {
        let user_id = self.user_id.read().await.clone();
        let req = GetFriendApplyListReq {
            from_user_id: user_id,
            pagination: Pagination {
                page_number: 1,
                show_number: 1000,
            },
        };
        let resp: GetFriendApplyListResp = self.http_client.post(GET_SELF_FRIEND_APPLY_LIST, &req).await?;
        Ok(resp)
    }

    /// 获取未处理的好友申请数量（对齐 Go SDK GetFriendApplicationUnhandledCount）
    pub async fn get_friend_application_unhandled_count(&self) -> Result<i32> {
        #[derive(Serialize)]
        struct UnhandledCountReq {
            user_id: String,
        }
        let user_id = self.user_id.read().await.clone();
        let req = UnhandledCountReq { user_id };
        #[derive(Deserialize, Default)]
        struct UnhandledCountResp {
            count: i32,
        }
        let resp: UnhandledCountResp = self.http_client.post(GET_SELF_UNHANDLED_APPLY_COUNT, &req).await?;
        Ok(resp.count)
    }

    pub async fn accept_friend_application(&self, user_id: String, handle_msg: Option<String>) -> Result<()> {
        let req = AcceptFriendApplicationReq {
            to_user_id: user_id.clone(),
            handle_msg,
        };
        let _resp: serde_json::Value = self.http_client.post(ACCEPT_FRIEND_APPLICATION, &req).await?;

        // 对齐 Go SDK: 接受好友申请后同步好友列表（创建好友关系）
        if let Err(e) = self.sync_friends().await {
            tracing::warn!("接受好友申请后同步好友列表失败: {}", e);
        }

        info!("好友申请已接受: {}", user_id);
        Ok(())
    }

    pub async fn refuse_friend_application(&self, user_id: String, handle_msg: Option<String>) -> Result<()> {
        let req = RefuseFriendApplicationReq {
            to_user_id: user_id.clone(),
            handle_msg,
        };
        let _resp: serde_json::Value = self.http_client.post(REFUSE_FRIEND_APPLICATION, &req).await?;
        info!("好友申请已拒绝: {}", user_id);
        Ok(())
    }

    pub async fn clear(&self) {
        self.friends.write().await.clear();
        self.blacks.write().await.clear();
        info!("好友数据已清空");
    }
}

fn server_to_friend(s: FriendServerInfo) -> FriendInfo {
    FriendInfo {
        user_id: s.friend_user.user_id,
        nickname: s.friend_user.nickname,
        face_url: s.friend_user.face_url,
        gender: 0,
        remark: s.remark,
        create_time: s.create_time,
        add_source: s.add_source.to_string(),
        ex: s.friend_user.ex,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_server_to_friend_conversion() {
        let server = FriendServerInfo {
            owner_user_id: "owner_123".to_string(),
            remark: "My Friend".to_string(),
            create_time: 1234567890,
            friend_user: FriendUserInfo {
                user_id: "user_123".to_string(),
                nickname: "Test Friend".to_string(),
                face_url: "https://example.com/avatar.jpg".to_string(),
                ex: String::new(),
                create_time: 0,
            },
            add_source: 1,
            operator_user_id: "owner_123".to_string(),
            ex: String::new(),
            is_pinned: false,
        };

        let domain = server_to_friend(server);
        assert_eq!(domain.user_id, "user_123");
        assert_eq!(domain.nickname, "Test Friend");
        assert_eq!(domain.remark, "My Friend");
    }

    #[test]
    fn test_get_friend_list_req_serialization() {
        let req = GetFriendListReq {
            user_id: "test_user".to_string(),
            pagination: Pagination {
                page_number: 1,
                show_number: 100,
            },
        };

        let json = serde_json::to_string(&req).unwrap();
        assert!(json.contains("pagination"));
        assert!(json.contains("pageNumber"));
    }

    #[test]
    fn test_add_friend_req_serialization() {
        let req = AddFriendReq {
            from_user_id: "user_123".to_string(),
            to_user_id: "user_456".to_string(),
            req_msg: Some("Hello!".to_string()),
        };

        let json = serde_json::to_string(&req).unwrap();
        assert!(json.contains("toUserID"));
        assert!(json.contains("fromUserID"));
        assert!(json.contains("Hello!"));
    }

    #[test]
    fn test_add_black_req_serialization() {
        let req = AddBlackReq {
            to_user_id: "user_789".to_string(),
        };

        let json = serde_json::to_string(&req).unwrap();
        assert!(json.contains("toUserID"));
        assert!(json.contains("user_789"));
    }
}
