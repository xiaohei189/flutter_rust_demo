---
name: project-related-repos
description: Related repositories and their roles in the local development environment
metadata:
  type: project
---

## 相关仓库

| 路径 | 角色 |
|------|------|
| `D:\workspace\openim-docker` | 本地启动的 Docker 服务（一键启动整个环境） |
| `D:\workspace\chat-server` | 应用服务源码（业务逻辑层服务） |
| `D:\workspace\open-im-server` | IM 服务源码（即时通讯核心服务） |
| `D:\workspace\openim-sdk-core` | 官方 Go 版 SDK（参考实现） |
| `D:\workspace\openim-flutter-demo` | 官方 Flutter Demo（参考 UI 实现） |
| `D:\workspace\flutter_rust_demo` | **当前项目** — Rust + Flutter 实现的 IM 应用 |

**Why:** 本地开发环境依赖这些 Docker 服务，且 Rust SDK 实现参考了 Go 版 SDK 的接口设计。
**How to apply:** 在需要对接 API、参考实现、或排查服务端问题时，可以直接查看对应仓库的源码。
