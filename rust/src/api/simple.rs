use std::sync::Mutex;
use std::sync::OnceLock;

use tracing_subscriber::layer::SubscriberExt;
use tracing_subscriber::util::SubscriberInitExt;
use tracing_subscriber::Layer;
use tracing_subscriber::registry::LookupSpan;

use crate::frb_generated::StreamSink;

static LOG_DIR: OnceLock<String> = OnceLock::new();
static LOG_INITIALIZED: Mutex<bool> = Mutex::new(false);
static LOG_GUARD: OnceLock<tracing_appender::non_blocking::WorkerGuard> = OnceLock::new();
static LOG_SINK: OnceLock<StreamSink<String>> = OnceLock::new();

/// 获取当前设置的日志目录
fn get_log_dir() -> Option<&'static str> {
    LOG_DIR.get().map(|s| s.as_str())
}

/// 设置日志目录（应在 init_logger 前调用）
#[flutter_rust_bridge::frb]
pub fn set_log_directory(path: String) {
    let _ = LOG_DIR.set(path);
}

/// 初始化 Rust 日志系统（同时输出到文件和控制台）
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

    // 文件输出
    let file_appender = tracing_appender::rolling::daily(log_dir, "sdk.log");
    let (non_blocking_file, guard) = tracing_appender::non_blocking(file_appender);
    let _ = LOG_GUARD.set(guard);

    // 控制台输出
    let (non_blocking_console, _console_guard) = tracing_appender::non_blocking(std::io::stdout());

    // 使用 layer 同时输出到文件和控制台
    let result = tracing_subscriber::registry()
        .with(env_filter)
        .with(
            tracing_subscriber::fmt::layer()
                .with_writer(non_blocking_file)
                .with_ansi(false)
                .with_file(true)
                .with_line_number(true)
                .with_thread_ids(true)
                .with_target(true)
        )
        .with(
            tracing_subscriber::fmt::layer()
                .with_writer(non_blocking_console)
                .with_ansi(true)
        )
        .with(DartLogLayer)
        .try_init();
    
    if let Err(e) = result {
        eprintln!("日志系统初始化失败: {}", e);
        *initialized = true;
        return Ok(());
    }

    // 输出一条启动日志，验证日志系统工作
    tracing::info!("[Rust SDK] 日志系统已初始化，级别: {}", log_level);
    tracing::debug!("[Rust SDK] 调试日志已启用");

    *initialized = true;
    Ok(())
}

/// 订阅 Rust 日志流（实时推送到 Dart 侧）
#[flutter_rust_bridge::frb]
pub async fn subscribe_rust_logs(sink: StreamSink<String>) -> anyhow::Result<()> {
    let _ = LOG_SINK.set(sink);
    tracing::info!("[Rust SDK] Dart 侧已订阅日志流");
    Ok(())
}

/// 自定义 Layer：将日志转发到 StreamSink
#[flutter_rust_bridge::frb(ignore)]
struct DartLogLayer;

impl<S> Layer<S> for DartLogLayer
where
    S: tracing::Subscriber + for<'lookup> LookupSpan<'lookup>,
{
    fn on_event(
        &self,
        event: &tracing::Event<'_>,
        _ctx: tracing_subscriber::layer::Context<'_, S>,
    ) {
        if let Some(sink) = LOG_SINK.get() {
            let mut visitor = MessageVisitor::default();
            event.record(&mut visitor);
            
            let metadata = event.metadata();
            let level = metadata.level();
            let target = metadata.target();
            
            // 简化模块路径，只保留最后一部分
            let short_target = target.split("::").last().unwrap_or(target);
            
            // 获取文件和行号
            let file = metadata.file().unwrap_or("unknown");
            let line = metadata.line().unwrap_or(0);
            // 只保留文件名，去掉路径前缀
            let short_file = file.rsplit('/').next().unwrap_or(file);
            
            // 获取当前时间（毫秒精度）
            let now = chrono::Local::now();
            let timestamp = now.format("%H:%M:%S%.3f");
            
            // 构建简洁的日志格式，添加 [Rust] 前缀方便筛选
            let log_line = if visitor.fields.is_empty() {
                format!("[Rust] [{}] [{}] [{}:{}] {}: {}", level, timestamp, short_file, line, short_target, visitor.message)
            } else {
                format!("[Rust] [{}] [{}] [{}:{}] {}: {} | {}", level, timestamp, short_file, line, short_target, visitor.message, visitor.fields)
            };
            
            let _ = sink.add(log_line);
        }
    }
}

#[derive(Default)]
#[flutter_rust_bridge::frb(ignore)]
struct MessageVisitor {
    message: String,
    fields: String,
}

impl tracing::field::Visit for MessageVisitor {
    fn record_debug(&mut self, field: &tracing::field::Field, value: &dyn std::fmt::Debug) {
        if field.name() == "message" {
            self.message = format!("{:?}", value);
        } else {
            if !self.fields.is_empty() {
                self.fields.push_str(", ");
            }
            self.fields.push_str(&format!("{}={:?}", field.name(), value));
        }
    }
    
    fn record_str(&mut self, field: &tracing::field::Field, value: &str) {
        if field.name() == "message" {
            self.message = value.to_string();
        } else {
            if !self.fields.is_empty() {
                self.fields.push_str(", ");
            }
            self.fields.push_str(&format!("{}={}", field.name(), value));
        }
    }
}
