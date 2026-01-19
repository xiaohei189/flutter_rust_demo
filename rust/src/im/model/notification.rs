use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize, Default, sqlx::FromRow)]
#[serde(rename_all = "camelCase")]
pub struct LocalNotificationSeq {
    pub conversation_id: String,
    pub seq: i64,
}
 