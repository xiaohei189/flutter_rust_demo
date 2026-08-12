import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../../../domain/models/friend.dart';
import '../../../domain/models/user.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_logger.dart';
import '../../core/widgets/user_avatar.dart';
import '../view_models/chat_detail_view_model.dart';

/// 聊天页媒体与名片操作：图片、相机、位置、文件、视频、语音、名片。
class ChatMediaActions {
  ChatMediaActions({
    required this.viewModel,
    required this.onError,
    required this.onScrollToBottom,
    required this.preLoaded,
  });

  final ChatDetailViewModel viewModel;
  final void Function(String message) onError;
  final VoidCallback onScrollToBottom;
  final bool preLoaded;

  Future<void> pickImage(BuildContext context) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final ok = await viewModel.sendImage(picked.path);
    if (!ok) onError('发送图片失败');
    if (!preLoaded) onScrollToBottom();
  }

  Future<void> pickFromCamera(BuildContext context) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.camera);
    if (picked == null) return;
    final ok = await viewModel.sendImage(picked.path);
    if (!ok) onError('发送图片失败');
    if (!preLoaded) onScrollToBottom();
  }

  Future<void> pickLocation(BuildContext context) async {
    double? latitude;
    double? longitude;
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.whileInUse ||
            permission == LocationPermission.always) {
          final position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
            ),
          );
          latitude = position.latitude;
          longitude = position.longitude;
        }
      }
    } catch (_) {
      // 定位失败时仍允许手动填写坐标
    }

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
      final result = await FilePicker.platform.pickFiles();
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      if (file.path == null) return;
      final ok = await viewModel.sendFile(file.path!);
      if (!ok) onError('发送文件失败');
      if (!preLoaded) onScrollToBottom();
    } catch (e) {
      appLog.e('发送文件失败: $e');
    }
  }

  Future<void> pickVideo(BuildContext context) async {
    try {
      final picker = ImagePicker();
      final video = await picker.pickVideo(source: ImageSource.gallery);
      if (video == null) return;

      var duration = 0;
      var snapshotPath = '';
      try {
        final controller = VideoPlayerController.file(File(video.path));
        await controller.initialize();
        duration = controller.value.duration.inSeconds;
        await controller.dispose();
        final tempDir = await getTemporaryDirectory();
        snapshotPath =
            (await VideoThumbnail.thumbnailFile(
              video: video.path,
              thumbnailPath:
                  '${tempDir.path}/video_thumb_${DateTime.now().millisecondsSinceEpoch}.jpg',
              imageFormat: ImageFormat.JPEG,
              maxHeight: 720,
              quality: 80,
            )) ??
            '';
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
