//! OpenTelemetry 集成：trace_id 提取、remote span 重建、subscriber 初始化

use opentelemetry::propagation::TextMapPropagator;
use opentelemetry::trace::{SpanContext, SpanId, TraceContextExt, TraceFlags, TraceId, TraceState, TracerProvider as _};
use opentelemetry::Context;
use opentelemetry_sdk::propagation::TraceContextPropagator;
use opentelemetry_sdk::trace::TracerProvider;
use std::collections::HashMap;
use std::fmt;
use std::io::Write;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Mutex;
use std::time::Instant;
use tracing::Span;
use tracing_opentelemetry::OpenTelemetrySpanExt;
use tracing_subscriber::fmt::format::FmtSpan;
use tracing_subscriber::fmt::format::Writer;
use tracing_subscriber::fmt::FmtContext;
use tracing_subscriber::fmt::FormatEvent;
use tracing_subscriber::fmt::MakeWriter;
use tracing_subscriber::layer::SubscriberExt;
use tracing_subscriber::registry::LookupSpan;
use tracing_subscriber::util::SubscriberInitExt;
use tracing_subscriber::Layer;
use tracing_subscriber::Registry;

use super::config::LogConfig;

// ============================================================================
// CompactLayer — 参考 JSON formatter 实现，使用 Layer trait 精确控制 span 生命周期
// ============================================================================

/// 每个 span 的运行时状态
struct SpanState {
    name: String,
    target: String,
    file: Option<String>,
    line: Option<u32>,
    fields: String,
    trace_id: Option<String>,
    span_id: Option<String>,
    parent_span_id: Option<String>,
    start: Instant,
    /// 是否已输出过 enter 日志（async fn 多次 poll 去重）
    enter_emitted: bool,
}

/// 自定义 Layer：手动控制紧凑格式输出
///
/// 输出格式：
///   `<ts> <LEVEL> <file:line> <span_name>{fields, trace_id, span_id}: <message>`
///
/// 与 `FormatEvent` 方案的关键区别：
/// - 实现 `Layer` trait，直接挂钩 `on_new_span` / `on_enter` / `on_close` / `on_event`
/// - `on_enter` 时从 OTel 读取 trace_id 并缓存到 `SpanState`
/// - `on_close` 时从缓存读取 trace_id（不受 OTel layer 清理影响）
/// - `enter_emitted` 标志天然去重 async fn 多次 poll
/// - 不依赖 `fmt::Layer` 的 span 事件合成，事件类型天然可区分
pub struct CompactLayer<W> {
    make_writer: W,
    with_ansi: bool,
    log_span_events: bool,
    spans: Mutex<HashMap<u64, SpanState>>,
}

impl<W: Clone> Clone for CompactLayer<W> {
    fn clone(&self) -> Self {
        Self {
            make_writer: self.make_writer.clone(),
            with_ansi: self.with_ansi,
            log_span_events: self.log_span_events,
            spans: Mutex::new(HashMap::new()),
        }
    }
}

impl<W> CompactLayer<W> {
    pub fn new(make_writer: W, with_ansi: bool, log_span_events: bool) -> Self {
        Self {
            make_writer,
            with_ansi,
            log_span_events,
            spans: Mutex::new(HashMap::new()),
        }
    }
}

// ANSI 颜色码
const GREY: &str = "\x1b[90m";
const WHITE: &str = "\x1b[37m";
const CYAN: &str = "\x1b[36m";
const DIM: &str = "\x1b[2m";
const RESET: &str = "\x1b[0m";

