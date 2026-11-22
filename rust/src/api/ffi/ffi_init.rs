use std::sync::Mutex;
use std::sync::OnceLock;

use crate::infra::logger::{self, LogConfig};

static LOG_INITIALIZED: Mutex<bool> = Mutex::new(false);
static LOG_CONFIG: OnceLock<LogConfig> = OnceLock::new();

/// 设置日志目录（应在 init_logger 前调用）
#[flutter_rust_bridge::frb]
pub fn set_log_directory(path: String) {
    let mut config = LogConfig::default();
    config.log_file_path = path;
    let _ = LOG_CONFIG.set(config);
}

/// 初始化 Rust 日志系统（兼容旧接口，内部委托给 init_otel_subscriber）
#[flutter_rust_bridge::frb]
pub async fn init_logger(log_level: String) -> anyhow::Result<()> {
    let mut initialized = LOG_INITIALIZED.lock().unwrap_or_else(|e| e.into_inner());
    if *initialized {
        return Ok(());
    }

    let mut config = LOG_CONFIG.get().cloned().unwrap_or_default();
    let trimmed = log_level.trim();
    if trimmed.contains(',') || trimmed.contains('=') {
        // EnvFilter 风格表达式（如 "info,rust_lib_flutter_rust_demo=debug"）：
        // 由 init_otel_subscriber 合并进 EnvFilter，基础级别取 info
        logger::set_env_filter_override(trimmed);
        config.log_level = 2;
    } else {
        config.log_level = match trimmed.to_lowercase().as_str() {
            "trace" => 0,
            "debug" => 1,
            "info" => 2,
            "warn" => 3,
            "error" => 4,
            _ => 2,
        };
    }

    logger::init_otel_subscriber(&config)?;
    *initialized = true;
    Ok(())
}

/// 初始化日志系统（完整配置）
#[flutter_rust_bridge::frb]
pub async fn init_logger_v2(config: LogConfig) -> anyhow::Result<()> {
    let mut initialized = LOG_INITIALIZED.lock().unwrap_or_else(|e| e.into_inner());
    if *initialized {
        return Ok(());
    }
    logger::init_otel_subscriber(&config)?;
    *initialized = true;
    Ok(())
}

/// 设置是否打印 span 进入/退出事件（可在 init_logger 前后调用）
///
/// 启用后，每个 #[tracing::instrument] 注解的方法在进入和退出时都会输出日志，
/// 即使方法内部没有手动调用 info!() 等宏。
/// 运行时也可切换，立即生效。
#[flutter_rust_bridge::frb]
pub fn set_log_span_events(enabled: bool) {
    let config = LOG_CONFIG.get();
    if let Some(c) = config {
        let mut updated = c.clone();
        updated.is_log_span_events = enabled;
        let _ = LOG_CONFIG.set(updated);
    } else {
        let mut c = LogConfig::default();
        c.is_log_span_events = enabled;
        let _ = LOG_CONFIG.set(c);
    }
    logger::set_span_events_enabled(enabled);
}
