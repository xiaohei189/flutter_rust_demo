//! 集成测试：启动客户端 → 获取会话列表 → 给第一个会话发一条消息 → 退出
//!
//! 需要可用的 OpenIM 服务与有效账号，默认使用与 bin/im_client 相同的测试账号。
//! 运行（查看日志与发送结果）：
//!   cargo test --test im_client_integration -- --nocapture
//! 或设置日志级别：
//!   RUST_LOG=info cargo test --test im_client_integration -- --nocapture

use rust_lib_flutter_rust_demo::im::client::client::{ClientConfig, IMClient};
use rust_lib_flutter_rust_demo::im::logger::logger::init_logger;
use rust_lib_flutter_rust_demo::login_async;
use std::time::Duration;
use tokio::time::timeout;
use tracing::{error, info};

/// 与 bin/im_client 一致的默认测试密码
const DEFAULT_PASSWORD: &str = "284f3d09ea0695538e4ded1c1766d73a";

/// 会话类型：1=单聊, 2=普通群聊, 3=超级群聊, 4=通知会话（不发消息）
const CONVERSATION_TYPE_SINGLE: i32 = 1;
const CONVERSATION_TYPE_GROUP: i32 = 2;
const CONVERSATION_TYPE_SUPER_GROUP: i32 = 3;

const TEST_MSG: &str = "[集成测试] 会话列表群发一条消息";

/// 从 conversation_id 解析出单聊对方 user_id（与 OpenIM 约定一致：si_userA_userB）
fn parse_single_recv_id(conversation_id: &str, self_user_id: &str) -> Option<String> {
    let rest = conversation_id.strip_prefix("si_")?;
    let parts: Vec<&str> = rest.splitn(2, '_').collect();
    if parts.len() >= 2 {
        let a = parts[0];
        let b = parts[1];
        if a == self_user_id {
            return Some(b.to_string());
        }
        if b == self_user_id {
            return Some(a.to_string());
        }
        return Some(b.to_string());
    }
    if parts.len() == 1 && !parts[0].is_empty() && parts[0] != self_user_id {
        return Some(parts[0].to_string());
    }
    None
}

/// 从 conversation_id 解析出群聊 group_id（sg_groupID）
fn parse_group_id(conversation_id: &str) -> Option<String> {
    conversation_id
        .strip_prefix("sg_")
        .filter(|s| !s.is_empty())
        .map(String::from)
}

#[tokio::test]
async fn start_client_get_conversations_then_exit() -> anyhow::Result<()> {
    // 初始化日志，便于看到 tracing 与发送结果（需配合 --nocapture）
    let _ = init_logger("info,rust_lib_flutter_rust_demo=debug");

    let area_code = "+86".to_string();
    let phone = "17764338283".to_string();
    let platform = 5i32;

    let token_info = login_async(area_code, phone, DEFAULT_PASSWORD.to_string(), platform).await?;
    let mut config = ClientConfig::new(token_info.user_id.clone(), token_info.im_token.clone(), platform);
    config.conversation_db_url = "sqlite://conversations_test.db?mode=rwc".to_string();
    let self_user_id = config.user_id.clone();

    let mut client = IMClient::new(config);

    // 1. 启动客户端（非阻塞）
    client.start().await?;

    // 2. 等待 WebSocket 连接与初始同步（稍长一点便于发消息走 WS）
    tokio::time::sleep(Duration::from_secs(3)).await;

    // 3. 获取会话列表
    let list = client.get_all_conversations().await?;
    eprintln!("[集成测试] 会话总数: {}", list.conversations.len());
    for (i, c) in list.conversations.iter().enumerate() {
        eprintln!(
            "  [{}] id={} type={} user_id={:?} group_id={:?}",
            i, c.conversation_id, c.conversation_type, c.user_id, c.group_id
        );
    }

    // 4. 仅给第一个会话发送一条消息（优先用 API 返回的 user_id/group_id，否则从 conversation_id 解析）
    let self_user_id = self_user_id.as_str();
    if let Some(conv) = list.conversations.first() {
        let send = match conv.conversation_type {
            CONVERSATION_TYPE_SINGLE => {
                let recv_id = conv
                    .user_id
                    .is_empty()
                    .then(|| parse_single_recv_id(&conv.conversation_id, self_user_id))
                    .flatten()
                    .or_else(|| Some(conv.user_id.clone()).filter(|s| !s.is_empty()));
                match recv_id {
                    Some(rid) => client.send_text_message(rid, TEST_MSG.to_string()).await,
                    None => {
                        eprintln!(
                            "[集成测试] 跳过第一个会话(单聊) id={} (无法解析 recv_id)",
                            conv.conversation_id
                        );
                        Err(anyhow::anyhow!("无法解析 recv_id"))
                    }
                }
            }
            CONVERSATION_TYPE_GROUP | CONVERSATION_TYPE_SUPER_GROUP => {
                let gid = conv
                    .group_id
                    .is_empty()
                    .then(|| parse_group_id(&conv.conversation_id))
                    .flatten()
                    .or_else(|| Some(conv.group_id.clone()).filter(|s| !s.is_empty()));
                match gid {
                    Some(gid) => client.send_text_to_group(gid, TEST_MSG.to_string()).await,
                    None => {
                        eprintln!(
                            "[集成测试] 跳过第一个会话(群聊) id={} (无法解析 group_id)",
                            conv.conversation_id
                        );
                        Err(anyhow::anyhow!("无法解析 group_id"))
                    }
                }
            }
            _ => {
                eprintln!(
                    "[集成测试] 跳过第一个会话 type={} id={} (通知或未知类型)",
                    conv.conversation_type, conv.conversation_id
                );
                Err(anyhow::anyhow!("不支持的会话类型"))
            }
        };
        match send {
            Ok(resp) => {
                info!(
                    conversation_id = %conv.conversation_id,
                    client_msg_id = %resp.client_msg_id,
                    "已发送"
                );
                eprintln!(
                    "[集成测试] 已发送(第一个会话) -> conversation_id={} client_msg_id={}",
                    conv.conversation_id, resp.client_msg_id
                );
            }
            Err(e) => {
                error!(conversation_id = %conv.conversation_id, error = %e, "发送失败");
                eprintln!("[集成测试] 发送失败 conversation_id={} error={}", conv.conversation_id, e);
            }
        }
    } else {
        eprintln!("[集成测试] 无会话，未发送消息");
    }

    // 5. 退出：等待运行循环结束（带超时，避免无限阻塞）
    let _ = timeout(Duration::from_secs(3), client.wait_for_exit()).await;

    Ok(())
}