impl<S, W> Layer<S> for CompactLayer<W>
where
    S: tracing::Subscriber + for<'a> LookupSpan<'a>,
    W: for<'writer> MakeWriter<'writer> + 'static,
{
    fn on_new_span(&self, attrs: &tracing::span::Attributes<'_>, id: &tracing::span::Id, _ctx: tracing_subscriber::layer::Context<'_, S>) {
        let meta = attrs.metadata();
        let mut fields = String::new();
        attrs.record(&mut FieldVisitor(&mut fields));

        let mut spans = self.spans.lock().unwrap_or_else(|e| e.into_inner());
        spans.insert(
            id.into_u64(),
            SpanState {
                name: meta.name().to_string(),
                target: meta.target().to_string(),
                file: meta.file().map(|s| s.to_string()),
                line: meta.line(),
                fields,
                trace_id: None,
                span_id: None,
                parent_span_id: None,
                start: Instant::now(),
                enter_emitted: false,
            },
        );
    }

    fn on_enter(&self, id: &tracing::span::Id, ctx: tracing_subscriber::layer::Context<'_, S>) {
        let span_id_u64 = id.into_u64();

        // 在锁内完成状态更新，克隆需要的数据，锁外执行 IO
        let enter_data = {
            let mut spans = self.spans.lock().unwrap_or_else(|e| e.into_inner());
            if let Some(state) = spans.get_mut(&span_id_u64) {
                // 首次 enter 时读取 OTel trace_id / span_id 并缓存
                if state.trace_id.is_none() {
                    if let Some(span) = ctx.span(id) {
                        if let Some(otel) = span.extensions().get::<tracing_opentelemetry::OtelData>() {
                            let (tid, sid, psid) = otel_trace_span_id(otel);
                            if let (Some(tid), Some(sid)) = (tid, sid) {
                                state.trace_id = Some(tid);
                                state.span_id = Some(sid);
                                state.parent_span_id = psid;
                            }
                        }
                    }
                    state.start = Instant::now();
                }

                if self.log_span_events && SPAN_EVENTS_ENABLED.load(Ordering::Relaxed) && !state.enter_emitted {
                    state.enter_emitted = true;
                    Some((
                        state.name.clone(),
                        state.fields.clone(),
                        state.trace_id.clone(),
                        state.span_id.clone(),
                        state.parent_span_id.clone(),
                        state.file.clone(),
                        state.line,
                    ))
                } else {
                    None
                }
            } else {
                None
            }
        }; // 锁释放

        if let Some((name, fields, trace_id, span_id, parent_span_id, file, line)) = enter_data {
            let ts = chrono::Utc::now().format("%Y-%m-%dT%H:%M:%S%.3fZ").to_string();
            let mut writer = self.make_writer.make_writer();
            let _ = write_span_event(
                &mut writer,
                self.with_ansi,
                &ts,
                "INFO ",
                file.as_deref(),
                line,
                &name,
                &fields,
                trace_id.as_deref(),
                span_id.as_deref(),
                parent_span_id.as_deref(),
                "enter",
            );
        }
    }

    fn on_close(&self, id: tracing::span::Id, _ctx: tracing_subscriber::layer::Context<'_, S>) {
        let span_id_u64 = id.into_u64();

        // 在锁内完成状态移除，克隆数据，锁外执行 IO
        let close_data = {
            let mut spans = self.spans.lock().unwrap_or_else(|e| e.into_inner());
            spans.remove(&span_id_u64).and_then(|state| {
                if self.log_span_events && SPAN_EVENTS_ENABLED.load(Ordering::Relaxed) {
                    let busy = state.start.elapsed();
                    Some((state.name, state.fields, state.trace_id, state.span_id, state.parent_span_id, state.file, state.line, busy))
                } else {
                    None
                }
            })
        }; // 锁释放

        if let Some((name, fields, trace_id, span_id, parent_span_id, file, line, busy)) = close_data {
            let ts = chrono::Utc::now().format("%Y-%m-%dT%H:%M:%S%.3fZ").to_string();
            let mut writer = self.make_writer.make_writer();
            let msg = format!("close time.busy={:.2}ms", busy.as_secs_f64() * 1000.0);
            let _ = write_span_event(
                &mut writer,
                self.with_ansi,
                &ts,
                "INFO ",
                file.as_deref(),
                line,
                &name,
                &fields,
                trace_id.as_deref(),
                span_id.as_deref(),
                parent_span_id.as_deref(),
                &msg,
            );
        }
    }

    fn on_event(&self, _event: &tracing::Event<'_>, _ctx: tracing_subscriber::layer::Context<'_, S>) {
        // 普通事件由 fmt::Layer 处理，CompactLayer 只负责 span 生命周期事件
    }
}

