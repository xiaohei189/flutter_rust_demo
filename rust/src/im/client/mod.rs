pub mod callbacks;
pub mod client;
pub mod friend_sync;

pub mod connection_handle;
pub mod conversation_handle;
pub mod message_handle;
pub mod reconnect;

pub use callbacks::ClientCallbacks;
pub use client::IMClient;
pub use conversation_handle::{ConvCmd, ConvCmdKind, ConversationHandle};
pub use friend_sync::FriendSyncer;
pub use reconnect::{ConnectFatalError, ReconnectStrategy};
