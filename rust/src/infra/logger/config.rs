use serde::{Deserialize, Serialize};

/// 日志配置（对齐 Go SDK IMConfig 日志字段）
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct LogConfig {
    /// 日志级别: 0=trace, 1=debug, 2=info, 3=warn, 4=error, 5=off
    pub log_level: u32,
    /// 是否输出到控制台
    pub is_log_standard_output: bool,
    /// 日志文件目录
    pub log_file_path: String,
    /// 保留日志文件个数
    pub log_remain_count: u32,
    /// 是否输出 JSON 格式（文件层）
    pub is_log_json: bool,
    /// 系统类型（如 "linux", "android"）
    pub system_type: String,
    /// 平台名称（如 "Android", "iOS"）
    pub platform_name: String,
    /// SDK 版本号
    pub sdk_version: String,
    /// 是否打印 span 进入/退出事件（FmtSpan::ENTER | FmtSpan::CLOSE）
    /// 启用后即使 span 内没有 info!() 调用，也会在 span 进入/退出时输出日志
    pub is_log_span_events: bool,
}

impl Default for LogConfig {
    fn default() -> Self {
        Self {
            log_level: 2,           // info
            is_log_standard_output: true,
            log_file_path: "./logs".to_string(),
            log_remain_count: 7,
            is_log_json: false,
            system_type: String::new(),
            platform_name: String::new(),
            sdk_version: env!("CARGO_PKG_VERSION").to_string(),
            is_log_span_events: true,
        }
    }
}

impl LogConfig {
    /// 转换为 tracing level filter
    pub fn level_filter(&self) -> tracing_subscriber::filter::LevelFilter {
        match self.log_level {
            0 => tracing_subscriber::filter::LevelFilter::TRACE,
            1 => tracing_subscriber::filter::LevelFilter::DEBUG,
            2 => tracing_subscriber::filter::LevelFilter::INFO,
            3 => tracing_subscriber::filter::LevelFilter::WARN,
            4 => tracing_subscriber::filter::LevelFilter::ERROR,
            _ => tracing_subscriber::filter::LevelFilter::OFF,
        }
    }
}
