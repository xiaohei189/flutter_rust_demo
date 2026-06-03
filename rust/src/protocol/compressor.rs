use anyhow::{Context, Result};
use flate2::read::GzDecoder;
use flate2::write::GzEncoder;
use flate2::Compression;
use std::io::{Read, Write};

/// Gzip 压缩器，对齐 Go SDK compressor.go
#[derive(Clone)]
pub struct GzipCompressor;

impl GzipCompressor {
    pub fn new() -> Self {
        Self
    }

    /// Gzip 压缩
    pub fn compress(&self, raw_data: &[u8]) -> Result<Vec<u8>> {
        let mut encoder = GzEncoder::new(Vec::new(), Compression::default());
        encoder
            .write_all(raw_data)
            .context("gzip write failed")?;
        encoder.finish().context("gzip finish failed")
    }

    /// Gzip 解压
    pub fn decompress(&self, compressed_data: &[u8]) -> Result<Vec<u8>> {
        let mut decoder = GzDecoder::new(compressed_data);
        let mut output = Vec::new();
        decoder
            .read_to_end(&mut output)
            .context("gzip decompress failed")?;
        Ok(output)
    }
}

impl Default for GzipCompressor {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_compress_decompress_roundtrip() {
        let compressor = GzipCompressor::new();
        let original = b"Hello, OpenIM SDK! This is a test message with some repeated content for compression. \
                         Hello, OpenIM SDK! This is a test message with some repeated content for compression.";

        let compressed = compressor.compress(original).unwrap();
        assert!(compressed.len() < original.len(), "compressed should be smaller");

        let decompressed = compressor.decompress(&compressed).unwrap();
        assert_eq!(decompressed, original);
    }

    #[test]
    fn test_compress_empty() {
        let compressor = GzipCompressor::new();
        let compressed = compressor.compress(b"").unwrap();
        let decompressed = compressor.decompress(&compressed).unwrap();
        assert!(decompressed.is_empty());
    }
}
