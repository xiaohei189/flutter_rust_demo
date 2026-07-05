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
            Self { priority, buf: RefCell::new(Vec::with_capacity(1024)) }
        }

        /// 缩短 cargo registry 的绝对路径
        /// /home/.../.cargo/registry/src/XX/sqlx-core-0.8.6/src/logger.rs:143
        /// → sqlx-core/src/logger.rs:143
        fn shorten_paths(buf: &mut Vec<u8>) {
            let Ok(text) = std::str::from_utf8(buf) else { return };
            let marker = ".cargo/registry/src/";
            if !text.contains(marker) {
                return;
            }
            let mut out = String::with_capacity(text.len());
            let mut rem = text;
            while let Some(idx) = rem.find(marker) {
                out.push_str(&rem[..idx]);
                let after = &rem[idx + marker.len()..];
                let Some(slash1) = after.find('/') else {
                    out.push_str(&rem[idx..]);
                    break;
                };
                let crate_path = &after[slash1 + 1..];
                let Some(slash2) = crate_path.find('/') else {
                    out.push_str(crate_path);
                    break;
                };
                let cv = &crate_path[..slash2]; // crate-version, e.g. sqlx-core-0.8.6
                let dash = cv.as_bytes().iter().enumerate().rev()
                    .find(|(i, &b)| b == b'-' && i + 1 < cv.len()
                        && cv.as_bytes()[i + 1].is_ascii_digit())
                    .map(|(i, _)| i);
                let cn = dash.map_or(cv, |d| &cv[..d]);
                out.push_str(cn);
                out.push_str(&crate_path[slash2..]);
                rem = &crate_path[slash2..];
            }
            out.push_str(rem);
            *buf = out.into_bytes();
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
                // 缩短 cargo registry 路径: 提取 crate 名
                Self::shorten_paths(&mut inner);
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
static CONSOLE_GUARD: OnceLock<tracing_appender::non_blocking::WorkerGuard> = OnceLock::new();

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
    let mut initialized = LOG_INITIALIZED.lock().unwrap_or_else(|e| e.into_inner());
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
    // 抑制三方 crate 的 INFO/DEBUG 日志（避免显示 registry 绝对路径）
    env_filter = env_filter.add_directive("hyper=warn".parse().unwrap());
    env_filter = env_filter.add_directive("reqwest=warn".parse().unwrap());
    env_filter = env_filter.add_directive("tower=warn".parse().unwrap());
    env_filter = env_filter.add_directive("hyper_util=warn".parse().unwrap());
    env_filter = env_filter.add_directive("http_pool=warn".parse().unwrap());
    env_filter = env_filter.add_directive("sqlx=warn".parse().unwrap());

    // 文件输出
    let file_appender = tracing_appender::rolling::daily(log_dir, "sdk.log");
    let (non_blocking_file, guard) = tracing_appender::non_blocking(file_appender);
    let _ = LOG_GUARD.set(guard);

    // 控制台输出：桌面端走 stdout，Android 走 logcat
    #[cfg(not(target_os = "android"))]
    let (non_blocking_console, console_guard) = tracing_appender::non_blocking(std::io::stdout());
    #[cfg(not(target_os = "android"))]
    let _ = CONSOLE_GUARD.set(console_guard);
    #[cfg(not(target_os = "android"))]
    let console_layer = Some(
        tracing_subscriber::fmt::layer()
            .with_writer(non_blocking_console)
            .with_ansi(true)
            .with_file(true)
            .with_line_number(true)
            .with_target(false)
    );
    #[cfg(target_os = "android")]
    let console_layer = Some(
        tracing_subscriber::fmt::layer()
            .with_writer(android_logcat::LogcatMakeWriter)
            .with_ansi(false)
            .with_file(true)
            .with_line_number(true)
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
                .with_span_events(tracing_subscriber::fmt::format::FmtSpan::ACTIVE)
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
