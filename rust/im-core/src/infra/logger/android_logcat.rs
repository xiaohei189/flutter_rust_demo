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

impl Write for LogcatWriter {
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

#[derive(Clone, Copy)]
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
