use md5::Digest;
use std::io::Read;

/// Md5Reader — 边读边算 MD5 的 Reader 包装器
/// 对齐 Go SDK `internal/third/file/md5.go`
pub struct Md5Reader<R> {
    reader: R,
    hasher: md5::Md5,
}

impl<R: Read> Md5Reader<R> {
    pub fn new(reader: R) -> Self {
        Self { reader, hasher: md5::Md5::new() }
    }

    /// 获取当前已计算的 MD5（hex 编码）
    pub fn md5_hex(self) -> String {
        let result = self.hasher.finalize();
        hex::encode(result)
    }
}

impl<R: Read> Read for Md5Reader<R> {
    fn read(&mut self, buf: &mut [u8]) -> std::io::Result<usize> {
        let n = self.reader.read(buf)?;
        if n > 0 {
            self.hasher.update(&buf[..n]);
        }
        Ok(n)
    }
}

/// 计算字节数组的 MD5（hex 编码）
pub fn compute_md5_hex(data: &[u8]) -> String {
    let mut hasher = md5::Md5::new();
    hasher.update(data);
    hex::encode(hasher.finalize())
}

/// 计算多个分片 hash 组合后的 partsHash
/// 对齐 Go SDK 的 `f.partMD5(parts []string) string`
pub fn parts_hash(part_md5s: &[String]) -> String {
    let combined = part_md5s.join(",");
    compute_md5_hex(combined.as_bytes())
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::Cursor;

    #[test]
    fn test_md5_reader() {
        let data = b"hello world";
        let reader = Cursor::new(data);
        let mut md5_reader = Md5Reader::new(reader);

        let mut buf = vec![0u8; 1024];
        loop {
            let n = md5_reader.read(&mut buf).unwrap();
            if n == 0 {
                break;
            }
        }

        let hex_val = md5_reader.md5_hex();
        assert_eq!(hex_val, "5eb63bbbe01eeed093cb22bb8f5acdc3");
    }

    #[test]
    fn test_compute_md5_hex() {
        let hex_val = compute_md5_hex(b"hello world");
        assert_eq!(hex_val, "5eb63bbbe01eeed093cb22bb8f5acdc3");
    }
}