// ============================================================================
// 辅助函数
// ============================================================================

/// 从 OtelData 提取 (trace_id, span_id)
///
/// - `trace_id`：优先从 `parent_cx` 继承（子 span / 通过 set_parent 设置 remote parent 的 span），
///   若 parent_cx 的 trace_id 无效则回退到 `builder.trace_id`（根 span）
/// - `span_id`：始终从 `builder.span_id` 获取
///
/// 注意：只检查 `trace_id` 有效性，不检查 `span_id`。
/// 当 remote parent 只有 trace_id 没有 span_id 时（如服务端回传的 operation_id），
/// `is_valid()` 会因 span_id 为 INVALID 而返回 false，导致 trace_id 继承失败。
fn otel_trace_span_id(data: &tracing_opentelemetry::OtelData) -> (Option<String>, Option<String>, Option<String>) {
    let trace_id = {
        let parent_span = data.parent_cx.span();
        let sc = parent_span.span_context();
        if sc.trace_id() != opentelemetry::trace::TraceId::INVALID {
            Some(sc.trace_id())
        } else {
            data.builder.trace_id
        }
    };
    let span_id = data.builder.span_id;
    let parent_span_id = {
        let parent_span = data.parent_cx.span();
        let sc = parent_span.span_context();
        if sc.span_id() != opentelemetry::trace::SpanId::INVALID {
            Some(sc.span_id().to_string())
        } else {
            None
        }
    };
    (trace_id.map(|t| t.to_string()), span_id.map(|s| s.to_string()), parent_span_id)
}

/// 写 span 生命周期事件（enter / close）
fn write_span_event(
    writer: &mut dyn Write,
    with_ansi: bool,
    ts: &str,
    level: &str,
    file: Option<&str>,
    line: Option<u32>,
    span_name: &str,
    fields: &str,
    trace_id: Option<&str>,
    span_id: Option<&str>,
    parent_span_id: Option<&str>,
    message: &str,
) -> std::io::Result<()> {
    // 1) 时间戳
    if with_ansi {
        write!(writer, "{}{}{} ", GREY, ts, RESET)?;
    } else {
        write!(writer, "{} ", ts)?;
    }

    // 2) 级别
    if with_ansi {
        write!(writer, "\x1b[32m{}{}\x1b[0m ", level, RESET)?;
    } else {
        write!(writer, "{} ", level)?;
    }

    // 3) 文件:行号
    if let (Some(f), Some(l)) = (file, line) {
        let f = shorten_cargo_path(f);
        if with_ansi {
            write!(writer, "{}{}:{}{} ", GREY, f, l, RESET)?;
        } else {
            write!(writer, "{}:{} ", f, l)?;
        }
    }

    // 4) span_name{fields, trace_id, span_id}
    if with_ansi {
        write!(writer, "{}{}{}", CYAN, span_name, RESET)?;
    } else {
        write!(writer, "{}", span_name)?;
    }

    let mut inner = String::new();
    if !fields.is_empty() {
        inner.push_str(&fields.replace(' ', ", "));
    }
    if let (Some(tid), Some(sid)) = (trace_id, span_id) {
        if !inner.is_empty() {
            inner.push_str(", ");
        }
        inner.push_str(&format!("trace_id={}, span_id={}", tid, sid));
    }
    if let Some(psid) = parent_span_id {
        if !inner.is_empty() {
            inner.push_str(", ");
        }
        inner.push_str(&format!("parent_span_id={}", psid));
    }

    if !inner.is_empty() {
        if with_ansi {
            write!(writer, "{}{{{}}}{}", GREY, inner, RESET)?;
        } else {
            write!(writer, "{{{}}}", inner)?;
        }
    }
    write!(writer, " ")?;

    // 5) 消息
    writeln!(writer, "{}", message)?;

    Ok(())
}

/// 事件格式化器：只负责普通事件（span 事件由 CompactLayer 处理）
struct EventFormatter {
    with_ansi: bool,
}

