# 📖 Flutter Rust Demo — 文档总入口

> 本项目是基于 **Flutter + Rust**（flutter_rust_bridge）的 **OpenIM 即时通讯客户端**。
> 本文档是**全部项目文档的唯一入口**，按用途归类并标注时效状态，方便开发与 Agent 快速定位。

---

## ⏱ 时效状态图例

| 标记 | 含义 | 使用建议 |
|------|------|----------|
| ✅ **现行** | 与当前代码一致，可直接参考 | 正常使用 |
| 📌 **参考** | 历史设计/规划，部分可能与现状不符 | 理解设计意图时参考，**以代码为准** |
| ⚠️ **过时** | 与当前代码不符（多为早期基线） | 勿直接引用，已标注替代文档 |

> **通用原则**：涉及具体实现时，**以实际代码为准**（Dart：`lib/`；Rust：`rust/src/`）。文档与代码冲突时，代码优先。

---

## 🚀 快速上手（根目录）

| 文档 | 状态 | 说明 |
|------|------|------|
| [QUICKSTART.md](../QUICKSTART.md) | ✅ 现行 | 环境准备（Flutter / Rust / OpenIM Server）与运行步骤 |
| [README.md](../README.md) | ✅ 现行 | 项目简介 |

## 🏗️ 架构

| 文档 | 状态 | 说明 |
|------|------|------|
| [docs/architecture.md](./architecture.md) | ✅ 现行 | **当前架构与数据流**（Dart 侧已对齐 Flutter 分层规范） |
| [rust/ARCHITECTURE.md](../rust/ARCHITECTURE.md) | 📌 参考 | Rust **目标**分层（五层）；实际为扁平结构（迁移未完成） |

### 架构对齐现状（2026-08）

| 侧 | 文档描述 | 实际代码 | 对齐 |
|----|----------|----------|------|
| **Dart `lib/`** | `data/` + `domain/` + `ui/<feature>` | ✅ `data/repositories+services`、`domain/models`、`ui/{auth,chat,contacts,groups,profile,discover,shared,shell}` + `ui/core` | ✅ **已对齐** |
| **Rust `rust/src/`** | 五层：`api/sdk/core/domain/infra` | ❌ 实际为**扁平结构**（`cache, client, connection, db, ffi, ...` 平铺） | ⚠️ **未对齐**（五层为目标，迁移未完成） |

## 📚 SDK 模块规范（docs/sdk-spec/）

> ⚠️ **规格参考**：sdk-spec 的「实施状态 / ❌ 未实现」标注为**早期基线，与代码有出入**（多数已实现）。
> 功能状态的权威依据：**实际代码 + [docs/testing-gap.md](./testing-gap.md)**。协议/常量/模型等规格内容仍可参考。

17 个文档，**从 [INDEX.md](./sdk-spec/INDEX.md) 进入**：

| 分组 | 文档 | 内容 |
|------|------|------|
| 全局 | [00-OVERVIEW](./sdk-spec/00-OVERVIEW.md) | 系统全景、分层、数据流、功能清单 |
| 连接 | [01-CONNECTION](./sdk-spec/01-CONNECTION.md) | WebSocket、心跳、重连、RPC |
| 消息 | [02-MESSAGE-SYNC](./sdk-spec/02-MESSAGE-SYNC.md) [03-MESSAGE-HANDLER](./sdk-spec/03-MESSAGE-HANDLER.md) [04-MESSAGE-SENDER](./sdk-spec/04-MESSAGE-SENDER.md) | 同步 / 入库 / 发送 |
| 会话 | [05-CONVERSATION](./sdk-spec/05-CONVERSATION.md) | 会话 CRUD、已读、撤回/删除 |
| 通知 | [06-NOTIFICATION](./sdk-spec/06-NOTIFICATION.md) | 通知路由（41 种） |
| 业务 | [07-FRIEND](./sdk-spec/07-FRIEND.md) [08-GROUP](./sdk-spec/08-GROUP.md) [09-USER](./sdk-spec/09-USER.md) | 好友 / 群组 / 用户 |
| 参考 | [10-CONSTANTS](./sdk-spec/10-CONSTANTS.md) [11-DATA-MODELS](./sdk-spec/11-DATA-MODELS.md) [12-HTTP-API](./sdk-spec/12-HTTP-API.md) [13-SYNCER-FRAMEWORK](./sdk-spec/13-SYNCER-FRAMEWORK.md) | 常量 / 模型 / HTTP API / 同步器框架 |
| 生命周期 | [14-SDK-LIFECYCLE](./sdk-spec/14-SDK-LIFECYCLE.md) | Login / Logout / Token |
| 桥接 | [15-FFI-BRIDGE](./sdk-spec/15-FFI-BRIDGE.md) | FFI 函数与 Go SDK API 对照 |
| 事件 | [16-LISTENERS](./sdk-spec/16-LISTENERS.md) | 6 个 Listener trait 回调体系（最新） |

## 📋 开发规范与进度

