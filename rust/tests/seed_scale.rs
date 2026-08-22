mod common;

use common::*;
use rust_lib_flutter_rust_demo::domain::constant::enums::GroupType;
use rust_lib_flutter_rust_demo::sdk::client::*;
use std::sync::Arc;
use std::time::{Duration, Instant};

/// 规模化演示数据：1 万用户基数 + 20 个中型群 + 3 个大型群，围绕当前登录用户。
///
/// - 用户：确定性手机号（1776+7位序号）批量注册，重复执行幂等（已存在则跳过/登录）。
/// - 群：当前用户为所有群成员，消息以当前用户为主、少量演示用户参与。
///
/// 运行（需 Docker OpenIM：10001/10002/10008）：
/// `powershell
/// cargo test --test seed_scale -- --ignored --test-threads=1 --nocapture
/// `
/// 目标账号默认取 OPENIM_DEMO_TARGET_PHONE（App 当前登录手机号），缺省 17764008284。
#[tokio::test]
#[ignore = "requires docker OpenIM server"]
async fn seed_scale_data() {
    let started = Instant::now();
    let _ = tracing_subscriber::fmt()
        .with_max_level(tracing::Level::WARN)
        .with_target(false)
        .try_init();

    let total_users = 10_000usize;
    let target_phone = std::env::var("OPENIM_DEMO_TARGET_PHONE")
        .ok()
        .filter(|s| !s.is_empty())
        .unwrap_or_else(|| "17764008284".to_string());

    // ========== 1. 批量注册用户基数 ==========
    println!("\n========== 批量注册 {} 用户（并发 24）==========", total_users);
    let users = register_bulk(1, total_users, 24).await;
    println!("  注册/复用成功: {} 个", users.len());

    // ========== 2. 登录目标账号 + 3 个发言演示用户 ==========
    println!("\n========== 登录 SDK ==========");
    let me = login_or_register_user(&target_phone, "我").await;
    let (me_token, _) = login_account(&me).await.expect("目标账号登录失败");
    let me_sdk = create_sdk(&me, &me_token).await;
    println!("  目标账号: {} ({})", me.user_id, me.phone);

    let speakers = [users[1].clone(), users[2].clone(), users[3].clone()];
    let mut speaker_sdks = Vec::new();
    for s in &speakers {
        let (tok, _) = login_account(s).await.expect("speaker 登录失败");
        let sdk = create_sdk(s, &tok).await;
        println!("  发言用户: {} ({})", s.nickname, s.user_id);
        speaker_sdks.push(sdk);
    }

    // ========== 3. 建群：20 中型（200人）+ 3 大型（2000/1500/1200）==========
    println!("\n========== 创建群聊 ==========");
    let medium_names = [
        "前端技术交流", "后端架构组", "产品需求评审", "UI 设计讨论", "测试质量保障",
        "运维值班群", "数据平台组", "算法研究组", "移动端开发", "Web 开发组",
        "项目管理部", "市场运营部", "人力资源部", "财务部", "法务合规",
        "客户成功部", "售前方案组", "售后支持组", "企业文化活动", "全员通知群",
    ];
    let large_names = ["公司全员大群", "集团总群", "年度战略群"];

    let mut all_groups = Vec::new();
    let member_of = |users: &[TestAccount], start: usize, count: usize| -> Vec<String> {
        users
            .iter()
            .cycle()
            .skip(start)
            .take(count)
            .map(|u| u.user_id.clone())
            .collect()
    };

    // 20 个中型群，每个 200 人（滚动窗口，避免重复组合）
    for (i, name) in medium_names.iter().enumerate() {
        let mut members = member_of(&users, i * 53, 200);
        for s in &speakers {
            members.push(s.user_id.clone());
        }
        let g = me_sdk
            .create_group(name, GroupType::Normal, &members)
            .await
            .expect("创建中型群失败");
        println!("  中型群 {}: {} ({}) 成员={}", i + 1, g.group_name, g.group_id, members.len() + 1);
        all_groups.push((g.group_name, g.group_id, i));
    }

    // 3 个大型群
    for (i, (name, size)) in large_names.iter().zip([2000usize, 1500, 1200]).enumerate() {
        let mut members = member_of(&users, 700 + i * 333, size);
        for s in &speakers {
            members.push(s.user_id.clone());
        }
        let g = me_sdk
            .create_group(name, GroupType::Normal, &members)
            .await
            .expect("创建大型群失败");
        println!("  大型群 {}: {} ({}) 成员={}", i + 1, g.group_name, g.group_id, members.len() + 1);
        all_groups.push((g.group_name, g.group_id, i));
    }
    println!("  建群完成：{} 个（20 中型 + 3 大型）", all_groups.len());

    // ========== 4. 群内消息 ==========
    println!("\n========== 群内消息 ==========");
    let mut sent = 0usize;
    for (idx, (name, gid, _slot)) in all_groups.iter().enumerate() {
        // 当前用户发言 2-3 条
        send_demo_msg(&me_sdk, gid, 3, &DemoMsg::Text(format!("大家好，欢迎来到{}", name))).await;
        sent += 1;
        tokio::time::sleep(Duration::from_millis(120)).await;
        send_demo_msg(&me_sdk, gid, 3, &DemoMsg::Text("本周进展同步一下：整体按计划推进".to_string())).await;
        sent += 1;
        tokio::time::sleep(Duration::from_millis(120)).await;
        // 部分群发图片 / @我
        if idx % 5 == 0 {
            send_demo_msg(&me_sdk, gid, 3, &DemoMsg::Image("https://picsum.photos/seed/scale/400/300")).await;
            sent += 1;
        } else if idx % 7 == 3 {
            send_demo_msg(
                &speaker_sdks[1],
                gid,
                3,
                &DemoMsg::At("这个安排大家看下，有疑问随时提".to_string(), vec![me.user_id.clone()]),
            )
            .await;
            sent += 1;
        } else {
            send_demo_msg(&speaker_sdks[idx % 3], gid, 3, &DemoMsg::Text("收到，我这边没问题".to_string())).await;
            sent += 1;
        }
        tokio::time::sleep(Duration::from_millis(120)).await;
    }
    println!("  群消息发送完成：{} 条", sent);

    // ========== 5. 单聊：当前用户 ↔ 若干用户基数成员 ==========
    println!("\n========== 少量单聊（前 20 个用户基数成员）==========");
    for u in users.iter().take(20) {
        send_demo_msg(&me_sdk, &u.user_id, 1, &DemoMsg::Text(format!("你好 {}，认识一下", u.nickname))).await;
        tokio::time::sleep(Duration::from_millis(80)).await;
    }
    println!("  单聊发送完成");

    println!("\n========== 规模化种子完成 ==========");
    println!("  用户基数: {} 个", users.len());
    println!("  群聊: {} 个（20 中型 + 3 大型）", all_groups.len());
    println!("  目标账号: {} ({})", me.user_id, me.phone);
    println!("  耗时: {:.1}s", started.elapsed().as_secs_f32());
    println!("在 App 里重新登录（手机号 {} + 666666）即可看到大量群会话。", me.phone);
}

