//! 连接状态监听器

use crate::frb_generated::StreamSink;
use serde::{Deserialize, Serialize};

// 重新导出 Arc 和 Mutex，以便生成的代码通过 use crate::api::listeners::connection_status::*; 可以访问
pub use std::sync::{Arc, Mutex};

/// 连接状态事件
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ConnectionStatusEvent {
    pub connected: bool,
    pub message: String,
}

/// 连接状态监听器（桥接到 Dart）
pub struct DartConnectionStatusListener {
    pub sink: Arc<Mutex<Option<StreamSink<ConnectionStatusEvent>>>>,
}

impl DartConnectionStatusListener {
    pub fn new() -> Self {
        Self {
            sink: Arc::new(Mutex::new(None)),
        }
    }

    /// 设置连接状态 sink
    pub fn set_sink(&self, sink: StreamSink<ConnectionStatusEvent>) {
        *self.sink.lock().unwrap() = Some(sink);
    }

    /// 发送连接状态事件
    pub(crate) fn send_event(&self, event: ConnectionStatusEvent) {
        if let Ok(sink) = self.sink.lock() {
            if let Some(ref s) = *sink {
                let _ = s.add(event);
            }
        }
    }
}