| 文档 | 状态 | 说明 |
|------|------|------|
| [CLAUDE.md](../CLAUDE.md) | ✅ 现行 | **Agent 开发规范**（分层架构、编码、提交规范） |
| [AGENTS.md](../AGENTS.md) | ✅ 现行 | **仓库指南**（模块结构、命令、风格） |
| [docs/conventions.md](./conventions.md) | ✅ 现行 | 命名 / 目录 / 提交等编码规范 |
| [docs/SDK_PROGRESS.md](./SDK_PROGRESS.md) | ⚠️ 部分过时 | SDK 进度（大量 ✅ 为规划估算，**以 testing-gap.md + 代码为准**） |
| [docs/testing-gap.md](./testing-gap.md) | ✅ 现行 | **测试缺口与状态矩阵**（文档冲突的权威裁决） |
| [docs/ui-optimization-plan.md](./ui-optimization-plan.md) | 📌 参考 | UI 与目录组织优化计划（已大部分落地） |
| [rust/tests/README.md](../rust/tests/README.md) | ✅ 现行 | Rust 测试说明 |

## 🔬 专项实现说明（docs/ 下）

| 文档 | 状态 | 说明 |
|------|------|------|
| [docs/RUST_API_IMPLEMENTATION.md](./RUST_API_IMPLEMENTATION.md) | 📌 参考 | Rust API 与 Go SDK 对照 |
| [docs/MESSAGE_LOADING_IMPLEMENTATION.md](./MESSAGE_LOADING_IMPLEMENTATION.md) | 📌 参考 | 消息加载实现（对照 Go SDK） |
| [docs/FILE_UPLOAD_IMPLEMENTATION.md](./FILE_UPLOAD_IMPLEMENTATION.md) | 📌 参考 | 文件/头像上传实现 |
| [docs/AVATAR_UPDATE.md](./AVATAR_UPDATE.md) | 📌 参考 | 头像系统更新说明 |
| [docs/go_ws_message_handling.md](./go_ws_message_handling.md) | 📌 参考 | Go SDK WebSocket 消息处理链路 |
| [docs/message_flow_analysis.md](./message_flow_analysis.md) | 📌 参考 | 消息收发全链路分析 |

## 📦 归档（docs/archive/）

以下为**历史文档**，内容多为早期骨架/规划，**仅作历史参考，勿直接引用**：

| 文档 | 原位置 | 说明 |
|------|--------|------|
| [ARCHITECTURE.md](./archive/ARCHITECTURE.md) | 根目录 | 早期骨架架构（setState/screens），已过时 |
| [项目架构以及规划信息.md](./archive/项目架构以及规划信息.md) | 根目录 | 早期项目规划 |
| [CHAT_APP_README.md](./archive/CHAT_APP_README.md) | 根目录 | 早期聊天应用骨架说明 |
| [openim_demo功能清单报告.md](./archive/openim_demo功能清单报告.md) | 根目录 | 与官方 demo 的功能对比报告 |
| [SDK_ARCHITECTURE_REDESIGN.md](./archive/SDK_ARCHITECTURE_REDESIGN.md) | rust/ | SDK 重构设计（历史，95KB） |
| [SDK_IMPLEMENTATION_PLAN.md](./archive/SDK_IMPLEMENTATION_PLAN.md) | rust/ | SDK 实施计划（历史） |
| [REFACTORING_PLAN.md](./archive/REFACTORING_PLAN.md) | rust/ | Rust 重构计划 |

## 🧰 Agent 技能（.agents/skills/）

项目内置 22 个 Dart/Flutter 开发技能（`SKILL.md`），供 Agent 使用：

| 类别 | 技能 |
|------|------|
| Dart | 单元测试、静态分析、修复运行时错误、覆盖率、FFI（ffigen/native-assets）、CLI、模式匹配、主构造器、mock、checks 迁移、包冲突 |
| Flutter | 架构分层、响应式布局、修复布局、JSON 序列化、路由、本地化、HTTP、集成测试、Widget 测试、Widget 预览 |

技能详情见 `.agents/skills/<name>/SKILL.md`。

---

## ⚠️ 已知文档冲突（以代码为准）

| 冲突点 | 位置 | 处理 |
|--------|------|------|
| Rust 侧结构：文档写五层（api/sdk/core/domain/infra） | docs/architecture.md、rust/ARCHITECTURE.md、CLAUDE.md | **实际为扁平结构**；五层是目标，迁移未完成 |
| sdk-spec 大量「❌ 未实现」实为已实现 | sdk-spec/00、05、07、08、09、15 等 | 已加警示；以代码 + testing-gap.md 为准 |
| SDK_PROGRESS.md 大量功能标 ✅ | docs/SDK_PROGRESS.md | 与代码有出入，已加警示；以 testing-gap.md 为准 |

---

## 🧭 推荐阅读顺序

| 读者 | 路径 |
|------|------|
| **新人上手** | QUICKSTART → docs/architecture.md → sdk-spec/00-OVERVIEW → sdk-spec/16-LISTENERS |
| **开发/改 Dart** | docs/architecture.md → docs/conventions.md → `lib/ui/<feature>/` 实际代码 |
| **开发/改 Rust SDK** | docs/architecture.md → CLAUDE.md → sdk-spec/INDEX.md（按需查模块）→ `rust/src/` 实际代码 |
| **了解现状/排查** | docs/testing-gap.md → docs/SDK_PROGRESS.md（对照）→ sdk-spec/00-OVERVIEW |
| **Agent 使用** | AGENTS.md（仓库指南）→ CLAUDE.md（规范）→ docs/README.md（本文档导航）→ 按需查 sdk-spec |

---

> 维护提示：新增文档请在本文档登记；文档收拢统一放入 `docs/archive/`；涉及事件体系请以 16-LISTENERS.md 为准。
