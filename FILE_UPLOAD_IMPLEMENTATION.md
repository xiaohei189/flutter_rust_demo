# 文件上传功能实现文档

## 背景

参考 `openim-sdk-core` 和 `openim-flutter-demo` 的实现，我们需要在 Rust 中实现文件上传功能，并通过 `flutter_rust_bridge` 暴露给 Flutter 端，以便 Flutter 应用可以上传用户头像等文件。

## 实现步骤

### 步骤 1：在 Rust 中创建文件上传服务

1. 在 `rust/src/im` 目录下创建 `file` 目录，包含以下文件：
   - `mod.rs`：模块声明
   - `file.rs`：文件上传核心逻辑
   - `upload.rs`：已存在，用于数据库操作

2. 在 `file.rs` 中实现文件上传逻辑：
   - 实现分块上传功能
   - 实现与对象存储服务的集成
   - 实现上传进度回调

### 步骤 2：在 Rust API 中暴露文件上传方法

1. 在 `rust/src/api` 目录下创建 `file.rs` 文件，实现以下方法：
   - `upload_file`：上传文件，返回文件 URL
   - `upload_file_with_progress`：上传文件并返回进度

2. 在 `rust/src/api/mod.rs` 中导出这些方法

### 步骤 3：通过 flutter_rust_bridge 暴露方法

1. 使用 `#[flutter_rust_bridge::frb]` 注解标记需要暴露给 Flutter 的方法
2. 确保方法参数和返回值类型符合 Flutter 的要求

### 步骤 4：在 Flutter 端调用 Rust 方法

1. 在 `lib/generated/rust/ffi` 目录下创建 `file.dart` 文件
2. 实现 `uploadFile` 方法，调用 Rust 端的方法
3. 在 `my_profile_screen.dart` 中使用此方法上传头像

## 代码示例

### Rust 端代码示例：

```rust
// rust/src/im/file/file.rs
use anyhow::Result;
use std::path::Path;

pub struct FileService {
    // 实现文件上传所需的字段
}

impl FileService {
    pub fn new() -> Self {
        Self {}
    }

    pub async fn upload_file(&self, file_path: &str, file_name: &str) -> Result<String> {
        // 实现文件上传逻辑
        // 1. 读取文件
        // 2. 分块上传
        // 3. 获取对象存储返回的 URL
        Ok("https://example.com/avatar.jpg".to_string())
    }
}

// rust/src/api/file.rs
use flutter_rust_bridge::frb;
use crate::im::file::FileService;

#[frb]
pub async fn upload_file(file_path: String, file_name: String) -> Result<String, String> {
    let file_service = FileService::new();
    match file_service.upload_file(&file_path, &file_name).await {
        Ok(url) => Ok(url),
        Err(e) => Err(e.to_string()),
    }
}
```

### Flutter 端代码示例：

```dart
// lib/generated/rust/ffi/file.dart
import 'package:flutter_rust_bridge/flutter_rust_bridge.dart';
import '../frb_generated.dart';

class FileApi {
  static Future<String> uploadFile(String filePath, String fileName) async {
    try {
      return await api.uploadFile(filePath, fileName);
    } catch (e) {
      throw Exception('Upload failed: $e');
    }
  }
}

// lib/screens/my_profile_screen.dart
Future<void> _pickImage() async {
  final ImagePicker picker = ImagePicker();
  final XFile? image = await picker.pickImage(source: ImageSource.gallery);
  if (image != null && mounted) {
    try {
      final url = await FileApi.uploadFile(image.path, 'avatar.jpg');
      final success = await ref.read(userProfileProvider.notifier).updateAvatar(url);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('头像更新成功')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('上传失败: $e')),
      );
    }
  }
}
```

## 注意事项

1. **对象存储集成**：需要根据实际使用的对象存储服务（如 AWS S3、阿里云 OSS 等）实现相应的上传逻辑
2. **错误处理**：确保在 Rust 和 Flutter 端都有适当的错误处理
3. **进度回调**：如果需要显示上传进度，需要实现进度回调功能
4. **安全性**：确保上传过程中的安全性，如使用 HTTPS、签名验证等
5. **性能优化**：对于大文件，实现分块上传和断点续传功能

## 参考资料

1. `openim-sdk-core` 中的文件上传实现：`internal/third/file/upload.go`
2. `openim-flutter-demo` 中的文件上传调用：`openim_common/lib/src/widgets/views.dart` 中的 `uCropPic` 方法
3. `flutter_rust_bridge` 文档：https://cjycode.com/flutter_rust_bridge/
