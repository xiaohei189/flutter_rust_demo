use std::sync::Once;
use std::fs;

/// 日志配置
#[derive(Debug, Clone)]
pub struct LoggerConfig {
    /// 日志级别（例如："info", "debug", "warn", "error"）
    pub log_level: String,
    /// 日志文件路径（如果为空则不写入文件）
    pub log_file_path: String,
    /// 是否输出到标准输出（控制台）
    pub is_log_standard_output: bool,
}

impl Default for LoggerConfig {
    fn default() -> Self {
        Self {
            log_level: "info".to_string(),
            log_file_path: String::new(),
            is_log_standard_output: true,
        }
    }
}

/// 初始化日志系统（全局单例）
static INIT_LOGGER: Once = Once::new();

/// 初始化日志
/// 
/// 根据配置初始化日志系统，支持输出到控制台和文件
/// 只能初始化一次，后续调用会被忽略
#[flutter_rust_bridge::frb(sync)]
pub fn init_logger(config: LoggerConfig) -> Result<(), String> {
    INIT_LOGGER.call_once(|| {
        use tracing_subscriber::prelude::*;
        use tracing_subscriber::EnvFilter;

        // 创建日志过滤器
        let filter_layer = EnvFilter::try_from_default_env()
            .unwrap_or_else(|_| EnvFilter::new(&config.log_level));

        let registry = tracing_subscriber::registry().with(filter_layer);

        // 根据配置构建输出层
        match (
            config.is_log_standard_output,
            !config.log_file_path.is_empty(),
        ) {
            (true, true) => {
                // 同时输出到控制台和文件
                // 确保日志目录存在
                if let Some(parent) = std::path::Path::new(&config.log_file_path).parent() {
                    let _ = fs::create_dir_all(parent);
                }

                match std::fs::OpenOptions::new()
                    .create(true)
                    .append(true)
                    .open(&config.log_file_path)
                {
                    Ok(file) => {
                        registry
                            .with(
                                tracing_subscriber::fmt::layer()
                                    .with_writer(std::io::stdout)
                                    .with_file(true)
                                    .with_line_number(true)
                                    .with_target(false)
                                    .with_ansi(true),
                            )
                            .with(
                                tracing_subscriber::fmt::layer()
                                    .with_writer(file)
                                    .with_file(true)
                                    .with_line_number(true)
                                    .with_target(false)
                                    .with_ansi(false),
                            )
                            .init();
                    }
                    Err(e) => {
                        eprintln!("无法打开日志文件 {}: {}", config.log_file_path, e);
                        // 只使用标准输出
                        registry
                            .with(
                                tracing_subscriber::fmt::layer()
                                    .with_writer(std::io::stdout)
                                    .with_file(true)
                                    .with_line_number(true)
                                    .with_target(false)
                                    .with_ansi(true),
                            )
                            .init();
                    }
                }
            }
            (true, false) => {
                // 只输出到控制台
                registry
                    .with(
                        tracing_subscriber::fmt::layer()
                            .with_writer(std::io::stdout)
                            .with_file(true)
                            .with_line_number(true)
                            .with_target(false)
                            .with_ansi(true),
                    )
                    .init();
            }
            (false, true) => {
                // 只输出到文件
                // 确保日志目录存在
                if let Some(parent) = std::path::Path::new(&config.log_file_path).parent() {
                    let _ = fs::create_dir_all(parent);
                }

                match std::fs::OpenOptions::new()
                    .create(true)
                    .append(true)
                    .open(&config.log_file_path)
                {
                    Ok(file) => {
                        registry
                            .with(
                                tracing_subscriber::fmt::layer()
                                    .with_writer(file)
                                    .with_file(true)
                                    .with_line_number(true)
                                    .with_target(false)
                                    .with_ansi(false),
                            )
                            .init();
                    }
                    Err(e) => {
                        eprintln!("无法打开日志文件 {}: {}", config.log_file_path, e);
                        // 回退到标准输出
                        registry
                            .with(
                                tracing_subscriber::fmt::layer()
                                    .with_writer(std::io::stdout)
                                    .with_file(true)
                                    .with_line_number(true)
                                    .with_target(false),
                            )
                            .init();
                    }
                }
            }
            (false, false) => {
                // 默认输出到控制台
                registry
                    .with(
                        tracing_subscriber::fmt::layer()
                            .with_writer(std::io::stdout)
                            .with_file(true)
                            .with_line_number(true)
                            .with_target(false),
                    )
                    .init();
            }
        }
    });

    Ok(())
}

/// 简化版日志初始化（使用默认配置）
/// 
/// 默认配置：
/// - 日志级别: "info"
/// - 输出到标准输出: true
/// - 日志文件路径: 空（不写入文件）
#[flutter_rust_bridge::frb(sync)]
pub fn init_logger_simple(log_level: Option<String>) -> Result<(), String> {
    let config = LoggerConfig {
        log_level: log_level.unwrap_or_else(|| "info".to_string()),
        ..Default::default()
    };
    init_logger(config)
}

