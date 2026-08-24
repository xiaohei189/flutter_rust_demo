import 'package:flutter/material.dart';

import '../../../../data/services/image_picker_service.dart';
import '../../../../data/services/media_import_service.dart';
import '../../../../domain/models/friend.dart';
import '../../../../domain/models/user.dart';
import '../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../view_models/chat_detail_view_model.dart';

/// 聊天页媒体与名片操作：图片、相机、位置、文件、视频、语音、名片。
class ChatMediaActions {
  ChatMediaActions({
    required this.viewModel,
    required this.onError,
    required this.onScrollToBottom,
    required this.preLoaded,
    required this.imagePickerService,
    required this.mediaImportService,
  });

  final ChatDetailViewModel viewModel;
  final void Function(String message) onError;
  final VoidCallback onScrollToBottom;
  final bool preLoaded;
  final ImagePickerService imagePickerService;
  final MediaImportService mediaImportService;

  Future<void> pickImage(BuildContext context) async {
    final picked = await imagePickerService.pickImageFromGallery(
      imageQuality: 85,
      maxWidth: 1920,
    );
    if (picked == null) return;
    final ok = await viewModel.sendImage(picked.path);
    if (!ok) onError('发送图片失败');
    if (!preLoaded) onScrollToBottom();
  }

  /// 相册多选连发（压缩后逐张发送，最多 9 张）
  Future<void> pickImages(BuildContext context) async {
    final picked = await imagePickerService.pickMultiImage(
      imageQuality: 85,
      maxWidth: 1920,
      limit: 9,
    );
    if (picked == null || picked.isEmpty) return;
    for (final image in picked) {
      final ok = await viewModel.sendImage(image.path);
      if (!ok) {
        onError('发送图片失败');
        break;
      }
    }
    if (!preLoaded) onScrollToBottom();
  }

  Future<void> pickFromCamera(BuildContext context) async {
    final picked = await imagePickerService.takePhoto(
      imageQuality: 85,
      maxWidth: 1920,
    );
    if (picked == null) return;
    final ok = await viewModel.sendImage(picked.path);
    if (!ok) onError('发送图片失败');
    if (!preLoaded) onScrollToBottom();
  }

  Future<void> pickLocation(BuildContext context) async {
    // 定位失败时仍允许手动填写坐标
    final position = await mediaImportService.currentLocation();
    final latitude = position?.latitude;
    final longitude = position?.longitude;

    if (!context.mounted) return;
    final location = await _askLocation(
      context,
      latitude: latitude,
      longitude: longitude,
    );
    if (location == null || !context.mounted) return;
    final ok = await viewModel.sendLocation(
      description: location.description,
      latitude: location.latitude,
      longitude: location.longitude,
    );
    if (!ok) onError('发送位置失败');
    if (!preLoaded) onScrollToBottom();
  }

  Future<({String description, double latitude, double longitude})?>
  _askLocation(
    BuildContext context, {
    double? latitude,
    double? longitude,
  }) async {
    final descriptionController = TextEditingController(text: '当前位置');
    final latitudeController = TextEditingController(
      text: latitude?.toStringAsFixed(6) ?? '',
    );
    final longitudeController = TextEditingController(
      text: longitude?.toStringAsFixed(6) ?? '',
    );

    final result =
        await showDialog<
          ({String description, double latitude, double longitude})
        >(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('发送位置'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: '位置描述',
                      hintText: '当前位置',
                    ),
                  ),
                  TextField(
                    controller: latitudeController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: '纬度'),
                  ),
                  TextField(
                    controller: longitudeController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: '经度'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () {
                  final lat = double.tryParse(latitudeController.text.trim());
                  final lon = double.tryParse(longitudeController.text.trim());
                  if (lat == null || lon == null) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(content: Text('请输入有效的纬度和经度')),
                    );
                    return;
                  }
                  Navigator.of(dialogContext).pop((
                    description: descriptionController.text.trim().isEmpty
                        ? '当前位置'
                        : descriptionController.text.trim(),
                    latitude: lat,
                    longitude: lon,
                  ));
                },
                child: const Text('发送'),
              ),
            ],
          ),
        );

    descriptionController.dispose();
    latitudeController.dispose();
    longitudeController.dispose();
    return result;
  }

  Future<void> pickFile(BuildContext context) async {
    try {
      final path = await mediaImportService.pickFile();
      if (path == null || path.isEmpty) return;
      final ok = await viewModel.sendFile(path);
      if (!ok) onError('发送文件失败');
      if (!preLoaded) onScrollToBottom();
    } catch (e) {
      appLog.e('发送文件失败: $e');
    }
  }

  Future<void> pickVideo(BuildContext context) async {
    try {
      final video = await imagePickerService.pickVideoFromGallery();
      if (video == null) return;

      var duration = 0;
      var snapshotPath = '';
      try {
        duration = await mediaImportService.videoDuration(video.path);
        snapshotPath = await mediaImportService.videoThumbnail(video.path);
      } catch (_) {
        // 时长或缩略图解析失败不阻塞发送
      }

      final ok = await viewModel.sendVideo(
        videoPath: video.path,
        snapshotPath: snapshotPath,
        duration: duration,
      );
      if (!ok) onError('发送视频失败');
      if (!preLoaded) onScrollToBottom();
    } catch (e) {
      appLog.e('发送视频失败: $e');
    }
  }

  Future<void> sendVoiceMessage(int duration, String filePath) async {
    final ok = await viewModel.sendVoice(filePath, duration);
    if (!ok) onError('发送语音失败');
    if (!preLoaded) onScrollToBottom();
  }

  Future<void> sendCardMessage(BuildContext context) async {
    try {
      final friends = await viewModel.loadFriendsForPicker();
      if (!context.mounted) return;
      if (friends.isEmpty) {
        onError('暂无好友可选');
        return;
      }
      final selected = await showModalBottomSheet<Friend>(
        context: context,
        backgroundColor: context.appColors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (sheetContext) => SafeArea(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: friends.length,
            itemBuilder: (_, index) {
              final friend = friends[index];
              return ListTile(
                leading: UserAvatar(
                  user: User(
                    id: friend.userId,
                    name: friend.nickname,
                    avatar: friend.faceUrl.isNotEmpty ? friend.faceUrl : null,
                  ),
                  radius: 20,
                ),
                title: Text(
                  friend.remark.isNotEmpty ? friend.remark : friend.nickname,
                ),
                subtitle: Text('ID: ${friend.userId}'),
                onTap: () => Navigator.of(sheetContext).pop(friend),
              );
            },
          ),
        ),
      );
      if (selected == null || !context.mounted) return;
      final ok = await viewModel.sendCard(selected);
      if (!ok) onError('发送名片失败');
      if (!preLoaded) onScrollToBottom();
    } catch (e) {
      appLog.e('发送名片失败: $e');
    }
  }
}
