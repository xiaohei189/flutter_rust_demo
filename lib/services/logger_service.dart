import 'package:logger/logger.dart';

/// 日志管理服务
class LoggerService {
  static final LoggerService _instance = LoggerService._internal();
  factory LoggerService() => _instance;
  
  late Logger _logger;
  
  LoggerService._internal() {
    // 配置日志输出
    _logger = Logger(
      printer: PrettyPrinter(
        methodCount: 2, // 显示方法调用链的深度
        errorMethodCount: 8, // 错误时显示方法调用链的深度
        lineLength: 120, // 日志行长度
        colors: true, // 启用彩色输出
        printEmojis: true, // 显示表情符号
        dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart, // 显示时间
      ),
    );
  }
  
  /// 记录详细信息
  void verbose(String message) {
    _logger.t(message);
  }
  
  /// 记录调试信息
  void debug(String message) {
    _logger.d(message);
  }
  
  /// 记录信息
  void info(String message) {
    _logger.i(message);
  }
  
  /// 记录警告信息
  void warning(String message) {
    _logger.w(message);
  }
  
  /// 记录错误信息
  void error(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.e(message, error: error, stackTrace: stackTrace);
  }
  
  /// 记录致命错误信息
  void fatal(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.f(message, error: error, stackTrace: stackTrace);
  }
}

// 全局日志实例
final logger = LoggerService();