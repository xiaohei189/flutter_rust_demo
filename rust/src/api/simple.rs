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
    use super::super::openim_client::OpenIMClient;

    /// OpenIM 客户端演示：连接、发送消息、接收消息
    /// 使用: cargo test run_openim_client -- --nocapture --ignored
    #[tokio::test]
    #[ignore]
    async fn run_openim_client() {
        let mut client = OpenIMClient::new(
            "4937393320".to_string(),
            "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJVc2VySUQiOiI0OTM3MzkzMzIwIiwiUGxhdGZvcm1JRCI6NSwiZXhwIjoxNzcwOTAzNjkwLCJpYXQiOjE3NjMxMjc2ODV9.bnTKyUQ_w0c_d5UAXWDoKq5YTG8ZPlhA0wXIshQpT6Y".to_string(),
            5,
        );

        // 连接到服务器
        let read = match client.connect().await {
            Ok(r) => r,
            Err(e) => {
                println!("连接失败: {}", e);
                return;
            }
        };

        // 持续监听消息
        println!("📥 客户端运行中，等待消息推送...\n");
        if let Err(e) = client.handle_messages(read).await {
            println!("错误: {}", e);
        }
    }
}
