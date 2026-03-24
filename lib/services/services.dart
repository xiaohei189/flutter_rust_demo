// 服务层导出文件
//
// 使用方式:
// ```dart
// import 'package:flutter_rust_demo/services/services.dart';
// ```

export 'im_client.dart';
export 'connection_service.dart';
export 'conversation_service.dart';
export 'message_service_new.dart' show MessageService;
export 'user_service.dart';
export 'navigation_service.dart';

// 导出 Rust 侧的 UserProfile 和 UserProfilePatch
export '../src/rust/api/bridge_client.dart' show UserProfile, UserProfilePatch;
