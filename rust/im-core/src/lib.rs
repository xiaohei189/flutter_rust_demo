//! Platform-neutral OpenIM SDK core.
//!
//! This crate owns connection, protocol, persistence, domain and event logic.
//! Flutter and NSH integrations must depend on this crate through their own
//! binding layers and must not be referenced from here.

#![allow(clippy::redundant_field_names)]

pub mod core;
pub mod domain;
pub mod infra;
pub mod sdk;

pub use openim_protocol::sdkws::{MsgData, OfflinePushInfo, PullMsgs};
