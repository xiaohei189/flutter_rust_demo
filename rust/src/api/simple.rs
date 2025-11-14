// 使用 openim-protocol 库（仅内部使用，不通过 FFI 导出类型）
use openim_protocol::{auth, Message};

#[flutter_rust_bridge::frb(sync)]
pub fn greet(name: String) -> String {
    format!("Hello, {name}!")
}


#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    // Default utilities - feel free to customize
    flutter_rust_bridge::setup_default_user_utils();
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_auth_protobuf() {
        // 测试创建用户 Token 请求
        let request = auth::GetUserTokenReq {
            platform_id: 1,
            user_id: "test_user".to_string(),
        };

        // 序列化
        let mut buf = Vec::new();
        request.encode(&mut buf).unwrap();
        
        assert!(!buf.is_empty(), "序列化后的数据不应该为空");
        println!("序列化成功，字节数: {}", buf.len());

        // 反序列化验证
        let decoded = auth::GetUserTokenReq::decode(&buf[..]).unwrap();
        assert_eq!(decoded.platform_id, 1);
        assert_eq!(decoded.user_id, "test_user");
        println!("反序列化成功: platform_id={}, user_id={}", decoded.platform_id, decoded.user_id);
    }

}
