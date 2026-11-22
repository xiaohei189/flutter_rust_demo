//! 跨模块共享的外部服务线格式类型

use serde::{Deserialize, Serialize};

/// 分页参数（好友/群组等服务端接口共用，对齐 Go SDK `sdkws.RequestPagination`）
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Pagination {
    #[serde(rename = "pageNumber")]
    pub page_number: i32,
    #[serde(rename = "showNumber")]
    pub show_number: i32,
}