impl<S, N> FormatEvent<S, N> for EventFormatter
where
    S: tracing::Subscriber + for<'a> LookupSpan<'a>,
    N: for<'a> tracing_subscriber::fmt::FormatFields<'a> + 'static,
{
    fn format_event(&self, ctx: &FmtContext<'_, S, N>, mut writer: Writer<'_>, event: &tracing::Event<'_>) -> fmt::Result {
        // 1) 时间戳
        let ts = chrono::Utc::now().format("%Y-%m-%dT%H:%M:%S%.3fZ");
        if self.with_ansi {
            write!(writer, "{}{}{} ", GREY, ts, RESET)?;
        } else {
            write!(writer, "{} ", ts)?;
        }

        // 2) 级别
        let level = event.metadata().level();
        if self.with_ansi {
            let color = match *level {
                tracing::Level::ERROR => "\x1b[31m",
                tracing::Level::WARN => "\x1b[33m",
                tracing::Level::INFO => "\x1b[32m",
                tracing::Level::DEBUG => "\x1b[34m",
                tracing::Level::TRACE => "\x1b[35m",
            };
            write!(writer, "{}{:<5}{} ", color, *level, RESET)?;
        } else {
            write!(writer, "{:<5} ", *level)?;
        }

        // 3) 文件:行号
        if let (Some(file), Some(line)) = (event.metadata().file(), event.metadata().line()) {
            let file = shorten_cargo_path(file);
            if self.with_ansi {
                write!(writer, "{}{}:{}{} ", GREY, file, line, RESET)?;
            } else {
                write!(writer, "{}:{} ", file, line)?;
            }
        }

        // 4) 消息内容
        if self.with_ansi {
            write!(writer, "{}", WHITE)?;
        }
        ctx.field_format().format_fields(writer.by_ref(), event)?;
        if self.with_ansi {
            write!(writer, "{}", RESET)?;
        }

        // 5) span 信息放在最后，key=value 格式
        if let Some(scope) = ctx.event_scope() {
            if let Some(span_ref) = scope.from_root().last() {
                let name = span_ref.metadata().name();
                let extensions = span_ref.extensions();
                let fields_str = extensions.get::<tracing_subscriber::fmt::FormattedFields<N>>().map(|f| f.as_str()).unwrap_or("");

                let otel_info: Option<(String, String)> = extensions.get::<tracing_opentelemetry::OtelData>().and_then(|data| {
                    let (tid, sid, _psid) = otel_trace_span_id(data);
                    match (tid, sid) {
                        (Some(tid), Some(sid)) => Some((tid, sid)),
                        _ => None,
                    }
                });

                // INFO 及以上只保留 trace_id/span_id，避免每行尾部 span 上下文过长；
                // DEBUG/TRACE 才输出完整 span 名称与字段，便于链路排查。
                let show_full_span = *level <= tracing::Level::DEBUG;
                if show_full_span {
                    if self.with_ansi {
                        write!(writer, " {}span={}", GREY, name)?;
                        if !fields_str.is_empty() {
                            write!(writer, " {}", fields_str.replace('=', "=").replace(' ', " "))?;
                        }
                        if let Some((ref tid, ref sid)) = otel_info {
                            write!(writer, " trace_id={} span_id={}", tid, sid)?;
                        }
                        write!(writer, "{}", RESET)?;
                    } else {
                        write!(writer, " span={}", name)?;
                        if !fields_str.is_empty() {
                            write!(writer, " {}", fields_str)?;
                        }
                        if let Some((ref tid, ref sid)) = otel_info {
                            write!(writer, " trace_id={} span_id={}", tid, sid)?;
                        }
                    }
                } else if let Some((ref tid, ref sid)) = otel_info {
                    if self.with_ansi {
                        write!(writer, " {}trace_id={} span_id={}{}", GREY, tid, sid, RESET)?;
                    } else {
                        write!(writer, " trace_id={} span_id={}", tid, sid)?;
                    }
                }
            }
        }

        writeln!(writer)?;
        Ok(())
    }
}

/// 记录 span 字段的 visitor
struct FieldVisitor<'a>(&'a mut String);

