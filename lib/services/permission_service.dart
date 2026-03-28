import 'package:permission_handler/permission_handler.dart';
import 'logger_service.dart';

/// 权限管理服务
class PermissionService {
  static final PermissionService _instance = PermissionService._internal();
  factory PermissionService() => _instance;
  
  PermissionService._internal();
  
  /// 请求相机权限
  Future<bool> requestCameraPermission() async {
    logger.debug('请求相机权限');
    final status = await Permission.camera.request();
    logger.debug('相机权限状态: $status');
    return status.isGranted;
  }
  
  /// 请求麦克风权限
  Future<bool> requestMicrophonePermission() async {
    logger.debug('请求麦克风权限');
    final status = await Permission.microphone.request();
    logger.debug('麦克风权限状态: $status');
    return status.isGranted;
  }
  
  /// 请求存储权限
  Future<bool> requestStoragePermission() async {
    logger.debug('请求存储权限');
    final status = await Permission.storage.request();
    logger.debug('存储权限状态: $status');
    return status.isGranted;
  }
  
  /// 请求相册权限
  Future<bool> requestPhotosPermission() async {
    logger.debug('请求相册权限');
    final status = await Permission.photos.request();
    logger.debug('相册权限状态: $status');
    return status.isGranted;
  }
  
  /// 检查相机权限
  Future<bool> checkCameraPermission() async {
    final status = await Permission.camera.status;
    return status.isGranted;
  }
  
  /// 检查麦克风权限
  Future<bool> checkMicrophonePermission() async {
    final status = await Permission.microphone.status;
    return status.isGranted;
  }
  
  /// 检查存储权限
  Future<bool> checkStoragePermission() async {
    final status = await Permission.storage.status;
    return status.isGranted;
  }
  
  /// 检查相册权限
  Future<bool> checkPhotosPermission() async {
    final status = await Permission.photos.status;
    return status.isGranted;
  }
  
  /// 打开应用设置
  Future<void> launchAppSettings() async {
    logger.debug('打开应用设置');
    await openAppSettings();
  }
}

// 全局权限服务实例
final permissionService = PermissionService();