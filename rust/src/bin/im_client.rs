//! 命令行入口：登录并启动 OpenIM 客户端（WebSocket 长连 + 消息/会话同步）
//!
//! 认证与测试一致，默认账号/密码，可直接：cargo run --bin im_client

use clap::Parser;
use rust_lib_flutter_rust_demo::domain::config::ClientConfig;
use rust_lib_flutter_rust_demo::sdk::client::OpenIMClient;
use tracing::info;

/// 与测试用例相同的默认密码
const DEFAULT_PASSWORD: &str = "284f3d09ea0695538e4ded1c1766d73a";

#[derive(Parser, Debug)]
#[command(name = "im_client", about = "OpenIM 客户端命令行启动")]
struct Args {
    #[arg(long, default_value = "+86")]
    area_code: String,

    #[arg(long, default_value = "17764338283")]
    phone: String,

    #[arg(long, default_value = DEFAULT_PASSWORD)]
    password: String,

    #[arg(long, default_value = "5")]
    platform: i32,
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    let args = Args::parse();

    tracing_subscriber::fmt::init();

    info!("登录中: {} {}", args.area_code, args.phone);
    let token_info = login_async(args.area_code.clone(), args.phone.clone(), args.password, args.platform).await?;

    let config = ClientConfig::new(
        token_info.user_id.clone(),
        token_info.im_token.clone(),
        args.platform,
        None,
        None,
    );
    info!("已创建配置，user_id={}", config.user_id);

    let mut client = IMClient::new(config).await?;
    client.start().await?;
    // 阻塞等待客户端运行循环退出（不调用则不会阻塞）
    client.wait_for_exit().await?;

    flush_tracer_provider();
    Ok(())
}
