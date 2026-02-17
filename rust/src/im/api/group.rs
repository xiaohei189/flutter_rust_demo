//! 群组 HTTP API 客户端（增量加入群、增量群成员 batch）
//! 与 Go GetIncrementalJoinGroup / GetIncrementalGroupMemberBatch 对齐

use crate::im::http::{extract_data, make_client, HttpClient};
use crate::im::model::group::IncrementalJoinGroupResp;
use anyhow::Result;
use serde::Deserialize;
use std::collections::HashMap;
use uuid::Uuid;

/// 增量群成员单条请求（与 Go GetIncrementalGroupMemberReq 对齐）
#[derive(Debug, Clone, serde::Serialize)]
#[serde(rename_all = "camelCase")]
pub struct GetIncrementalGroupMemberReq {
    pub group_id: String,
    #[serde(skip_serializing_if = "String::is_empty")]
    pub version_id: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub version: Option<u64>,
}

/// 批量增量群成员响应：groupID -> IncrementalGroupMemberResp
#[derive(Debug, Clone, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct BatchIncrementalGroupMemberResp {
    #[serde(default)]
    pub resp_list: HashMap<String, crate::im::model::group::IncrementalGroupMemberResp>,
}

/// 群组相关 HTTP API 客户端
#[derive(Clone)]
pub struct GroupApi {
    client: HttpClient,
    api_base_url: String,
    user_id: String,
}

impl GroupApi {
    pub fn new(client: reqwest::Client, api_base_url: String, user_id: String, token: &str) -> Self {
        Self {
            client: make_client(client, token),
            api_base_url,
            user_id,
        }
    }

    /// 增量拉取当前用户加入的群列表（与 Go getIncrementalJoinGroup 对齐）
    pub async fn get_incremental_join_groups(&self, version: u64, version_id: &str) -> Result<IncrementalJoinGroupResp> {
        let operation_id = Uuid::new_v4().to_string();
        let url = format!("{}/group/get_incremental_join_groups", self.api_base_url);
        let resp = self
            .client
            .post(&url)
            .header("Content-Type", "application/json")
            .header("operationID", &operation_id)
            .json(&serde_json::json!({
                "userID": self.user_id,
                "version": version,
                "versionID": version_id,
            }))
            .send()
            .await
            .map_err(|e| anyhow::anyhow!("HTTP request failed: {}", e))?;
        extract_data(resp).await
    }

    /// 批量拉取各群的增量成员（与 Go getIncrementalGroupMemberBatch 对齐）
    pub async fn get_incremental_group_members_batch(
        &self,
        req_list: &[GetIncrementalGroupMemberReq],
    ) -> Result<HashMap<String, crate::im::model::group::IncrementalGroupMemberResp>> {
        if req_list.is_empty() {
            return Ok(HashMap::new());
        }
        let operation_id = Uuid::new_v4().to_string();
        let url = format!("{}/group/get_incremental_group_members_batch", self.api_base_url);
        let body = serde_json::json!({
            "userID": self.user_id,
            "reqList": req_list,
        });
        let resp = self
            .client
            .post(&url)
            .header("Content-Type", "application/json")
            .header("operationID", &operation_id)
            .json(&body)
            .send()
            .await
            .map_err(|e| anyhow::anyhow!("HTTP request failed: {}", e))?;
        let data: BatchIncrementalGroupMemberResp = extract_data(resp).await?;
        Ok(data.resp_list)
    }
}
