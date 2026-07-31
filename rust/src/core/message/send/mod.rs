//! ② 发送管道: Client → [Queue] → Connection → Server

mod queue;

pub use queue::MessageSendQueue;
