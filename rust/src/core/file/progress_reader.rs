use std::io::Read;
use std::sync::{Arc, atomic::{AtomicI64, Ordering}};

/// ProgressReader — 追踪读取进度的 Reader 包装器
/// 对齐 Go SDK `internal/third/file/progress.go`
///
/// 包裹在外层，在每次 Read 时回调已读取字节数
pub struct ProgressReader<R> {
    reader: R,
    read: i64,
    callback: Arc<dyn Fn(i64) + Send + Sync>,
}

impl<R: Read> ProgressReader<R> {
    pub fn new(reader: R, callback: Arc<dyn Fn(i64) + Send + Sync>) -> Self {
        Self {
            reader,
            read: 0,
            callback,
        }
    }
}

impl<R: Read> Read for ProgressReader<R> {
    fn read(&mut self, buf: &mut [u8]) -> std::io::Result<usize> {
        let n = self.reader.read(buf)?;
        if n > 0 {
            self.read += n as i64;
            (self.callback)(self.read);
        }
        Ok(n)
    }
}

/// AtomicProgress — 线程安全的进度追踪器
/// 用于在异步上传中跟踪已传输字节数
pub struct AtomicProgress {
    uploaded: AtomicI64,
    total: i64,
}

impl AtomicProgress {
    pub fn new(total: i64) -> Self {
        Self {
            uploaded: AtomicI64::new(0),
            total,
        }
    }

    pub fn add(&self, bytes: i64) {
        self.uploaded.fetch_add(bytes, Ordering::Relaxed);
    }

    pub fn uploaded(&self) -> i64 {
        self.uploaded.load(Ordering::Relaxed)
    }

    pub fn total(&self) -> i64 {
        self.total
    }

    /// 计算进度百分比 (0-100)
    pub fn percentage(&self) -> u8 {
        if self.total <= 0 {
            return 0;
        }
        let uploaded = self.uploaded() as u64;
        let total = self.total as u64;
        ((uploaded * 100) / total).min(100) as u8
    }
}
