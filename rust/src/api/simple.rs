use std::sync::Mutex;
use std::sync::OnceLock;

use tracing_subscriber::layer::SubscriberExt;
use tracing_subscriber::util::SubscriberInitExt;

// Android 平台：通过 JNI 写入 logcat
#[cfg(target_os = "android")]
mod android_logcat {
    use std::cell::RefCell;
    use std::ffi::CString;
    use std::io::Write;

    const LOG_TAG: &str = "RustSDK";

    // Android log priority
    const ANDROID_LOG_DEBUG: i32 = 3;
    const ANDROID_LOG_INFO: i32 = 4;
    const ANDROID_LOG_WARN: i32 = 5;
    const ANDROID_LOG_ERROR: i32 = 6;

    extern "C" {
        fn __android_log_write(prio: i32, tag: *const std::os::raw::c_char, text: *const std::os::raw::c_char) -> i32;
    }

    /// 单行写入 logcat 的 Writer
    pub struct LogcatWriter {
        priority: i32,
        buf: RefCell<Vec<u8>>,
    }

    impl LogcatWriter {
        pub fn new(priority: i32) -> Self {
            Self { priority, buf: RefCell::new(Vec::with_capacity(512)) }
        }

        fn ansi_prefix(&self) -> &'static [u8] {
            match self.priority {
                6 => b"\x1B[31m",  // ERROR → 红色
                5 => b"\x1B[33m",  // WARN  → 黄色
                4 => b"\x1B[32m",  // INFO  → 绿色
                _ => b"\x1B[36m",  // DEBUG → 青色
            }
        }
    }

    impl std::io::Write for LogcatWriter {
        fn write(&mut self, buf: &[u8]) -> std::io::Result<usize> {
            self.buf.borrow_mut().extend_from_slice(buf);
            Ok(buf.len())
        }

        fn flush(&mut self) -> std::io::Result<()> {
            let mut inner = self.buf.borrow_mut();
            while inner.last() == Some(&b'\n') {
                inner.pop();
            }
            if !inner.is_empty() {
                // 前缀 ANSI 颜色，后缀重置
                let prefix = self.ansi_prefix();
                let reset = b"\x1B[0m";
                let mut colored = Vec::with_capacity(prefix.len() + inner.len() + reset.len());
                colored.extend_from_slice(prefix);
                colored.extend_from_slice(&inner);
                colored.extend_from_slice(reset);
                if let Ok(text) = CString::new(colored.as_slice()) {
                    if let Ok(tag) = CString::new(LOG_TAG) {
                        unsafe { __android_log_write(self.priority, tag.as_ptr(), text.as_ptr()); }
                    }
                }
                inner.clear();
            }
            Ok(())
        }
    }

    impl Drop for LogcatWriter {
        fn drop(&mut self) {
            let _ = self.flush();
        }
    }

    /// MakeWriter：为每条日志创建新的 LogcatWriter
    pub struct LogcatMakeWriter;

    impl tracing_subscriber::fmt::MakeWriter<'_> for LogcatMakeWriter {
        type Writer = LogcatWriter;

        fn make_writer(&self) -> Self::Writer {
            LogcatWriter::new(ANDROID_LOG_INFO)
        }

        fn make_writer_for(&self, meta: &tracing::Metadata<'_>) -> Self::Writer {
            let priority = match *meta.level() {
                tracing::Level::ERROR => ANDROID_LOG_ERROR,
                tracing::Level::WARN => ANDROID_LOG_WARN,
                tracing::Level::INFO => ANDROID_LOG_INFO,
                tracing::Level::DEBUG | tracing::Level::TRACE => ANDROID_LOG_DEBUG,
            };
            LogcatWriter::new(priority)
        }
    }
}

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

    // 构建 EnvFilter：全局级别 + 抑制 HTTP 连接池噪音
    let mut env_filter = tracing_subscriber::EnvFilter::builder()
        .with_default_directive(level_filter.into())
        .from_env_lossy();
    // 抑制 reqwest/hyper 连接池 DEBUG 日志
    env_filter = env_filter.add_directive("hyper=info".parse().unwrap());
    env_filter = env_filter.add_directive("reqwest=info".parse().unwrap());
    env_filter = env_filter.add_directive("tower=info".parse().unwrap());
    env_filter = env_filter.add_directive("hyper_util=info".parse().unwrap());
    env_filter = env_filter.add_directive("http_pool=info".parse().unwrap());

    // 文件输出
    let file_appender = tracing_appender::rolling::daily(log_dir, "sdk.log");
    let (non_blocking_file, guard) = tracing_appender::non_blocking(file_appender);
    let _ = LOG_GUARD.set(guard);

    // 控制台输出：桌面端走 stdout，Android 走 logcat（每条独立写入，避免与 Flutter 日志重叠）
    #[cfg(not(target_os = "android"))]
    let (non_blocking_console, _console_guard) = tracing_appender::non_blocking(std::io::stdout());
    #[cfg(not(target_os = "android"))]
    let console_layer = Some(
        tracing_subscriber::fmt::layer()
            .with_writer(non_blocking_console)
            .with_ansi(true)
    );
    #[cfg(target_os = "android")]
    let console_layer = Some(
        tracing_subscriber::fmt::layer()
            .with_writer(android_logcat::LogcatMakeWriter)
            .with_ansi(false)
            .with_target(false)
    );

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
        .with(console_layer)
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
