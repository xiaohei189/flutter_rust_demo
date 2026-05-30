use std::sync::Mutex;
use std::sync::OnceLock;

static LOG_DIR: OnceLock<String> = OnceLock::new();
static LOG_INITIALIZED: Mutex<bool> = Mutex::new(false);
static LOG_GUARD: OnceLock<tracing_appender::non_blocking::WorkerGuard> = OnceLock::new();

/// 获取当前设置的日志目录
fn get_log_dir() -> Option<&'static str> {
    LOG_DIR.get().map(|s| s.as_str())
}

/// 设置日志目录（应在 init_logger 前调用）
#[flutter_rust_bridge::frb]
pub fn set_log_directory(path: String) {
    let _ = LOG_DIR.set(path);
}

/// 初始化 Rust 日志系统
#[flutter_rust_bridge::frb]
pub async fn init_logger(log_level: String) -> anyhow::Result<()> {
    let mut initialized = LOG_INITIALIZED.lock().unwrap();
    if *initialized {
        return Ok(());
    }

    let log_dir = get_log_dir().unwrap_or(".");
    let _ = std::fs::create_dir_all(log_dir);

    let level_filter: tracing_subscriber::filter::LevelFilter = match log_level.to_lowercase().as_str() {
        "trace" => tracing_subscriber::filter::LevelFilter::TRACE,
        "debug" => tracing_subscriber::filter::LevelFilter::DEBUG,
        "info" => tracing_subscriber::filter::LevelFilter::INFO,
        "warn" => tracing_subscriber::filter::LevelFilter::WARN,
        "error" => tracing_subscriber::filter::LevelFilter::ERROR,
        _ => tracing_subscriber::filter::LevelFilter::INFO,
    };

    let env_filter = tracing_subscriber::EnvFilter::builder()
        .with_default_directive(level_filter.into())
        .from_env_lossy();

    let file_appender = tracing_appender::rolling::daily(log_dir, "sdk.log");
    let (non_blocking_file, guard) = tracing_appender::non_blocking(file_appender);
    let _ = LOG_GUARD.set(guard);

    let _ = tracing_subscriber::fmt()
        .with_env_filter(env_filter)
        .with_writer(non_blocking_file)
        .with_ansi(false)
        .try_init();

    *initialized = true;
    Ok(())
}
