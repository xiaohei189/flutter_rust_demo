//! 事件系统 — 领域事件类型 + Listener 回调契约
//!
//! 事件流向：Service → Listener trait（唯一出口）→ EventHub → Dart StreamSink / 外部 SDK。

pub mod events;
pub mod hub;
pub mod types;

#[cfg(test)]
pub(crate) mod test_util;