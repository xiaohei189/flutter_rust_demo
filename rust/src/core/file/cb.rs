/// UploadFileCallback — 细粒度上传回调接口
/// 对齐 Go SDK `internal/third/file/cb.go`
///
/// 分片上传的每个阶段都会回调对应方法：
/// 1. Open → PartSize → HashPartProgress... → HashPartComplete
/// 2. UploadID → UploadPartProgress... → UploadPartComplete...
/// 3. UploadComplete（持续回调进度）→ Complete
pub trait UploadFileCallback: Send + Sync {
    /// 文件打开，获取文件大小
    fn open(&self, size: i64);

    /// 分片大小和总数确定
    fn part_size(&self, part_size: i64, num: i32);

    /// 计算每个分片 hash 的过程
    fn hash_part_progress(&self, index: i32, size: i64, part_hash: &str);

    /// 全部分片 hash 计算完成
    fn hash_part_complete(&self, parts_hash: &str, file_hash: &str);

    /// 获得上传会话 ID
    fn upload_id(&self, upload_id: &str);

    /// 单个分片上传完成
    fn upload_part_complete(&self, index: i32, part_size: i64, part_hash: &str);

    /// 整体上传进度（file_size, stream_size, storage_size）
    fn upload_complete(&self, file_size: i64, stream_size: i64, storage_size: i64);

    /// 上传全部完成（size, url, typ: 1=全新, 2=断点续传）
    fn complete(&self, size: i64, url: &str, typ: i32);
}

/// 空实现 — 用于默认场景
pub struct EmptyUploadCallback;

impl UploadFileCallback for EmptyUploadCallback {
    fn open(&self, _size: i64) {}
    fn part_size(&self, _part_size: i64, _num: i32) {}
    fn hash_part_progress(&self, _index: i32, _size: i64, _part_hash: &str) {}
    fn hash_part_complete(&self, _parts_hash: &str, _file_hash: &str) {}
    fn upload_id(&self, _upload_id: &str) {}
    fn upload_part_complete(&self, _index: i32, _part_size: i64, _part_hash: &str) {}
    fn upload_complete(&self, _file_size: i64, _stream_size: i64, _storage_size: i64) {}
    fn complete(&self, _size: i64, _url: &str, _typ: i32) {}
}

/// 简化回调 — 将细粒度回调转为简单的 (current, total) 进度
/// 对齐 Go SDK `internal/third/progress.go` 的 `progressConvert`
pub struct ProgressConvert<C: Fn(i64, i64)> {
    pub on_progress: C,
}

impl<C: Fn(i64, i64) + Send + Sync> UploadFileCallback for ProgressConvert<C> {
    fn open(&self, size: i64) {
        (self.on_progress)(0, size);
    }
    fn part_size(&self, _part_size: i64, _num: i32) {}
    fn hash_part_progress(&self, _index: i32, _size: i64, _part_hash: &str) {}
    fn hash_part_complete(&self, _parts_hash: &str, _file_hash: &str) {}
    fn upload_id(&self, _upload_id: &str) {}
    fn upload_part_complete(&self, _index: i32, _part_size: i64, _part_hash: &str) {}
    fn upload_complete(&self, _file_size: i64, stream_size: i64, file_size: i64) {
        (self.on_progress)(stream_size, file_size);
    }
    fn complete(&self, size: i64, _url: &str, _typ: i32) {
        (self.on_progress)(size, size);
    }
}

/// 上传进度结构 — 对齐 Go SDK `sdk_struct.UploadProgress`
#[derive(Debug, Clone, Default, serde::Serialize, serde::Deserialize)]
pub struct UploadProgressInfo {
    /// 文件总大小
    #[serde(rename = "total")]
    pub total: i64,
    /// 已存储大小（storageSize）
    #[serde(rename = "save")]
    pub save: i64,
    /// 已流式传输大小（streamSize）
    #[serde(rename = "current")]
    pub current: i64,
    /// 上传会话 ID（用于断点续传）
    #[serde(rename = "uploadID")]
    pub upload_id: String,
}
