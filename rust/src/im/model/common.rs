
use serde::{Deserialize, Deserializer};

/// 统一的 API 响应包装结构体（包含 errCode、errMsg、data）
/// data 字段可能为 null 或缺失，因此使用 Option<T>
/// serde 会自动将缺失或 null 的字段反序列化为 None
#[derive(Debug, Deserialize)]
pub struct ApiResponse<T> {
    #[serde(rename = "errCode")]
    pub err_code: i32,
    #[serde(rename = "errMsg")]
    pub err_msg: String,
    pub data: Option<T>,
}



/// 反序列化数组字段，处理 null 值
pub fn deserialize_vec_or_null<'de, D, T>(deserializer: D) -> Result<Vec<T>, D::Error>
where
    D: Deserializer<'de>,
    T: Deserialize<'de>,
{
    let opt = Option::<Vec<T>>::deserialize(deserializer)?;
    Ok(opt.unwrap_or_default())
}
