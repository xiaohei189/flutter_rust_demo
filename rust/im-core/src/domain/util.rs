//! 领域层纯工具函数：随机 ID 与 MD5，避免 domain 依赖 infra。

use md5::Digest;
use rand::Rng;

/// 生成指定长度的随机字母数字串（0-9a-z）
pub fn generate_random_id(len: usize) -> String {
    let mut rng = rand::thread_rng();
    (0..len)
        .map(|_| {
            let idx = rng.gen_range(0..36);
            if idx < 10 {
                (b'0' + idx) as char
            } else {
                (b'a' + idx - 10) as char
            }
        })
        .collect()
}

/// 计算字节数组的 MD5（hex 编码）
pub fn compute_md5_hex(data: &[u8]) -> String {
    let mut hasher = md5::Md5::new();
    hasher.update(data);
    hex::encode(hasher.finalize())
}
