mod common;

use common::*;
use rust_lib_flutter_rust_demo::domain::constant::enums::GroupType;
use rust_lib_flutter_rust_demo::sdk::client::*;
use std::time::Duration;

/// 演示消息类型（种子数据用）。
enum DemoMsg {
    Text(&'static str),
    Markdown(&'static str),
    Image(&'static str),
    At(&'static str, Vec<String>),
}

/// 给「当前登录用户」造演示数据：创建一批联系人（互加好友）、
/// 单聊会话、群聊会话并发送消息，让 App 里联系人和会话列表更真实。
///
/// 目标账号：设置环境变量 OPENIM_DEMO_TARGET_PHONE 为当前登录 App 的手机号；
/// 未设置时回退到演示主账号 17764008301。
///
/// 运行（需 Docker OpenIM 在本机 10001/10002/10008 端口）：
/// `powershell
/// cargo test --test seed_demo -- --ignored --test-threads=1 --nocapture
/// `
#[tokio::test]
#[ignore = "requires docker OpenIM server"]
async fn seed_demo_data() {
    let _ = tracing_subscriber::fmt()
        .with_max_level(tracing::Level::INFO)
        .with_target(false)
        .try_init();

    // ========== 1. 目标账号（当前登录用户） ==========
    let target_phone = std::env::var("OPENIM_DEMO_TARGET_PHONE")
        .ok()
        .filter(|s| !s.is_empty());
    let me = match &target_phone {
        Some(phone) => {
            println!("\n========== 目标账号：当前登录用户 phone={} ==========", phone);
            login_or_register_user(phone, "我").await
        }
        None => {
            println!("\n========== 未设置 OPENIM_DEMO_TARGET_PHONE，使用演示主账号 17764008301 ==========");
            login_or_register_user("17764008301", "林晚").await
        }
    };

    // ========== 2. 创建一批联系人（固定手机号，幂等） ==========
    println!("\n========== 创建联系人 ==========");
    let contacts: Vec<(&str, &str)> = vec![
        ("17764008401", "张伟"),
        ("17764008402", "李娜"),
        ("17764008403", "王强"),
        ("17764008404", "赵敏"),
        ("17764008405", "刘洋"),
        ("17764008406", "孙丽"),
        ("17764008407", "周杰"),
        ("17764008408", "吴芳"),
        ("17764008409", "苏晴"),
        ("17764008410", "陈晨"),
        ("17764008411", "杨帆"),
        ("17764008412", "黄磊"),
    ];
    let mut accounts = Vec::new();
    for (phone, nickname) in &contacts {
        let acc = login_or_register_user(phone, nickname).await;
        println!("  联系人 {} phone={} user_id={}", acc.nickname, acc.phone, acc.user_id);
        accounts.push(acc);
    }

    // ========== 3. 登录目标账号与全部联系人 SDK ==========
    println!("\n========== 登录 SDK ==========");
    let (me_token, _) = login_account(&me).await.expect("目标账号登录失败");
    let me_sdk = create_sdk(&me, &me_token).await;
    println!("  目标账号已登录: {} ({})", me.nickname, me.user_id);

    let mut others = Vec::new();
    for acc in &accounts {
        let (token, _) = login_account(acc).await.expect("联系人登录失败");
        let sdk = create_sdk(acc, &token).await;
        println!("  已登录: {} ({})", acc.nickname, acc.user_id);
        others.push((acc.clone(), sdk));
    }

    // ========== 4. 互加好友（联系人 → 我，我接受） ==========
    println!("\n========== 添加好友 ==========");
    for (acc, sdk) in &others {
        let msg = format!("你好，我是{}", acc.nickname);
        if let Err(e) = sdk.add_friend(&me.user_id, Some(&msg)).await {
            println!("  ⚠️ {} 好友申请失败(可能已是好友): {:?}", acc.nickname, e);
        }
        tokio::time::sleep(Duration::from_millis(300)).await;
        if let Err(e) = me_sdk.accept_friend_application(&acc.user_id, None).await {
            println!("  ⚠️ 接受 {} 好友失败: {:?}", acc.nickname, e);
        }
        tokio::time::sleep(Duration::from_millis(300)).await;
    }
    let _ = me_sdk.sync_friends().await;
    println!("  好友添加完成（{} 个联系人）", others.len());

    // ========== 5. 单聊会话：我 ↔ 联系人 ==========
    println!("\n========== 单聊消息 ==========");
    let scripts: Vec<(usize, Vec<DemoMsg>, &str)> = vec![
        (0, vec![DemoMsg::Text("早，昨天的方案我整体看了，没问题"), DemoMsg::Image("https://picsum.photos/seed/zhang/400/300"), DemoMsg::Text("原型图更新了一版，你空了看下")], "收到，我下午看"),
        (1, vec![DemoMsg::Text("需求评审定在明天下午三点，别忘了"), DemoMsg::Markdown("# 评审议程\n1. 登录流程\n2. 会话列表\n3. 消息收发")], "好，我准时到"),
        (2, vec![DemoMsg::Text("接口联调文档我放共享盘了"), DemoMsg::Text("有问题随时找我")], "OK，联调有问题我喊你"),
        (3, vec![DemoMsg::Text("这个月的 OKR 更新下哈")], "收到，我今晚更新"),
        (4, vec![DemoMsg::Text("新版本的测试用例我写好了"), DemoMsg::Image("https://picsum.photos/seed/liuyang/400/300")], "辛苦，我下午跑一遍"),
        (5, vec![DemoMsg::Text("周报记得今晚提交")], "好的，马上写"),
        (6, vec![DemoMsg::Text("上次说的设计稿改好了吗？")], "改好了，发你邮箱了"),
        (7, vec![DemoMsg::Text("预算审批下来了，可以推进了")], "太好了，我安排排期"),
        (8, vec![DemoMsg::Text("周末爬山的事定了吗？"), DemoMsg::Image("https://picsum.photos/seed/su/400/300")], "定了，周六早上八点集合"),
        (9, vec![DemoMsg::Text("新同事入职流程走完了，欢迎欢迎")], "谢谢！请多关照"),
        (10, vec![DemoMsg::Text("下周三有个技术分享，你来吗？"), DemoMsg::Markdown("## 主题\nRust 与 Flutter 的性能实践")], "来，我报名"),
        (11, vec![DemoMsg::Text("同学聚会定在月底，记得空出时间")], "没问题，我记下了"),
    ];

    for (idx, msgs, reply) in &scripts {
        let (acc, _) = &others[*idx];
        for m in msgs {
            send_demo_msg(&me_sdk, &acc.user_id, 1, m).await;
            tokio::time::sleep(Duration::from_millis(250)).await;
        }
        // 联系人回一条给我（产生未读）
        let (_, contact_sdk) = &others[*idx];
        send_demo_msg(contact_sdk, &me.user_id, 1, &DemoMsg::Text(reply)).await;
        tokio::time::sleep(Duration::from_millis(250)).await;
    }
    println!("  单聊会话完成（{} 个）", scripts.len());

    // ========== 6. 群聊会话 ==========
    println!("\n========== 群聊消息 ==========");
    let g1 = me_sdk
        .create_group(
            "前端需求评审",
            GroupType::Normal,
            &[
                others[0].0.user_id.clone(),
                others[1].0.user_id.clone(),
                others[2].0.user_id.clone(),
                others[4].0.user_id.clone(),
                others[7].0.user_id.clone(),
            ],
        )
        .await
        .expect("创建群1失败");
    println!("  群1: {} ({})", g1.group_name, g1.group_id);
    send_demo_msg(&others[0].1, &g1.group_id, 3, &DemoMsg::Text("群里的各位，新版本明天上线，大家留意回归")).await;
    tokio::time::sleep(Duration::from_millis(300)).await;
    send_demo_msg(&others[1].1, &g1.group_id, 3, &DemoMsg::Image("https://picsum.photos/seed/group1/400/300")).await;
    tokio::time::sleep(Duration::from_millis(300)).await;
    send_demo_msg(&others[2].1, &g1.group_id, 3, &DemoMsg::At("这个需求你确认下，明天评审用", vec![me.user_id.clone()])).await;
    tokio::time::sleep(Duration::from_millis(300)).await;
    send_demo_msg(&me_sdk, &g1.group_id, 3, &DemoMsg::Text("收到，我整理一下评审材料")).await;
    tokio::time::sleep(Duration::from_millis(300)).await;
    send_demo_msg(&others[0].1, &g1.group_id, 3, &DemoMsg::Text("辛苦，今晚前我出个排期表")).await;

    let g2 = me_sdk
        .create_group(
            "周末羽毛球",
            GroupType::Normal,
            &[
                others[8].0.user_id.clone(),
                others[9].0.user_id.clone(),
                others[10].0.user_id.clone(),
                others[11].0.user_id.clone(),
            ],
        )
        .await
        .expect("创建群2失败");
    println!("  群2: {} ({})", g2.group_name, g2.group_id);
    send_demo_msg(&others[8].1, &g2.group_id, 3, &DemoMsg::Text("周六晚上七点，老场地，别迟到")).await;
    tokio::time::sleep(Duration::from_millis(300)).await;
    send_demo_msg(&others[10].1, &g2.group_id, 3, &DemoMsg::At("你带拍子不？", vec![me.user_id.clone()])).await;
    tokio::time::sleep(Duration::from_millis(300)).await;
    send_demo_msg(&others[9].1, &g2.group_id, 3, &DemoMsg::Image("https://picsum.photos/seed/group2/400/300")).await;
    tokio::time::sleep(Duration::from_millis(300)).await;
    send_demo_msg(&me_sdk, &g2.group_id, 3, &DemoMsg::Text("带！顺便带两桶球")).await;

    let g3 = me_sdk
        .create_group(
            "同学聚会",
            GroupType::Normal,
            &[
                others[5].0.user_id.clone(),
                others[6].0.user_id.clone(),
                others[11].0.user_id.clone(),
            ],
        )
        .await
        .expect("创建群3失败");
    println!("  群3: {} ({})", g3.group_name, g3.group_id);
    send_demo_msg(&others[6].1, &g3.group_id, 3, &DemoMsg::Text("地点定在蜀都大酒店，晚上六点半")).await;
    tokio::time::sleep(Duration::from_millis(300)).await;
    send_demo_msg(&others[5].1, &g3.group_id, 3, &DemoMsg::Text("我带相册过来，大家看看老照片")).await;
    tokio::time::sleep(Duration::from_millis(300)).await;
    send_demo_msg(&me_sdk, &g3.group_id, 3, &DemoMsg::Text("没问题，我早点到")).await;

    let g4 = me_sdk
        .create_group(
            "项目管理群",
            GroupType::Normal,
            &[
                others[2].0.user_id.clone(),
                others[3].0.user_id.clone(),
                others[7].0.user_id.clone(),
                others[5].0.user_id.clone(),
            ],
        )
        .await
        .expect("创建群4失败");
    println!("  群4: {} ({})", g4.group_name, g4.group_id);
    send_demo_msg(&others[3].1, &g4.group_id, 3, &DemoMsg::Text("Q3 项目进度周会改到周四下午")).await;
    tokio::time::sleep(Duration::from_millis(300)).await;
    send_demo_msg(&others[2].1, &g4.group_id, 3, &DemoMsg::At("进度表你这边更新下", vec![me.user_id.clone()])).await;
    tokio::time::sleep(Duration::from_millis(300)).await;
    send_demo_msg(&others[7].1, &g4.group_id, 3, &DemoMsg::Image("https://picsum.photos/seed/group4/400/300")).await;
    tokio::time::sleep(Duration::from_millis(300)).await;
    send_demo_msg(&me_sdk, &g4.group_id, 3, &DemoMsg::Text("好，我下午更新到共享表")).await;

    let _ = me_sdk.sync_friends().await;

    println!("\n========== 种子数据完成 ==========");
    println!("目标账号: {} (user_id={}, phone={})", me.nickname, me.user_id, me.phone);
    println!("  - 联系人/好友：{} 个", others.len());
    println!("  - 单聊会话：{} 个（含图片/Markdown/未读回复）", scripts.len());
    println!("  - 群聊会话：4 个（含 @我 / 图片）");
    println!("重新登录 App（手机号 {} + 验证码 666666）即可看到。", me.phone);
}

async fn send_demo_msg(sdk: &OpenIMClient, target: &str, session_type: i32, msg: &DemoMsg) {
    let result = match msg {
        DemoMsg::Text(t) => sdk.send_text_message(t, target, session_type).await,
        DemoMsg::Markdown(t) => sdk.send_markdown_message(t, target, session_type).await,
        DemoMsg::Image(url) => sdk.send_image_message_from_url(url, target, session_type).await,
        DemoMsg::At(t, ids) => {
            sdk.send_at_text_message(t, ids.clone(), target, session_type).await
        }
    };
    if let Err(e) = result {
        println!("  发送失败 target={} err={:?}", target, e);
    }
}