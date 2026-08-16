# Rust SDK 目录结构重构计划

## 问题

当前 DDD 分层对 SDK 过重，主要问题：
1. domain/ports/ + infra/http/ 两层 trait 定义 → 实现，纯冗余
2. domain/repository/ + infra/database/ 两层 trait 定义 → 实现，纯冗余
3. domain/sdk_api/ + sdk/ 两层 trait 定义 → 实现，纯冗余
4. 文件分散在 6 个顶层目录，实际功能模块被拆散

## 目标结构

`
rust/src/
├── lib.rs              # 模块声明
├── frb_generated.rs    # 自动生成
├── ffi/                # FFI 桥接层 (was api/)
├── client/             # SDK 门面 (was sdk/ + domain/sdk_api/)
├── connection/         # WS 连接管理 (was core/connection/)
├── message/            # 消息收发 (was core/message/)
├── conversation/       # 会话管理 (was core/conversation/)
├── friend/             # 好友管理 (was core/friend/)
├── group/              # 群组管理 (was core/group/)
├── user/               # 用户管理 (was core/user/)
├── file/               # 文件上传 (was core/file/ + infra/file/)
├── event/              # 事件系统 (was event/)
├── http/               # HTTP 客户端 + API (was infra/http/ + domain/ports/)
├── db/                 # SQLite DAO (was infra/database/ + domain/repository/)
├── cache/              # 内存缓存 (was infra/cache/)
├── logger/             # 日志 (was infra/logger/)
├── model/              # 数据模型 (was domain/model/)
├── error/              # 错误类型 (was domain/error/)
├── constant/           # 常量 (was domain/constant/)
└── util.rs             # 工具函数 (was domain/util.rs)
`

## 核心变更

### 1. 删除 trait 间接层

| 当前 | 重构后 | 说明 |
|------|--------|------|
| domain/ports/ 8 个 trait | 删除 | 请求/响应 DTO 合并到 http/ 模块内 |
| domain/repository/ 8 个 trait | 删除 | DAO 方法直接调用，不经过 trait |
| domain/sdk_api/ 6 个 trait | 删除 | OpenIMClient 方法直接暴露给 ffi/ |

### 2. 层级扁平化

| 当前 | 重构后 | import 变更 |
|------|--------|-------------|
| core/connection/ | connection/ | crate::core::connection:: → crate::connection:: |
| core/message/ | message/ | crate::core::message:: → crate::message:: |
| core/conversation/ | conversation/ | 同上 |
| core/friend/ | friend/ | 同上 |
| core/group/ | group/ | 同上 |
| core/user/ | user/ | 同上 |
| core/file/ + infra/file/ | file/ | 合并两个 file 目录 |
| infra/database/ | db/ | crate::infra::database:: → crate::db:: |
| infra/http/ | http/ | crate::infra::http:: → crate::http:: |
| infra/cache/ | cache/ | crate::infra::cache:: → crate::cache:: |
| infra/logger/ | logger/ | crate::infra::logger:: → crate::logger:: |
| domain/model/ | model/ | crate::domain::model:: → crate::model:: |
| domain/error/ | error/ | crate::domain::error:: → crate::error:: |
| domain/constant/ | constant/ | crate::domain::constant:: → crate::constant:: |
| sdk/ + domain/sdk_api/ | client/ | crate::sdk:: → crate::client:: |
| api/ | ffi/ | crate::api:: → crate::ffi:: |

## 执行计划（6 个 Phase）

### Phase 1: 基础设施层迁移
创建新目录，移动不依赖 trait 的模块：
- domain/model/ → model/
- domain/error/ → error/
- domain/constant/ → constant/
- infra/cache/ → cache/
- infra/logger/ → logger/
- infra/file/ → file/（暂存，后续与 core/file/ 合并）
- domain/util.rs → util.rs

### Phase 2: 数据访问层迁移（删除 repository trait）
- infra/database/ → db/
- domain/repository/ trait 内联到 db/ 模块中
- 更新 core/ 中对 Arc<dyn Repository> 的引用改为直接使用 DAO

### Phase 3: HTTP API 层迁移（删除 port trait）
- infra/http/ → http/
- domain/ports/ trait 内联到 http/ 模块中
- core/ 直接依赖 HttpXxxApi 结构体

### Phase 4: 核心业务层迁移
- core/connection/ → connection/
- core/message/ → message/
- core/conversation/ → conversation/
- core/friend/ → friend/
- core/group/ → group/
- core/user/ → user/
- core/file/ 合并到 file/

### Phase 5: SDK 门面 + FFI 迁移
- sdk/ + domain/sdk_api/ → client/
- api/ → ffi/
- 删除 domain/sdk_api/ trait

### Phase 6: 清理验证
- 删除空目录 domain/ infra/ core/ sdk/ api/
- 更新 lib.rs 模块声明
- 编译验证 + 测试验证
