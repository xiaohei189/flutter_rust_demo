use base64::{Engine as _, engine::general_purpose::STANDARD as BASE64};
use prost::Message as ProstMessage;
use serde::{Deserialize, Deserializer, Serialize};

fn deserialize_base64_or_bytes<'de, D>(deserializer: D) -> Result<Vec<u8>, D::Error>
where
    D: Deserializer<'de>,
{
    use serde::de::Error;
    let value = serde_json::Value::deserialize(deserializer)?;
    match value {
        serde_json::Value::String(s) => {
            BASE64.decode(&s).map_err(|e| Error::custom(format!("base64 decode failed: {}", e)))
        }
        serde_json::Value::Array(arr) => {
            arr.into_iter()
                .map(|v| v.as_u64().map(|n| n as u8).ok_or_else(|| Error::custom("expected u8")))
                .collect()
        }
        _ => Err(Error::custom("expected string or array")),
    }
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct OpenIMReq {
    #[serde(rename = "reqIdentifier")]
    pub req_identifier: i32,
    pub token: String,
    #[serde(rename = "sendID")]
    pub send_id: String,
    #[serde(rename = "operationID")]
    pub operation_id: String,
    #[serde(rename = "msgIncr")]
    pub msg_incr: String,
    #[serde(default)]
    pub data: Vec<u8>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct OpenIMResp {
    #[serde(rename = "reqIdentifier")]
    pub req_identifier: i32,
    #[serde(rename = "msgIncr")]
    pub msg_incr: String,
    #[serde(rename = "operationID")]
    pub operation_id: String,
    #[serde(rename = "errCode")]
    pub err_code: i32,
    #[serde(rename = "errMsg")]
    pub err_msg: String,
    #[serde(default, deserialize_with = "deserialize_base64_or_bytes")]
    pub data: Vec<u8>,
}

#[derive(Clone, Debug, Deserialize)]
pub struct WebSocketConnectResp {
    #[serde(rename = "errCode")]
    pub err_code: i32,
    #[serde(rename = "errMsg")]
    pub err_msg: String,
    #[serde(rename = "errDlt", default)]
    pub err_dlt: String,
    #[serde(default)]
    pub data: Option<serde_json::Value>,
}

impl OpenIMReq {
    pub fn new(
        req_identifier: i32,
        token: String,
        send_id: String,
        operation_id: String,
        msg_incr: String,
        data: Vec<u8>,
    ) -> Self {
        Self {
            req_identifier,
            token,
            send_id,
            operation_id,
            msg_incr,
            data,
        }
    }

    pub fn encode_to_vec(&self) -> Result<Vec<u8>, crate::domain::error::types::SdkError> {
        let json = serde_json::to_vec(self).map_err(crate::domain::error::types::SdkError::from)?;
        Ok(json)
    }

    pub fn decode_from_bytes(bytes: &[u8]) -> Result<Self, crate::domain::error::types::SdkError> {
        serde_json::from_slice(bytes).map_err(crate::domain::error::types::SdkError::from)
    }
}

impl OpenIMResp {
    pub fn is_success(&self) -> bool {
        self.err_code == 0
    }

    pub fn into_result<T: ProstMessage + Default>(self) -> Result<T, crate::domain::error::types::SdkError> {
        if self.is_success() {
            T::decode(self.data.as_slice()).map_err(crate::domain::error::types::SdkError::from)
        } else {
            Err(crate::domain::error::types::SdkError::api(self.err_code, &self.err_msg))
        }
    }

    pub fn encode_to_vec(&self) -> Result<Vec<u8>, crate::domain::error::types::SdkError> {
        let json = serde_json::to_vec(self).map_err(crate::domain::error::types::SdkError::from)?;
        Ok(json)
    }

    pub fn decode_from_bytes(bytes: &[u8]) -> Result<Self, crate::domain::error::types::SdkError> {
        serde_json::from_slice(bytes).map_err(crate::domain::error::types::SdkError::from)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_openim_req_encode_decode() {
        let req = OpenIMReq::new(
            1003,
            "test_token".into(),
            "user_123".into(),
            "op_001".into(),
            "msg_1".into(),
            vec![1, 2, 3],
        );

        let encoded = req.encode_to_vec().unwrap();
        let decoded = OpenIMReq::decode_from_bytes(&encoded).unwrap();

        assert_eq!(decoded.req_identifier, 1003);
        assert_eq!(decoded.token, "test_token");
        assert_eq!(decoded.send_id, "user_123");
        assert_eq!(decoded.msg_incr, "msg_1");
        assert_eq!(decoded.data, vec![1, 2, 3]);
    }

    #[test]
    fn test_openim_resp_is_success() {
        let success_resp = OpenIMResp {
            req_identifier: 1003,
            msg_incr: "msg_1".into(),
            operation_id: "op_001".into(),
            err_code: 0,
            err_msg: String::new(),
            data: vec![],
        };
        assert!(success_resp.is_success());

        let error_resp = OpenIMResp {
            req_identifier: 1003,
            msg_incr: "msg_1".into(),
            operation_id: "op_001".into(),
            err_code: 10001,
            err_msg: "user not found".into(),
            data: vec![],
        };
        assert!(!error_resp.is_success());
    }

    #[test]
    fn test_openim_resp_encode_decode() {
        let resp = OpenIMResp {
            req_identifier: 1003,
            msg_incr: "msg_1".into(),
            operation_id: "op_001".into(),
            err_code: 0,
            err_msg: String::new(),
            data: vec![1, 2, 3],
        };

        let encoded = resp.encode_to_vec().unwrap();
        let decoded = OpenIMResp::decode_from_bytes(&encoded).unwrap();

        assert_eq!(decoded.err_code, 0);
        assert_eq!(decoded.data, vec![1, 2, 3]);
    }
}
