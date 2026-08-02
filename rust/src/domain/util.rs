//! 领域层通用工具函数

use rand::Rng;

/// 生成指定长度的随机字母数字串（0-9a-z），用于消息 ID 后缀等场景
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

#[cfg(test)]
mod tests {
    use super::generate_random_id;
    use std::collections::HashSet;

    #[test]
    fn test_generate_random_id_length() {
        assert_eq!(generate_random_id(8).len(), 8);
        assert_eq!(generate_random_id(1).len(), 1);
        assert_eq!(generate_random_id(32).len(), 32);
        assert_eq!(generate_random_id(0).len(), 0);
    }

    #[test]
    fn test_generate_random_id_charset() {
        let id = generate_random_id(100);
        for c in id.chars() {
            assert!(
                c.is_ascii_digit() || (c.is_ascii_lowercase() && c <= 'z'),
                "unexpected char: {}",
                c
            );
        }
    }

    #[test]
    fn test_generate_random_id_uniqueness() {
        let ids: Vec<String> = (0..100).map(|_| generate_random_id(16)).collect();
        let unique: HashSet<&String> = ids.iter().collect();
        assert_eq!(unique.len(), 100);
    }
}