impl<'a> tracing::field::Visit for FieldVisitor<'a> {
    fn record_debug(&mut self, field: &tracing::field::Field, value: &dyn fmt::Debug) {
        if !self.0.is_empty() {
            self.0.push(' ');
        }
        self.0.push_str(&format!("{}={:?}", field.name(), value));
    }

    fn record_str(&mut self, field: &tracing::field::Field, value: &str) {
        if !self.0.is_empty() {
            self.0.push(' ');
        }
        self.0.push_str(&format!("{}={}", field.name(), value));
    }
}

/// 把 `/home/user/.cargo/registry/src/xx/crate-1.0/src/lib.rs` 缩短为 `crate/src/lib.rs`
fn shorten_cargo_path(file: &str) -> String {
    let marker = ".cargo/registry/src/";
    if !file.contains(marker) {
        return file.to_string();
    }
    if let Some(idx) = file.find(marker) {
        let after = &file[idx + marker.len()..];
        if let Some(slash1) = after.find('/') {
            let crate_path = &after[slash1 + 1..];
            if let Some(slash2) = crate_path.find('/') {
                let cv = &crate_path[..slash2];
                let dash = cv
                    .as_bytes()
                    .iter()
                    .enumerate()
                    .rev()
                    .find(|(i, &b)| b == b'-' && i + 1 < cv.len() && cv.as_bytes()[i + 1].is_ascii_digit())
                    .map(|(i, _)| i);
                let cn = dash.map_or(cv, |d| &cv[..d]);
                return format!("{}{}", cn, &crate_path[slash2..]);
            }
            return crate_path.to_string();
        }
    }
    file.to_string()
}

// ============================================================================
// 公共 API
// ============================================================================

/// 从当前 tracing span 的 OTel 上下文中提取 trace_id 字符串
pub fn extract_trace_id() -> String {
    let span = Span::current();
    let cx = span.context();
    let span_ref = cx.span();
    let sc = span_ref.span_context();
    if sc.is_valid() {
        sc.trace_id().to_string()
    } else {
        String::new()
    }
}

/// 从当前 tracing span 的 OTel 上下文中提取 span_id
pub fn extract_span_id() -> Option<SpanId> {
    let span = Span::current();
    let cx = span.context();
    let span_ref = cx.span();
    let sc = span_ref.span_context();
    if sc.is_valid() {
        Some(sc.span_id())
    } else {
        None
    }
}

/// 将 trace_id 和 span_id 编码为透传用的 operationID
/// 格式: `{trace_id}:{span_id}`，服务端原样回传后由 decode_operation_id 解析
pub fn encode_operation_id(trace_id: &str, span_id: Option<SpanId>) -> String {
    if trace_id.is_empty() {
        return String::new();
    }
    match span_id {
        Some(sid) => format!("{}:{}", trace_id, sid),
        None => trace_id.to_string(),
    }
}

/// 从服务端回传的 operationID 解析出 trace_id 和 span_id
/// 兼容两种格式: `{trace_id}:{span_id}` 或 `{trace_id}`
pub fn decode_operation_id(operation_id: &str) -> (&str, Option<&str>) {
    if let Some(idx) = operation_id.rfind(':') {
        let trace_id = &operation_id[..idx];
        let span_id = &operation_id[idx + 1..];
        // 验证 trace_id 是32位 hex 且 span_id 是16位 hex
        if trace_id.len() == 32 && trace_id.chars().all(|c| c.is_ascii_hexdigit()) && span_id.len() == 16 && span_id.chars().all(|c| c.is_ascii_hexdigit()) {
            return (trace_id, Some(span_id));
        }
    }
    (operation_id, None)
}

