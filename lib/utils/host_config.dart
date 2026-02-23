// 导出：有 dart:io 时用 host_config_io（Android 用 10.0.2.2），否则用 stub（localhost）
export 'host_config_stub.dart'
    if (dart.library.io) 'host_config_io.dart';
