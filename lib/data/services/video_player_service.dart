import 'dart:io';
import 'package:video_player/video_player.dart';
import 'logger_service.dart';

/// 视频播放服务
class VideoPlayerService {
  static final VideoPlayerService _instance = VideoPlayerService._internal();
  factory VideoPlayerService() => _instance;
  
  // 存储正在播放的视频控制器
  final Map<String, VideoPlayerController> _controllers = {};
  
  VideoPlayerService._internal();
  
  /// 初始化视频控制器
  Future<VideoPlayerController> initializeController(String videoUrl) async {
    logger.debug('初始化视频控制器: $videoUrl');
    
    // 如果已经存在控制器，直接返回
    if (_controllers.containsKey(videoUrl)) {
      logger.debug('视频控制器已存在，直接返回');
      return _controllers[videoUrl]!;
    }
    
    // 创建新的控制器
    late VideoPlayerController controller;
    
    if (videoUrl.startsWith('http')) {
      // 网络视频
      controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
    } else {
      // 本地视频
      controller = VideoPlayerController.file(File(videoUrl));
    }
    
    // 初始化控制器
    await controller.initialize();
    logger.debug('视频控制器初始化成功: ${controller.value.duration}');
    
    // 存储控制器
    _controllers[videoUrl] = controller;
    
    return controller;
  }
  
  /// 播放视频
  Future<void> play(String videoUrl) async {
    logger.debug('播放视频: $videoUrl');
    final controller = await initializeController(videoUrl);
    await controller.play();
  }
  
  /// 暂停视频
  Future<void> pause(String videoUrl) async {
    logger.debug('暂停视频: $videoUrl');
    if (_controllers.containsKey(videoUrl)) {
      await _controllers[videoUrl]?.pause();
    }
  }
  
  /// 停止视频
  Future<void> stop(String videoUrl) async {
    logger.debug('停止视频: $videoUrl');
    if (_controllers.containsKey(videoUrl)) {
      await _controllers[videoUrl]?.pause();
      await _controllers[videoUrl]?.seekTo(Duration.zero);
    }
  }
  
  /// 跳转到指定位置
  Future<void> seekTo(String videoUrl, Duration position) async {
    logger.debug('跳转到指定位置: $position');
    if (_controllers.containsKey(videoUrl)) {
      await _controllers[videoUrl]?.seekTo(position);
    }
  }
  
  /// 设置音量
  Future<void> setVolume(String videoUrl, double volume) async {
    logger.debug('设置音量: $volume');
    if (_controllers.containsKey(videoUrl)) {
      await _controllers[videoUrl]?.setVolume(volume);
    }
  }
  
  /// 设置播放速度
  Future<void> setPlaybackSpeed(String videoUrl, double speed) async {
    logger.debug('设置播放速度: $speed');
    if (_controllers.containsKey(videoUrl)) {
      await _controllers[videoUrl]?.setPlaybackSpeed(speed);
    }
  }
  
  /// 释放视频控制器
  Future<void> dispose(String videoUrl) async {
    logger.debug('释放视频控制器: $videoUrl');
    if (_controllers.containsKey(videoUrl)) {
      await _controllers[videoUrl]?.dispose();
      _controllers.remove(videoUrl);
    }
  }
  
  /// 释放所有视频控制器
  Future<void> disposeAll() async {
    logger.debug('释放所有视频控制器');
    for (final url in _controllers.keys) {
      await _controllers[url]?.dispose();
    }
    _controllers.clear();
  }
  
  /// 获取视频控制器
  VideoPlayerController? getController(String videoUrl) {
    return _controllers[videoUrl];
  }
  
  /// 检查视频是否正在播放
  bool isPlaying(String videoUrl) {
    final controller = _controllers[videoUrl];
    return controller?.value.isPlaying ?? false;
  }
  
  /// 获取视频总时长
  Duration? getDuration(String videoUrl) {
    final controller = _controllers[videoUrl];
    return controller?.value.duration;
  }
  
  /// 获取当前播放位置
  Duration? getCurrentPosition(String videoUrl) {
    final controller = _controllers[videoUrl];
    return controller?.value.position;
  }
}

// 全局视频播放服务实例
final videoPlayerService = VideoPlayerService();