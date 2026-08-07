# Rust SDK 测试方案

## 分层

| 层级 | 命令 | 耗时 | 依赖 |
| --- | --- | --- | --- |
| 单元测试 | `cargo test --lib` | 约 3s | 无 |
| 离线集成（wiremock） | `cargo test --test hermetic_tests` | 约 1s | 无 |
| 真实服务端集成 | `cargo test --test <suite> -- --ignored --test-threads=1` | 分钟级 | Docker OpenIM |

真实服务端套件默认被 `#[ignore]` 标记，普通 `cargo test` 只跑快速层，避免开发/CI 被慢测试拖住。

## 快速入口

```powershell
powershell -ExecutionPolicy Bypass -File scripts/test-fast.ps1
```

## 全量真实服务端入口

```powershell
powershell -ExecutionPolicy Bypass -File scripts/test-integration.ps1
```

只跑某个套件：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/test-integration.ps1 -Suite message_tests
```

固定账号的套件必须串行，否则同账号并发会互相踢下线；`message_tests` 使用随机账号，但并行时离线同步偶发失败，因此脚本统一使用 `--test-threads=1`。

## 消息核心流程覆盖

消息模块的快速层已覆盖以下核心流程，均在内存 SQLite + mock 依赖下运行：

| 功能 | 主要测试位置 |
| --- | --- |
| 文本/媒体发送、发送队列高低 Lane | `src/message/send/sender.rs`, `src/message/send/queue.rs` |
| 发送成功/失败/超时/在线-only | `src/message/send/sender.rs` |
| 本地插入、撤回、删除、软删除 | `src/message/operate.rs`, `src/message/operate/delete.rs`, `src/message/operate/query.rs` |
| 历史消息正序/倒序/按 seq/按 ID | `src/message/operate/query.rs` |
| 搜索、未读数、已读回执 | `src/message/operate.rs`, `src/message/receive/receipt.rs` |
| 通知分发、撤回通知、群申请通知 | `src/message/notification.rs`, `src/message/receive/revoke.rs` |
| 消息去重、gap 校验、增量/重连同步 | `src/message/receive/processor.rs`, `src/message/receive/syncer.rs`, `src/message/receive/checker.rs` |
| HTTP 契约（revoke/delete/read） | `src/http/message_api.rs` |

真实服务端套件负责验证与服务端/网关的契约，包括消息收发、媒体上传、群消息、离线同步、会话未读等端到端路径。
