//! 向后兼容层 — 实现已移入 event::listener
//! frb_generated 自动生成代码依赖此路径，不可删除

pub use crate::event::listener::connection as connection;
pub use crate::event::listener::conversation as conversation;
pub use crate::event::listener::friend as friend;
pub use crate::event::listener::group as group;
pub use crate::event::listener::message as message;
pub use crate::event::listener::user as user;
pub use crate::event::listener::bridge as bridge;