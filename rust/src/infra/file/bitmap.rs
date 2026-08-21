/// Bitmap 位图 — 记录分片上传状态，支持断点续传
/// 对齐 Go SDK `internal/third/file/bitmap.go`
#[derive(Debug, Clone)]
pub struct Bitmap {
    data: Vec<u64>,
    size: usize,
}

impl Bitmap {
    /// 创建指定大小的空位图
    pub fn new(size: usize) -> Self {
        let words = size.div_ceil(64);
        Self { data: vec![0u64; words], size }
    }

    /// 从字节数组恢复位图（大端序，与 Go Serialize 输出一致）
    pub fn parse(bytes: &[u8], size: usize) -> Self {
        let words = size.div_ceil(64);
        let mut data = vec![0u64; words];
        for i in 0..words.min(bytes.len() / 8) {
            data[i] = u64::from_be_bytes([
                bytes[i * 8],
                bytes[i * 8 + 1],
                bytes[i * 8 + 2],
                bytes[i * 8 + 3],
                bytes[i * 8 + 4],
                bytes[i * 8 + 5],
                bytes[i * 8 + 6],
                bytes[i * 8 + 7],
            ]);
        }
        Self { data, size }
    }

    /// 标记指定分片已上传
    pub fn set(&mut self, index: usize) {
        assert!(index < self.size, "bitmap index out of range: {}", index);
        let word_index = index / 64;
        let bit_index = index % 64;
        self.data[word_index] |= 1u64 << bit_index;
    }

    /// 查询指定分片是否已上传
    pub fn get(&self, index: usize) -> bool {
        assert!(index < self.size, "bitmap index out of range: {}", index);
        let word_index = index / 64;
        let bit_index = index % 64;
        (self.data[word_index] & (1u64 << bit_index)) != 0
    }

    /// 位图大小
    pub fn size(&self) -> usize {
        self.size
    }

    /// 序列化为字节数组（大端序）
    pub fn serialize(&self) -> Vec<u8> {
        let mut p = vec![0u8; self.data.len() * 8];
        for (i, &word) in self.data.iter().enumerate() {
            let bytes = word.to_be_bytes();
            p[i * 8..i * 8 + 8].copy_from_slice(&bytes);
        }
        p
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_bitmap_basic() {
        let mut bm = Bitmap::new(100);
        assert!(!bm.get(0));
        assert!(!bm.get(99));

        bm.set(0);
        assert!(bm.get(0));
        assert!(!bm.get(1));

        bm.set(63);
        assert!(bm.get(63));

        bm.set(64);
        assert!(bm.get(64));
        assert!(!bm.get(65));
    }

    #[test]
    fn test_bitmap_serialize_parse() {
        let mut bm = Bitmap::new(200);
        bm.set(0);
        bm.set(63);
        bm.set(64);
        bm.set(199);

        let bytes = bm.serialize();
        let bm2 = Bitmap::parse(&bytes, 200);

        assert!(bm2.get(0));
        assert!(bm2.get(63));
        assert!(bm2.get(64));
        assert!(bm2.get(199));
        assert!(!bm2.get(1));
        assert!(!bm2.get(100));
    }
}
