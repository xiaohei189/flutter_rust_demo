import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';

/// 应用统一日志工具，输出包含 [文件:行号] 便于定位
///
/// 日志同时输出到控制台和文件，便于调试。
/// 文件路径：临时目录/app.log（热重启自动清除，每次运行生成新的）
///
/// 使用方式：
/// ```dart
/// appLog.d('调试信息');
/// appLog.i('普通信息');
/// appLog.w('警告');
/// appLog.e('错误');
/// ```
final appLog = AppLogger();

class AppLogger {
  late final Logger _logger;
  File? _logFile;
  IOSink? _logSink;

  AppLogger() {
    _logger = Logger(
      printer: _FileLinePrinter(),
      level: kDebugMode ? Level.debug : Level.info,
    );
    _initFile();
  }

  Future<void> _initFile() async {
    try {
      final dir = await getTemporaryDirectory();
      _logFile = File('${dir.path}/app.log');
      await _logFile?.delete(recursive: false).catchError((_) {});
      _logSink = _logFile?.openWrite(mode: FileMode.append);
    } catch (_) {}
  }

  void _writeToFile(String line) {
    _logSink?.writeAll([line, '\n']);
  }

  void d(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _logger.d(message, error: error, stackTrace: stackTrace);
    _writeToFile(_formatMessage(message));
  }

  void i(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _logger.i(message, error: error, stackTrace: stackTrace);
    _writeToFile(_formatMessage(message));
  }

  void w(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _logger.w(message, error: error, stackTrace: stackTrace);
    _writeToFile(_formatMessage(message));
  }

  void e(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _logger.e(message, error: error, stackTrace: stackTrace);
    _writeToFile(_formatMessage(message));
    if (error != null) _writeToFile('  Error: $error');
  }

  String _formatMessage(dynamic message) {
    final time = DateTime.now();
    final timeStr =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}.${time.millisecond.toString().padLeft(3, '0')}';
    return '[$timeStr] $message';
  }

  Future<void> close() async {
    await _logSink?.flush();
    await _logSink?.close();
  }
}

/// 自定义打印机：输出 [文件:行号] 便于定位
class _FileLinePrinter extends LogPrinter {
  static final _framePattern = RegExp(
    r'package:flutter_rust_demo/([^:)]+):(\d+)(?::\d+)?\)',
  );

  @override
  List<String> log(LogEvent event) {
    final caller = _parseCaller(StackTrace.current);
    final time = DateTime.now();
    final timeStr =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';
    final levelStr = _levelString(event.level);
    final msg = event.message.toString();
    final line = '[$timeStr] [$caller] $levelStr: $msg';
    if (event.error != null) {
      return [line, '  ${event.error}', if (event.stackTrace != null) '  ${event.stackTrace}'];
    }
    return [line];
  }

  String _levelString(Level level) {
    return switch (level) {
      Level.trace => 'TRACE',
      Level.debug => 'DEBUG',
      Level.info => 'INFO',
      Level.warning => 'WARN',
      Level.error => 'ERROR',
      Level.fatal => 'FATAL',
      Level.off => 'OFF',
      Level.all => 'ALL',
      _ => 'UNKNOWN',
    };
  }

  /// 从堆栈中解析第一个应用内调用位置，格式: lib/xxx.dart:123
  String _parseCaller(StackTrace stackTrace) {
    final lines = stackTrace.toString().split('\n');
    for (final line in lines) {
      final match = _framePattern.firstMatch(line);
      if (match == null) continue;
      final file = match.group(1) ?? '?';
      final lineNum = match.group(2) ?? '?';
      // 跳过 logger 包和本文件
      if (file.contains('app_logger') || file.contains('logger/')) continue;
      return '$file:$lineNum';
    }
    return '?:?';
  }
}
