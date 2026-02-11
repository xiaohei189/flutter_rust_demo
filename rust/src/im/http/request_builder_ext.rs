//! 为 reqwest_middleware::RequestBuilder 扩展 json 方法

use anyhow::Result;
use serde::Serialize;

/// 扩展 RequestBuilder，添加 json 方法（reqwest-middleware 0.4 未包含 json 方法）
pub trait RequestBuilderJsonExt {
    fn json<T: Serialize + ?Sized>(self, json: &T) -> Result<reqwest_middleware::RequestBuilder>;
}

impl RequestBuilderJsonExt for reqwest_middleware::RequestBuilder {
    fn json<T: Serialize + ?Sized>(self, json: &T) -> Result<reqwest_middleware::RequestBuilder> {
        let body = serde_json::to_string(json)?;
        Ok(self
            .header("Content-Type", "application/json")
            .body(body))
    }
}
