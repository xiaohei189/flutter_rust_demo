//! ② 发送管道: Client → [Queue] → Connection → Server

mod queue;
pub(crate) mod sender;

pub use queue::MessageSendQueue;
pub use sender::MessageSender;