// ============ 工具 ============

enum DemoMsg {
    Text(String),
    Image(&'static str),
    At(String, Vec<String>),
}

async fn send_demo_msg(sdk: &OpenIMClient, target: &str, session_type: i32, msg: &DemoMsg) {
    let result = match msg {
        DemoMsg::Text(t) => sdk.send_text_message(t, target, session_type).await,
        DemoMsg::Image(url) => sdk.send_image_message_from_url(url, target, session_type).await,
        DemoMsg::At(t, ids) => sdk.send_at_text_message(t, ids.clone(), target, session_type).await,
    };
    if let Err(e) = result {
        println!("  发送失败 target={} err={:?}", target, e);
    }
}

fn gen_nickname(i: usize) -> String {
    const SURNAMES: [&str; 20] = [
        "张", "李", "王", "赵", "刘", "陈", "杨", "黄", "周", "吴",
        "徐", "孙", "马", "朱", "胡", "郭", "何", "高", "林", "罗",
    ];
    const GIVEN: [&str; 30] = [
        "伟", "芳", "娜", "敏", "静", "磊", "军", "洋", "勇", "艳",
        "杰", "涛", "明", "超", "霞", "平", "刚", "文", "辉", "婷",
        "志强", "秀英", "丽", "强", "斌", "雪", "晨", "子涵", "雨桐", "一诺",
    ];
    format!("{}{}{:03}", SURNAMES[i % 20], GIVEN[(i / 20) % 30], i % 1000)
}

/// 批量注册（并发）。手机号确定性生成，已存在的账号改为登录复用。
async fn register_bulk(start: usize, count: usize, concurrency: usize) -> Vec<TestAccount> {
    let semaphore = Arc::new(tokio::sync::Semaphore::new(concurrency));
    let mut handles = Vec::new();
    for i in start..(start + count) {
        let permit = semaphore.clone().acquire_owned().await.expect("semaphore");
        handles.push(tokio::spawn(async move {
            let _permit = permit;
            let phone = format!("1776{:07}", i);
            let nickname = gen_nickname(i);
            match register_user(&phone, &nickname).await {
                Ok(cert) => Some(TestAccount {
                    user_id: cert.user_id,
                    phone,
                    nickname,
                    im_token: Some(cert.im_token),
                    chat_token: Some(cert.chat_token),
                }),
                Err(_) => match login_user(&phone).await {
                    Ok(cert) => Some(TestAccount {
                        user_id: cert.user_id,
                        phone,
                        nickname,
                        im_token: Some(cert.im_token),
                        chat_token: Some(cert.chat_token),
                    }),
                    Err(e) => {
                        println!("  ⚠️ {} 注册/登录失败: {}", phone, e);
                        None
                    }
                },
            }
        }));
    }
    let mut out = Vec::with_capacity(count);
    for h in handles {
        if let Ok(Some(acc)) = h.await {
            out.push(acc);
        }
    }
    out
}