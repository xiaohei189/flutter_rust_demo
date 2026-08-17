import '../../generated/rust/ffi/message_media.dart' as ffi_message_media;

abstract class MediaUploadService {
  Future<String> uploadFile({
    required String filePath,
    required String fileName,
  });
}

class MediaUploadServiceImpl implements MediaUploadService {
  const MediaUploadServiceImpl();

  @override
  Future<String> uploadFile({
    required String filePath,
    required String fileName,
  }) {
    return ffi_message_media.uploadFile(
      filePath: filePath,
      fileName: fileName,
    );
  }
}
