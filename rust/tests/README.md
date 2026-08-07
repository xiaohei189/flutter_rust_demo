# Rust SDK 测试方案

## 分层

| 层级 | 命令 | 耗时 | 依赖 |
| --- | --- | --- | --- |
| 单元测试 | `cargo test --lib` | 约 3s | 无 |
| 离线集成（wiremock） | `cargo test --test hermetic_tests` | 约 1s | 无 |
| 真实服务端契约冒烟 | `cargo test --test contract_tests -- --ignored --test-threads=1` | 约 30s | Docker OpenIM |
| 真实服务端集成 | `cargo test --test <suite> -- --ignored --test-threads=1` | 分钟级 | Docker OpenIM |

真实服务端套件默认被 `#[ignore]` 标记，普通 `cargo test` 只跑快速层，避免开发/CI 被慢测试拖住。

> mock 层不承担契约证明：它只验证 SDK 拿到“已知响应”后的处理逻辑。mock fixture 是否正确，必须以真实服务端响应为准；契约一致性由下面的真实服务端层负责。

保证 mock 准确的方式：

1. 以真实服务端响应为唯一事实来源，`contract_tests` 负责持续校验。
2. 建议把真实响应保存为 JSON fixtures，mock 层直接回放这些 fixtures，而不是手工拼响应。
3. 服务端升级或协议变更后，先跑 `scripts/test-contract.ps1`，再根据真实响应更新 fixtures。

## 快速入口

```powershell
powershell -ExecutionPolicy Bypass -File scripts/test-fast.ps1
```

## 全量真实服务端入口

```powershell
powershell -ExecutionPolicy Bypass -File scripts/test-integration.ps1
```

只跑快速契约冒烟（约 30s）：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/test-integration.ps1 -Mode Smoke
```

## 推荐工作流

测试按三层串成流水线，前一层是后一层的数据来源：

1. 契约确认：跑 `scripts/test-contract.ps1`，用真实服务端确认 client API 的请求字段和响应结构；必要时把真实响应保存为 fixtures。
2. mock 逻辑测试：mock 层基于已确认的 fixtures 验证 SDK 内部业务逻辑，跑 `scripts/test-fast.ps1`。
3. 完整集成：跑 `scripts/test-integration.ps1`，对 SDK 做真实服务端端到端功能验证；日常只需 `-Mode Smoke`。

契约层只在服务端版本或协议变更时重跑，mock 逻辑测试和完整集成各自按需执行。

自动重试、重连、超时、退避这类时序和状态机逻辑，放在 mock/离线层测试，通过注入网络失败、超时、被踢等故障验证重试次数、退避和最终状态；真实服务端层只做一次成功的端到端冒烟，不在真实网络上断言重试时序。

只跑某个套件：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/test-integration.ps1 -Suite message_tests
```

只跑真实服务端契约冒烟（各域代表性 client API）：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/test-contract.ps1
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
| 自动重试/指数退避/错误分类 | `src/connection/reconnect.rs`, `src/error/types.rs`, `src/message/send/sender.rs` |
| HTTP 契约（revoke/delete/read） | `src/http/message_api.rs` |

真实服务端套件负责验证与服务端/网关的契约，包括消息收发、媒体上传、群消息、离线同步、会话未读等端到端路径。