/// 从服务端回传的 trace_id 字符串重建 tracing span（带 remote parent）
///
/// 注意：tracing 0.1 的 span 名称必须是字面量，因此用固定名 `remote_span`，
/// 实际 span 名记录在 `otel.name` 字段中。
pub fn span_from_remote_trace_id(name: &str, trace_id_hex: &str, parent_span_id_hex: Option<&str>) -> Span {
    let trace_id = TraceId::from_hex(trace_id_hex).unwrap_or(TraceId::INVALID);
    if trace_id == TraceId::INVALID {
        return tracing::info_span!("remote_span", otel.name = %name);
    }

    let parent_span_id = parent_span_id_hex.and_then(|s| SpanId::from_hex(s).ok()).unwrap_or(SpanId::INVALID);

    let remote_sc = SpanContext::new(
        trace_id,
        if parent_span_id == SpanId::INVALID { SpanId::from(1u64) } else { parent_span_id },
        TraceFlags::SAMPLED,
        true,
        TraceState::default(),
    );

    let parent_cx = Context::new().with_remote_span_context(remote_sc);
    // 在创建 span 前 attach remote parent 到当前线程 OTel context，
    // 使 on_new_span 时 parent_context 能从 OtelContext::current() 继承 trace_id。
    // （set_parent 在 on_new_span 之后执行，builder.trace_id 已被生成，不会被覆盖）
    let span = {
        let _guard = parent_cx.attach();
        tracing::info_span!("remote_span", otel.name = %name)
    };
    span
}

/// 从 operation_id（encode_operation_id 编码的 trace_id:span_id）重建 span
///
/// 官方推荐：跨 channel/task 只传递 trace 上下文字符串，消费端再重建 span，
/// 不要跨任务持有 tracing::Span 句柄并对可能已关闭的 span 调用 enter。
pub fn span_from_operation_id(name: &str, operation_id: &str) -> Span {
    let (trace_id_str, span_id_str) = decode_operation_id(operation_id);
    span_from_remote_trace_id(name, trace_id_str, span_id_str)
}

/// 构建 W3C traceparent header
pub fn build_w3c_traceparent(trace_id_hex: &str, span_id_hex: &str) -> String {
    format!("00-{}-{}-01", trace_id_hex, span_id_hex)
}

/// 从 W3C traceparent 字符串提取 Context
pub fn context_from_traceparent(traceparent: &str) -> Context {
    let mut carrier = HashMap::new();
    carrier.insert("traceparent".to_string(), traceparent.to_string());
    let propagator = TraceContextPropagator::new();
    propagator.extract(&carrier)
}

/// 运行时开关：控制 span enter/close 日志是否输出
static SPAN_EVENTS_ENABLED: AtomicBool = AtomicBool::new(true);

/// EnvFilter 风格日志级别覆盖（如 "info,rust_lib_flutter_rust_demo=debug"）
static ENV_FILTER_OVERRIDE: Mutex<Option<String>> = Mutex::new(None);

/// 设置 EnvFilter 风格过滤指令（init_otel_subscriber 前调用）
pub fn set_env_filter_override(filter: &str) {
    if let Ok(mut guard) = ENV_FILTER_OVERRIDE.lock() {
        *guard = Some(filter.to_string());
    }
}

/// 设置 span enter/close 日志开关
pub fn set_span_events_enabled(enabled: bool) {
    SPAN_EVENTS_ENABLED.store(enabled, Ordering::Relaxed);
}

