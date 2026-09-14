# Repository Guidelines

## Project Structure & Module Organization

This repository is an OpenIM instant messaging client built with Flutter + Rust (`flutter_rust_bridge`).

- `lib/` - Flutter UI and Dart services: screens, widgets, Riverpod providers, and models.
- `lib/generated/rust/` - flutter_rust_bridge 与 Freezed 自动生成代码，禁止手改，由 codegen/build_runner 重新生成。
- `rust/` - Rust SDK core（当前为扁平结构：`client/connection/conversation/event/ffi/friend/group/message/user` 等；目标五层 `api/sdk/core/domain/infra` 尚未迁移）。
- `rust/tests/` - Rust integration suites and JSON fixtures used by offline mock tests.
- `test/` and `integration_test/` - Flutter unit/widget and integration tests.
- `docs/` - Documentation entry point (`docs/README.md`), SDK specs in `docs/sdk-spec/`, and conventions in `docs/conventions.md`.
- `scripts/` and `rust/scripts/` - Device and test-tier helper scripts.

## 架构边界（强制）

所有改动必须遵守以下依赖与分层规则，违反即视为不合规：

- Dart 依赖方向固定为 `UI (lib/ui) -> Domain (lib/domain) -> Data (lib/data) -> generated/rust`。`lib/data` 与 `lib/domain` 禁止 import `lib/ui/` 或 `lib/providers/`。
- FFI 调用只能出现在 `lib/data/` 与 `lib/main.dart`。`lib/ui/` 与 `lib/providers/` 禁止 import `generated/rust/ffi/` 和 `generated/rust/client/`；所有 Rust 调用必须经 Service/Repository。
- View 与 ViewModel 只能依赖 Repository/Provider，禁止直接调用 FFI、生成客户端或 Service 单例。
- 每个领域只保留一个状态源；派生状态用 Provider + `select`，禁止用 `ref.listen` 把全局状态复制进本地 Notifier（纯展示格式化除外）。
- Flutter 侧遵循 Flutter 官方/业界分层（UI / Application / Domain / Data）：Service 由 Riverpod Provider 持有实例并注入使用；仅在需要依赖反转或单测替换的边界（Repository、Rust 客户端桥）提供抽象接口，不为所有 Service 强制接口样板。
- 业务 Provider 禁止直接返回 `X.instance`；基础设施单例仅在 `lib/providers/im_providers.dart` 的 Provider 桥中暴露。
- Repository 返回 Domain Model；存量直接把 generated model 暴露给 UI 的代码应逐步迁移，新增代码禁止新增该泄漏。
- 提交前必须运行边界检查（或直接执行 `scripts/check-architecture.ps1`）：
  - `rg -n "generated/rust/(ffi|client)" lib/ui lib/providers --glob "!lib/generated/**"` 结果必须为空（`lib/main.dart` 的启动初始化除外）。
  - `rg -n "from '\.\./ui/|from '\.\./providers/|ui/core/utils/app_logger" lib/data lib/domain` 结果必须为空。

## Build, Test, and Development Commands

- `flutter pub get` - Install Dart dependencies.
- `flutter run -d <device>` - Run the app.
- `flutter analyze` - Static analysis for Dart.
- `flutter test test` - Run Flutter unit/widget tests.
- `cargo test --lib` / `cargo clippy --all-targets` - Fast Rust unit tests and lint checks.
- `rust/scripts/test-fast.ps1` - Fast Rust checks: unit tests, hermetic tests, and clippy.
- `rust/scripts/test-integration.ps1 -Mode Smoke` - Real OpenIM server smoke tests; `-Suite message_tests` runs one suite. Requires Docker OpenIM (ports 10001/10002/10008).
- `flutter_rust_bridge_codegen generate` - Regenerate FFI bindings after Rust API changes.
- `dart run build_runner build` - Regenerate Freezed/JSON models after model changes.

## Coding Style & Naming Conventions

- Dart files are `snake_case.dart`; classes are `PascalCase`, members `camelCase`, globals `kCamelCase`; prefer single quotes and `const`.
- Rust files/functions are `snake_case`, structs/enums `PascalCase`, constants `SCREAMING_SNAKE_CASE`; `rustfmt.toml` sets `max_width = 200`.
- Use `AppTheme` for colors, `appLog.i('[Module] description')` for logging, Chinese error messages, `SdkError` in core, and `anyhow::Error` at the FFI boundary.
- Details: `docs/conventions.md`.

## Testing Guidelines

Tests are layered; real-server suites are `#[ignore]`d and run only via scripts.

- Contract tests: verify Rust HTTP/API behavior against a real OpenIM server.
- Hermetic tests: replay `rust/tests/fixtures/` JSON with wiremock for offline logic tests; fixtures must match real server responses.
- Integration tests: end-to-end against the real server, always serial with `--test-threads=1`.
- Unit tests live next to the code (`#[cfg(test)]`); integration suites use `*_tests.rs` naming.
- Run `test-fast.ps1` before every commit; run contract tests after server/protocol changes.

### 迭代节奏（强制，2026-09 起）

功能迭代追求"改完立刻看到效果"，不要把时间花在重复的重建与全量测试上：

- **默认走热更新**：`flutter run -d <device>` 常驻，Dart 改动按 `r` 热重载（约 1~3s）。
  只有 Rust 改动、依赖/原生配置改动、或需要真机安装包时才 `flutter build apk` + `adb install`
  （模拟器一次构建 50~100s，冷启动 3~4min）。
- **UI/样式/文案改动不跑测试**：热重载看一眼真实渲染即可（比单测更可信），迭代期零测试开销。
- **只有逻辑改动才跑相关单文件**：状态机/reducer/view_model/mapper/排序/发送链路这类
  "看不出对错"的改动，跑 `flutter test test/<对应测试文件>.dart`（Rust 用
  `cargo test --lib <模块名>`）。注意 `flutter test` 有约 5s 固定开销（起测试宿主 + 编译
  测试内核），与用例条数基本无关，所以只挑真正相关的一两个文件。
- **全量测试按需手动触发**：`flutter test test`（约 40s）与 `cargo test --lib`（约 1min）
  只在用户要求、或改动涉及跨模块/协议/持久化等高风险面时执行；**不作为默认迭代步骤，
  也不作为每次提交的前置条件**。提交信息里说明测试结论时，写清实际跑了哪些。
- 静态检查同理：迭代中按目录跑（`flutter analyze lib/ui/chat`），全量 `flutter analyze lib test` 按需。

## Commit & Pull Request Guidelines

- Commit messages follow `type: Chinese description` (e.g., `fix: 历史消息排序对齐 Go 策略`).
- Allowed types: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`, `debug`, `log`, `optimize`.
- Branch from `main` as `feat/xxx` or `fix/xxx` for non-trivial changes.
- PRs should describe the change, reference the Go SDK contract where relevant, note real-server test results, and include screenshots for UI changes.
