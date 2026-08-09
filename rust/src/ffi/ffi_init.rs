use std::sync::Mutex;
use std::sync::OnceLock;

use crate::logger::{self, LogConfig};

// Android 平台：通过 JNI 写入 logcat
#[cfg(target_os = "android")]
mod android_logcat {
    use std::cell::RefCell;
    use std::ffi::CString;
    use std::io::Write;

    const LOG_TAG: &str = "RustSDK";

    const ANDROID_LOG_DEBUG: i32 = 3;
    const ANDROID_LOG_INFO: i32 = 4;
    const ANDROID_LOG_WARN: i32 = 5;
    const ANDROID_LOG_ERROR: i32 = 6;

    extern "C" {
        fn __android_log_write(prio: i32, tag: *const std::os::raw::c_char, text: *const std::os::raw::c_char) -> i32;
    }

    pub struct LogcatWriter {
        priority: i32,
        buf: RefCell<Vec<u8>>,
    }

    impl LogcatWriter {
        pub fn new(priority: i32) -> Self {
            Self {
                priority,
                buf: RefCell::new(Vec::with_capacity(1024)),
            }
        }

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
                let cv = &crate_path[..slash2];
                let dash = cv
                    .as_bytes()
                    .iter()
                    .enumerate()
                    .rev()
                    .find(|(i, &b)| b == b'-' && i + 1 < cv.len() && cv.as_bytes()[i + 1].is_ascii_digit())
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
                6 => b"\x1B[31m",
                5 => b"\x1B[33m",
                4 => b"\x1B[32m",
                _ => b"\x1B[36m",
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
                Self::shorten_paths(&mut inner);
                let prefix = self.ansi_prefix();
                let reset = b"\x1B[0m";
                let mut colored = Vec::with_capacity(prefix.len() + inner.len() + reset.len());
                colored.extend_from_slice(prefix);
                colored.extend_from_slice(&inner);
                colored.extend_from_slice(reset);
                if let Ok(text) = CString::new(colored.as_slice()) {
                    if let Ok(tag) = CString::new(LOG_TAG) {
                        unsafe {
                            __android_log_write(self.priority, tag.as_ptr(), text.as_ptr());
                        }
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

static LOG_INITIALIZED: Mutex<bool> = Mutex::new(false);
static LOG_CONFIG: OnceLock<LogConfig> = OnceLock::new();

/// 获取 logcat MakeWriter（供 otel.rs 使用）
#[cfg(target_os = "android")]
pub fn logcat_make_writer() -> android_logcat::LogcatMakeWriter {
    android_logcat::LogcatMakeWriter
}

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