/// 初始化 OTel subscriber（文件 + OTel + 可选控制台）
pub fn init_otel_subscriber(config: &LogConfig) -> anyhow::Result<()> {
    // --- EnvFilter ---
    // 默认 info；自己的 crate 级别由 LogConfig.log_level 控制
    let mut env_filter = tracing_subscriber::EnvFilter::builder()
        .with_default_directive(tracing_subscriber::filter::LevelFilter::INFO.into())
        .from_env_lossy();
    let override_filter = ENV_FILTER_OVERRIDE.lock().unwrap_or_else(|e| e.into_inner()).clone();
    let has_crate_override = override_filter.as_deref().is_some_and(|f| f.split(',').any(|p| p.trim_start().starts_with("rust_lib_flutter_rust_demo=")));
    if !has_crate_override {
        let crate_level = format!("{:?}", config.level_filter()).to_lowercase();
        env_filter = env_filter.add_directive(format!("rust_lib_flutter_rust_demo={}", crate_level).parse().unwrap());
    }
    if let Some(filter) = override_filter {
        for directive in filter.split(',').map(|s| s.trim()).filter(|s| !s.is_empty()) {
            if let Ok(d) = directive.parse() {
                env_filter = env_filter.add_directive(d);
            }
        }
    }
    env_filter = env_filter
        .add_directive("hyper=warn".parse().unwrap())
        .add_directive("reqwest=warn".parse().unwrap())
        .add_directive("tower=warn".parse().unwrap())
        .add_directive("hyper_util=warn".parse().unwrap())
        .add_directive("sqlx=warn".parse().unwrap());

    // --- 文件层 ---
    let _ = std::fs::create_dir_all(&config.log_file_path);
    let file_appender = tracing_appender::rolling::daily(&config.log_file_path, "sdk.log");
    let (non_blocking_file, _file_guard) = tracing_appender::non_blocking(file_appender);
    std::mem::forget(_file_guard);

    // 事件格式化：委托给 fmt::Layer（线程安全、久经测试）
    let file_layer_fmt = tracing_subscriber::fmt::layer()
        .with_writer(non_blocking_file.clone())
        .with_ansi(false)
        .with_span_events(FmtSpan::NONE)
        .event_format(EventFormatter { with_ansi: false });

    // span 事件：由 CompactLayer 处理（enter/close）
    let file_layer_span = CompactLayer::new(non_blocking_file, false, config.is_log_span_events);

    // --- OTel 层 ---
    let provider = TracerProvider::builder().build();
    let tracer = provider.tracer("openim-rust-sdk");
    let otel_layer = tracing_opentelemetry::layer().with_tracer(tracer);

    // --- 控制台层 ---
    #[cfg(not(target_os = "android"))]
    let (console_writer, _console_guard) = if config.is_log_standard_output {
        tracing_appender::non_blocking(std::io::stdout())
    } else {
        tracing_appender::non_blocking(std::io::sink())
    };
    #[cfg(not(target_os = "android"))]
    std::mem::forget(_console_guard);

    #[cfg(target_os = "android")]
    let console_writer = {
        let (nc, _cg) = tracing_appender::non_blocking(std::io::stdout());
        std::mem::forget(_cg);
        nc
    };

    let console_layer_fmt = tracing_subscriber::fmt::layer()
        .with_writer(console_writer.clone())
        .with_ansi(!cfg!(target_os = "android"))
        .with_span_events(FmtSpan::NONE)
        .event_format(EventFormatter {
            with_ansi: !cfg!(target_os = "android"),
        });

    let console_layer_span = CompactLayer::new(console_writer, !cfg!(target_os = "android"), config.is_log_span_events);

    // --- 组装 subscriber ---
    // fmt::Layer 处理普通事件，CompactLayer 处理 span 生命周期事件
    // OTel layer 在 span layer 之前：确保 on_enter 时 OTel span 已创建
    tracing_subscriber::registry()
        .with(env_filter)
        .with(file_layer_fmt)
        .with(file_layer_span)
        .with(otel_layer)
        .with(console_layer_fmt)
        .with(console_layer_span)
        .try_init()?;

    tracing::info!(
        otel.name = "sdk.init",
        sdk.version = %config.sdk_version,
        system.type = %config.system_type,
        platform.name = %config.platform_name,
        "[SDK] 日志已初始化 level={} json={} stdout={} span_events={}",
        config.log_level, config.is_log_json, config.is_log_standard_output, config.is_log_span_events,
    );

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_build_w3c_traceparent() {
        let tp = build_w3c_traceparent("0af7651916cd43dd8448eb211c80319c", "b7ad6b7169203331");
        assert_eq!(tp, "00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01");
    }

    #[test]
    fn test_span_from_invalid_trace_id() {
        let span = span_from_remote_trace_id("test", "invalid", None);
        let _guard = span.enter();
        tracing::info!("test message");
    }

    #[test]
    fn test_env_filter_expression_parses() {
        let filter = tracing_subscriber::EnvFilter::try_new("info,rust_lib_flutter_rust_demo=debug").unwrap();
        let directives = filter.to_string();
        assert!(directives.contains("rust_lib_flutter_rust_demo=debug"), "{}", directives);
    }
}
