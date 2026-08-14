# Rust SDK / Flutter 测试缺口与状态矩阵

> 目的：把“功能为空、行为异常、与 Go 差异大”变成可核对的状态，而不是主观判断。
> 原则：真实服务端契约是唯一事实来源；mock fixture 必须回放真实响应。

## 1. 当前基线

| 层 | 命令 | 结果 |
| --- | --- | --- |
| Rust 单元 | `cargo test --lib` | 396 passed |
| Rust 离线集成 | `cargo test --test hermetic_tests` | 8 passed |
| Rust 契约套件 | `cargo test --test contract_tests -- --ignored` | 5 个用例，需 Docker OpenIM |
| Rust lint | `cargo clippy --all-targets -- -D warnings` | 0 issues |
| Flutter 单元/Widget | `flutter test test` | 165 passed |
| Flutter 覆盖率 | `dart run tool/check_coverage.dart 10` | 13.07%（最低 10%） |
| Flutter E2E | `integration_test/simple_test.dart` | 仅启动到登录页 |
| Rust 真实服务端全量集成 | `rust/scripts/test-integration.ps1 -Mode Full` | 75 passed（3+20+6+9+22+8+7） |

## 2. 状态分类

| 状态 | 含义 | 后续动作 |
| --- | --- | --- |
| `implemented` | 代码已实现，且有测试 | 回归保护 |
| `implemented_untested` | 代码已实现，但没有行为测试 | 按优先级补测试 |
| `stub_rust` | Rust 明确只做占位/默认空实现 | 在矩阵标注原因，不当作缺口 |
| `stub_go` | Go SDK 本身是 stub 或返回错误 | 不追平，契约测试锁住现状 |
| `diff` | 与 Go SDK 行为存在真实差异 | 契约 + 离线差分测试 |
| `missing` | 确实缺失 | 先定范围，再实现或明确不实现 |

## 3. 当前高风险缺口

| 功能 | Go 参考 | Rust 位置 | 状态 | 建议测试 |
| --- | --- | --- | --- | --- |
| 在线状态订阅/退订 | `ws 2005` + HTTP stub | `rust/src/user/online/service.rs` | `implemented` | WS 成功、WS 失败回退 HTTP、缓存、事件、重连重订阅 |
| WS 在线状态响应路由 | Go `PushUserOnlineStatus` | `rust/src/connection/reader.rs` | `implemented` | 带 `msg_incr` 走 RPC，不带走用户状态推送 |
| WebSocket RPC | Go `long_conn_mgr.go` | `rust/src/connection/rpc.rs` | `implemented`（解码分支已测） | 超时、错误码、解码失败、channel 关闭 |
| max seq / 消息拉取 RPC | Go `msg_sync.go` | `rust/src/connection/sync_server.rs` | `implemented_untested` | 请求构造、错误传播、重试 |
| 消息已读 | Go `read_drawing.go` | `rust/src/message/operate.rs` | `implemented`（含全量已读） | 本地标记、服务端失败回滚 |
| 消息撤回 | Go `revoke.go` | `rust/src/message/operate.rs` | `implemented` | seq=0 等待、服务端失败、引用消息 |
| 本地消息搜索 | Go `search.go` | `rust/src/message/operate.rs` | `implemented` | 过滤条件、分页、软删除排除 |
| 上传进度/分片 | Go `upload.go` | `rust/src/file/progress_reader.rs`、`file/upload/session.rs` | `implemented_untested` | 进度回调、分片 md5、重试 |
| 通知分发 | Go `notification.go` | `rust/src/message/notification.rs` 等 | `implemented`，hermetic 覆盖不足 | 用真实 protobuf 样例做离线通知路由 |
| 消息同步 | Go `msg_sync.go` | `rust/src/message/receive/syncer.rs` | `implemented` | 连续/断档/重连/唤醒场景 |
| 离线未读 | 服务端按 `num` 只返回区间末尾，需分片 | `rust/src/message/receive/syncer.rs` | `implemented` | `pull_num=1` 时逐 seq 独立请求，避免同会话多 `SeqRange` 覆盖 |

## 4. 文档冲突

| 文档 | 冲突点 | 处理 |
| --- | --- | --- |
| `docs/SDK_PROGRESS.md` | 大量 API 标 `✅` | 以实际代码 + 契约为准 |
| `docs/sdk-spec/05-CONVERSATION.md` | 撤回/已读/删除仍标“未实现” | 已实现，需更新或标记为历史文档 |
| `docs/sdk-spec/08-GROUP.md` | 群组通知等标“缺失” | 代码已实现，需更新 |
| `docs/sdk-spec/15-FFI-BRIDGE.md` | 大量 FFI 标 `❌`，与 SDK_PROGRESS 冲突 | 逐项核对 FFI 入口后统一 |

## 5. 测试执行入口

```powershell
# 快速层
powershell -ExecutionPolicy Bypass -File rust/scripts/test-fast.ps1

# 真实服务端契约（需要 Docker OpenIM）
powershell -ExecutionPolicy Bypass -File rust/scripts/test-contract.ps1

# 真实服务端集成
powershell -ExecutionPolicy Bypass -File rust/scripts/test-integration.ps1 -Mode Smoke

# Flutter
flutter analyze
flutter test test
flutter test --coverage
```
