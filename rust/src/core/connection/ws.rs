//! OpenIM WebSocket 帧类型与 Gzip 压缩器
//!
//! 对齐 Go SDK `wsutil/conn.go`（OpenIMReq/OpenIMResp）与 `compressor.go`（GzipCompressor）。
//! 目前仅被连接模块（core::connection）使用，因此放在本模块下。

use anyhow::Context;
use base64::{engine::general_purpose::STANDARD as BASE64, Engine as _};
use flate2::read::GzDecoder;
use flate2::write::GzEncoder;
use flate2::Compression;
use prost::Message as ProstMessage;
use serde::{Deserialize, Deserializer, Serialize};
use std::io::{Read, Write};

fn deserialize_base64_or_bytes<'de, D>(deserializer: D) -> Result<Vec<u8>, D::Error>
where
    D: Deserializer<'de>,
{
    use serde::de::Error;
    let value = serde_json::Value::deserialize(deserializer)?;
    match value {
        serde_json::Value::String(s) => {
            if s.is_empty() {
                Ok(Vec::new())
            } else {
                BASE64.decode(&s).map_err(|e| Error::custom(format!("base64 decode failed: {}", e)))
            }
        }
        serde_json::Value::Array(arr) => arr.into_iter().map(|v| v.as_u64().map(|n| n as u8).ok_or_else(|| Error::custom("expected u8"))).collect(),
        serde_json::Value::Null => Ok(Vec::new()),
        _ => Err(Error::custom("expected string, array, or null")),
    }
}

fn serialize_bytes_base64<S>(data: &Vec<u8>, serializer: S) -> Result<S::Ok, S::Error>
where
    S: serde::Serializer,
{
    if data.is_empty() {
        serializer.serialize_str("")
    } else {
        serializer.serialize_str(&BASE64.encode(data))
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
    #[serde(default, serialize_with = "serialize_bytes_base64", deserialize_with = "deserialize_base64_or_bytes")]
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
    pub fn new(req_identifier: i32, token: String, send_id: String, operation_id: String, msg_incr: String, data: Vec<u8>) -> Self {
        Self {
            req_identifier,
            token,
            send_id,
            operation_id,
            msg_incr,
            data,
        }
    }

    pub fn encode_to_vec(&self) -> Result<Vec<u8>, crate::domain::error::SdkError> {
        let json = serde_json::to_vec(self).map_err(crate::domain::error::SdkError::from)?;
        Ok(json)
    }

    pub fn decode_from_bytes(bytes: &[u8]) -> Result<Self, crate::domain::error::SdkError> {
        serde_json::from_slice(bytes).map_err(crate::domain::error::SdkError::from)
    }
}

impl OpenIMResp {
    pub fn is_success(&self) -> bool {
        self.err_code == 0
    }

    pub fn into_result<T: ProstMessage + Default>(self) -> Result<T, crate::domain::error::SdkError> {
        if self.is_success() {
            T::decode(self.data.as_slice()).map_err(crate::domain::error::SdkError::from)
        } else {
            Err(crate::domain::error::SdkError::api(self.err_code, &self.err_msg))
        }
    }

    pub fn encode_to_vec(&self) -> Result<Vec<u8>, crate::domain::error::SdkError> {
        let json = serde_json::to_vec(self).map_err(crate::domain::error::SdkError::from)?;
        Ok(json)
    }

    pub fn decode_from_bytes(bytes: &[u8]) -> Result<Self, crate::domain::error::SdkError> {
        serde_json::from_slice(bytes).map_err(crate::domain::error::SdkError::from)
    }
}

// ============================================================================
// Gzip 压缩器（对齐 Go SDK compressor.go）
// ============================================================================

/// Gzip 压缩器，用于 WS 二进制消息的压缩/解压
#[derive(Clone)]
pub struct GzipCompressor;

impl GzipCompressor {
    pub fn new() -> Self {
        Self
    }

    /// Gzip 压缩
    pub fn compress(&self, raw_data: &[u8]) -> anyhow::Result<Vec<u8>> {
        let mut encoder = GzEncoder::new(Vec::new(), Compression::default());
        encoder.write_all(raw_data).context("gzip write failed")?;
        encoder.finish().context("gzip finish failed")
    }

    /// Gzip 解压
    pub fn decompress(&self, compressed_data: &[u8]) -> anyhow::Result<Vec<u8>> {
        let mut decoder = GzDecoder::new(compressed_data);
        let mut output = Vec::new();
        decoder.read_to_end(&mut output).context("gzip decompress failed")?;
        Ok(output)
    }
}

impl Default for GzipCompressor {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_openim_req_encode_decode() {
        let req = OpenIMReq::new(1003, "test_token".into(), "user_123".into(), "op_001".into(), "msg_1".into(), vec![1, 2, 3]);

        let encoded = req.encode_to_vec().unwrap();
        let json: serde_json::Value = serde_json::from_slice(&encoded).unwrap();
        assert_eq!(json["data"], serde_json::Value::String("AQID".into()), "data 应序列化为 base64 字符串");
        let decoded = OpenIMReq::decode_from_bytes(&encoded).unwrap();

        assert_eq!(decoded.req_identifier, 1003);
        assert_eq!(decoded.token, "test_token");
        assert_eq!(decoded.send_id, "user_123");
        assert_eq!(decoded.msg_incr, "msg_1");
        assert_eq!(decoded.data, vec![1, 2, 3]);
    }

    #[test]
    fn test_openim_req_empty_data_serializes_as_empty_string() {
        let req = OpenIMReq::new(1003, "test_token".into(), "user_123".into(), "op_001".into(), "msg_1".into(), Vec::new());

        let encoded = req.encode_to_vec().unwrap();
        let json: serde_json::Value = serde_json::from_slice(&encoded).unwrap();
        assert_eq!(json["data"], serde_json::Value::String(String::new()));

        let decoded = OpenIMReq::decode_from_bytes(&encoded).unwrap();
        assert!(decoded.data.is_empty());
    }

    #[test]
    fn test_openim_req_base64_roundtrip_with_response_style_payload() {
        // 服务端返回的响应 data 也可能是 base64 字符串，请求侧应与其对称
        let raw = serde_json::json!({
            "reqIdentifier": 1003,
            "token": "t",
            "sendID": "u",
            "operationID": "op",
            "msgIncr": "m",
            "data": "AQIDBA=="
        });
        let decoded: OpenIMReq = serde_json::from_value(raw).unwrap();
        assert_eq!(decoded.data, vec![1, 2, 3, 4]);
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

    #[test]
    fn test_compress_decompress_roundtrip() {
        let compressor = GzipCompressor::new();
        let original = b"Hello, OpenIM SDK! This is a test message with some repeated content for compression. \
                         Hello, OpenIM SDK! This is a test message with some repeated content for compression.";

        let compressed = compressor.compress(original).unwrap();
        assert!(compressed.len() < original.len(), "compressed should be smaller");

        let decompressed = compressor.decompress(&compressed).unwrap();
        assert_eq!(decompressed, original);
    }

    #[test]
    fn test_compress_empty() {
        let compressor = GzipCompressor::new();
        let compressed = compressor.compress(b"").unwrap();
        let decompressed = compressor.decompress(&compressed).unwrap();
        assert!(decompressed.is_empty());
    }
}
