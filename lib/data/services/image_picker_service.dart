import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'logger_service.dart';
import 'permission_service.dart';

/// 图片选择服务
class ImagePickerService {
  static final ImagePickerService _instance = ImagePickerService._internal();
  factory ImagePickerService() => _instance;

  final ImagePicker _picker = ImagePicker();

  ImagePickerService._internal();

  /// 从相册选择图片
  Future<File?> pickImageFromGallery({
    int? imageQuality,
    double? maxWidth,
    double? maxHeight,
  }) async {
    logger.debug('从相册选择图片');

    // 请求相册权限
    final hasPermission = await permissionService.requestPhotosPermission();
    if (!hasPermission) {
      logger.warning('没有相册权限');
      return null;
    }

    final pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: imageQuality,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
    );
    if (pickedFile == null) {
      logger.debug('用户取消选择图片');
      return null;
    }

    logger.debug('选择图片成功: ${pickedFile.path}');
    return File(pickedFile.path);
  }

  /// 使用相机拍照
  Future<File?> takePhoto({
    int? imageQuality,
    double? maxWidth,
    double? maxHeight,
  }) async {
    logger.debug('使用相机拍照');

    // 请求相机权限
    final hasPermission = await permissionService.requestCameraPermission();
    if (!hasPermission) {
      logger.warning('没有相机权限');
      return null;
    }

    final pickedFile = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: imageQuality,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
    );
    if (pickedFile == null) {
      logger.debug('用户取消拍照');
      return null;
    }

    logger.debug('拍照成功: ${pickedFile.path}');
    return File(pickedFile.path);
  }

  /// 从相册选择多张图片
  Future<List<File>?> pickMultiImage({
    int? limit,
    int? imageQuality,
    double? maxWidth,
    double? maxHeight,
  }) async {
    logger.debug('从相册选择多张图片');

    // 请求相册权限
    final hasPermission = await permissionService.requestPhotosPermission();
    if (!hasPermission) {
      logger.warning('没有相册权限');
      return null;
    }

    final pickedFiles = await _picker.pickMultiImage(
      imageQuality: imageQuality,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      limit: limit,
    );
    if (pickedFiles.isEmpty) {
      logger.debug('用户取消选择图片');
      return null;
    }

    final files = pickedFiles.map((file) => File(file.path)).toList();
    logger.debug('选择多张图片成功: ${files.length} 张');
    return files;
  }

  /// 从相册选择视频
  Future<File?> pickVideoFromGallery() async {
    logger.debug('从相册选择视频');

    // 请求相册权限
    final hasPermission = await permissionService.requestPhotosPermission();
    if (!hasPermission) {
      logger.warning('没有相册权限');
      return null;
    }

    final pickedFile = await _picker.pickVideo(source: ImageSource.gallery);
    if (pickedFile == null) {
      logger.debug('用户取消选择视频');
      return null;
    }

    logger.debug('选择视频成功: ${pickedFile.path}');
    return File(pickedFile.path);
  }

  /// 使用相机录制视频
  Future<File?> recordVideo() async {
    logger.debug('使用相机录制视频');

    // 请求相机权限
    final hasPermission = await permissionService.requestCameraPermission();
    if (!hasPermission) {
      logger.warning('没有相机权限');
      return null;
    }

    // 请求麦克风权限
    final hasMicPermission = await permissionService.requestMicrophonePermission();
    if (!hasMicPermission) {
      logger.warning('没有麦克风权限');
      return null;
    }

    final pickedFile = await _picker.pickVideo(
      source: ImageSource.camera,
      maxDuration: const Duration(minutes: 5),
    );
    if (pickedFile == null) {
      logger.debug('用户取消录制视频');
      return null;
    }

    logger.debug('录制视频成功: ${pickedFile.path}');
    return File(pickedFile.path);
  }
}
