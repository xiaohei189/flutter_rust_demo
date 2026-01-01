//! 测试固件和测试数据

/// 测试用户配置
pub struct TestUser {
    pub phone: String,
    pub password: String,
    pub area_code: String,
}

impl TestUser {
    pub fn new(phone: &str) -> Self {
        Self {
            phone: phone.to_string(),
            password: "284f3d09ea0695538e4ded1c1766d73a".to_string(), // 测试密码
            area_code: "+86".to_string(),
        }
    }
}

/// 默认测试用户
pub fn default_users() -> Vec<TestUser> {
    vec![
        TestUser::new("17764338283"),
        TestUser::new("17764338284"),
        TestUser::new("17764338285"),
    ]
}

/// 测试配置
pub struct TestConfig {
    pub api_base_url: String,
    pub ws_url: String,
    pub platform_id: i32,
}

impl Default for TestConfig {
    fn default() -> Self {
        Self {
            api_base_url: "http://localhost:10002".to_string(),
            ws_url: "ws://localhost:10001".to_string(),
            platform_id: 5,
        }
    }
}

