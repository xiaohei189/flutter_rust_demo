import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/chat/message_send_pipeline.dart';
import '../../../application/chat/message_service_notifier.dart';
import '../../../domain/models/chat_message.dart';
import '../../../domain/models/chat_session_type.dart';
import '../../../domain/models/group_member.dart';
import '../../../domain/models/mention.dart';
import '../../../providers/im_providers.dart';
import '../../chat/providers/message_service_provider.dart';
import '../../chat/widgets/composer/chat_input.dart';
import '../../chat/widgets/composer/group_member_picker.dart';
import '../../chat/widgets/composer/quote_preview_bar.dart';
import '../../chat/widgets/message_content_type.dart';
import '../../groups/providers/group_provider.dart';
import '../providers/topic_provider.dart';

/// 话题根消息/回复共用编辑器。
///
/// `topicId` 为空表示发布新话题，否则表示回复该话题。编辑器复用聊天页的
/// 输入、@、Markdown、图片、视频、文件、语音、位置和名片能力，所有消息都写入
/// 同一个 `sg_<groupID>` 会话，只额外携带话题元数据。
class TopicChatComposer extends ConsumerStatefulWidget {
  const TopicChatComposer({
    super.key,
    required this.groupId,
    required this.conversationId,
    this.topicId = '',
    this.quotedMessage,
    this.onClearQuote,
    this.onSent,
    this.heightNotifier,
    this.sendToLabel,
  });

  final String groupId;
  final String conversationId;
  final String topicId;
  final ChatMessage? quotedMessage;
  final VoidCallback? onClearQuote;
  final ValueChanged<ChatMessage>? onSent;
  final ValueNotifier<double>? heightNotifier;
  final String? sendToLabel;

  bool get isRoot => topicId.isEmpty;

  @override
  ConsumerState<TopicChatComposer> createState() => _TopicChatComposerState();
}

class _TopicChatComposerState extends ConsumerState<TopicChatComposer> {
  final TextEditingController _controller = TextEditingController();
  final Set<String> _atUserIds = <String>{};
  Timer? _draftTimer;
  bool _sending = false;
  bool _draftLoaded = false;
  List<GroupMember> _members = const [];

  @override
  void initState() {
    super.initState();
    _controller.addListener(_scheduleDraftSave);
    unawaited(_loadDraft());
    unawaited(_loadMembers());
  }

  @override
  void dispose() {
    _draftTimer?.cancel();
    _controller
      ..removeListener(_scheduleDraftSave)
      ..dispose();
    super.dispose();
  }

  Future<void> _loadDraft() async {
    final store = ref.read(topicDraftStoreProvider);
    final text = widget.isRoot
        ? await store.loadRoot(widget.groupId)
        : await store.loadReply(widget.topicId);
    if (!mounted) return;
    _draftLoaded = true;
    if (text.isNotEmpty && _controller.text.isEmpty) {
      _controller.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
  }

  void _scheduleDraftSave() {
    if (!_draftLoaded) return;
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 300), () {
      final store = ref.read(topicDraftStoreProvider);
      final text = _controller.text;
      if (widget.isRoot) {
        unawaited(store.saveRoot(widget.groupId, text));
      } else {
        unawaited(store.saveReply(widget.topicId, text));
      }
    });
  }

  Future<void> _clearDraft() async {
    final store = ref.read(topicDraftStoreProvider);
    if (widget.isRoot) {
      await store.clearRoot(widget.groupId);
    } else {
      await store.clearReply(widget.topicId);
    }
  }

  Future<void> _loadMembers() async {
    final notifier = ref.read(groupMemberProvider(widget.groupId).notifier);
    if (ref.read(groupMemberProvider(widget.groupId)).members.isEmpty) {
      await notifier.loadMembers();
    }
    if (!mounted) return;
    setState(() {
      _members = ref.read(groupMemberProvider(widget.groupId)).members;
    });
  }

  List<GroupMember> get _atSuggestions => [
    atAllGroupMember(widget.groupId),
    ..._members,
  ];

  MessageServiceNotifier get _messages =>
      ref.read(messageServiceProvider.notifier);

  @override
  Widget build(BuildContext context) {
    final quote = widget.quotedMessage;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (quote != null)
          QuotePreviewBar(
            message: quote,
            onClose: widget.onClearQuote ?? () {},
          ),
        ChatInput(
          controller: _controller,
          onSend: _sendText,
          onImagePick: _pickImage,
          onImagesPick: widget.isRoot ? null : _pickImages,
          onCameraPick: _pickFromCamera,
          onLocationPick: _pickLocation,
          onFilePick: _pickFile,
          onVideoPick: _pickVideo,
          onCardSend: _sendCard,
          onVoiceRecord: _sendVoice,
          onAtMention: _showAtMentionPicker,
          onGifSelected: _sendGif,
          atMembers: _atSuggestions,
          onAtMemberSelected: (userId) => _atUserIds.add(userId),
          isGroupChat: true,
          conversationId: widget.conversationId,
          sendToLabel:
              widget.sendToLabel ?? (widget.isRoot ? '发布到话题群' : '回复话题'),
          inputHint: widget.isRoot ? '发布话题' : '回复话题',
          heightNotifier: widget.heightNotifier,
          keyboardInset: MediaQuery.viewInsetsOf(context).bottom,
        ),
      ],
    );
  }

  Future<void> _sendText(String text, MessageContentType type) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _sending) return;
    _sending = true;
    try {
      final quote = widget.quotedMessage;
      final PendingSend pending;
      if (quote != null) {
        pending = widget.isRoot
            ? await _messages.sendTopicRootQuote(
                groupId: widget.groupId,
                text: trimmed,
                quoted: quote,
                conversationId: widget.conversationId,
              )
            : await _messages.sendQuoteMessage(
                text: trimmed,
                sourceId: widget.groupId,
                sessionType: ChatSessionType.writeGroupChat,
                quoted: quote,
                conversationId: widget.conversationId,
                topicId: widget.topicId,
              );
      } else if (_atUserIds.isNotEmpty && type != MessageContentType.markdown) {
        pending = widget.isRoot
            ? await _messages.sendTopicRootAtText(
                groupId: widget.groupId,
                text: trimmed,
                atUserIds: _atUserIds.toList(growable: false),
                conversationId: widget.conversationId,
              )
            : await _messages.sendAtTextMessage(
                text: trimmed,
                atUserIds: _atUserIds.toList(growable: false),
                recvId: widget.groupId,
                sessionType: ChatSessionType.writeGroupChat,
                conversationId: widget.conversationId,
                groupId: widget.groupId,
                topicId: widget.topicId,
              );
      } else if (type == MessageContentType.markdown) {
        pending = widget.isRoot
            ? await _messages.sendTopicRootMarkdown(
                groupId: widget.groupId,
                text: trimmed,
                conversationId: widget.conversationId,
              )
            : await _messages.sendMarkdownMessage(
                recvId: widget.groupId,
                text: trimmed,
                sessionType: ChatSessionType.writeGroupChat,
                conversationId: widget.conversationId,
                groupId: widget.groupId,
                topicId: widget.topicId,
              );
      } else {
        pending = widget.isRoot
            ? await _messages.sendTopicRootText(
                groupId: widget.groupId,
                text: trimmed,
                conversationId: widget.conversationId,
              )
            : await _messages.sendTextMessage(
                recvId: widget.groupId,
                text: trimmed,
                sessionType: ChatSessionType.writeGroupChat,
                conversationId: widget.conversationId,
                groupId: widget.groupId,
                topicId: widget.topicId,
              );
      }
      await _complete(pending);
    } catch (e) {
      _showError('发送失败: $e');
    } finally {
      _sending = false;
    }
  }

  Future<void> _complete(PendingSend pending) async {
    final sent = widget.isRoot ? await pending.done : pending.message;
    if (!mounted) return;
    _controller.clear();
    _atUserIds.clear();
    widget.onClearQuote?.call();
    await _clearDraft();
    widget.onSent?.call(sent);
  }

  Future<void> _pickImage() => _pickSingleImage(
    ref.read(imagePickerServiceProvider).pickImageFromGallery,
  );

  Future<void> _pickFromCamera() =>
      _pickSingleImage(ref.read(imagePickerServiceProvider).takePhoto);

  Future<void> _pickSingleImage(
    Future<File?> Function({
      int? imageQuality,
      double? maxWidth,
      double? maxHeight,
    })
    picker,
  ) async {
    try {
      final file = await picker(imageQuality: 85, maxWidth: 1920);
      if (file == null) return;
      final pending = widget.isRoot
          ? await _messages.sendTopicRootImage(
              groupId: widget.groupId,
              filePath: file.path,
              conversationId: widget.conversationId,
            )
          : await _messages.sendImageMessage(
              filePath: file.path,
              sourceId: widget.groupId,
              sessionType: ChatSessionType.writeGroupChat,
              conversationId: widget.conversationId,
              topicId: widget.topicId,
            );
      await _complete(pending);
    } catch (e) {
      _showError('发送图片失败: $e');
    }
  }

  Future<void> _pickImages() async {
    try {
      final files = await ref
          .read(imagePickerServiceProvider)
          .pickMultiImage(imageQuality: 85, maxWidth: 1920, limit: 9);
      if (files == null || files.isEmpty) return;
      for (final file in files) {
        final pending = await _messages.sendImageMessage(
          filePath: file.path,
          sourceId: widget.groupId,
          sessionType: ChatSessionType.writeGroupChat,
          conversationId: widget.conversationId,
          topicId: widget.topicId,
        );
        await _complete(pending);
      }
    } catch (e) {
      _showError('发送图片失败: $e');
    }
  }

  Future<void> _pickVideo() async {
    try {
      final video = await ref
          .read(imagePickerServiceProvider)
          .pickVideoFromGallery();
      if (video == null) return;
      final media = ref.read(mediaImportServiceProvider);
      final duration = await media.videoDuration(video.path);
      final thumbnail = await media.videoThumbnail(video.path);
      final pending = widget.isRoot
          ? await _messages.sendTopicRootVideo(
              groupId: widget.groupId,
              videoPath: video.path,
              snapshotPath: thumbnail,
              duration: duration,
              conversationId: widget.conversationId,
            )
          : await _messages.sendVideoMessage(
              videoPath: video.path,
              snapshotPath: thumbnail,
              sourceId: widget.groupId,
              sessionType: ChatSessionType.writeGroupChat,
              duration: duration,
              conversationId: widget.conversationId,
              topicId: widget.topicId,
            );
      await _complete(pending);
    } catch (e) {
      _showError('发送视频失败: $e');
    }
  }

  Future<void> _pickFile() async {
    try {
      final path = await ref.read(mediaImportServiceProvider).pickFile();
      if (path == null || path.isEmpty) return;
      final pending = widget.isRoot
          ? await _messages.sendTopicRootFile(
              groupId: widget.groupId,
              filePath: path,
              conversationId: widget.conversationId,
            )
          : await _messages.sendFileMessage(
              filePath: path,
              sourceId: widget.groupId,
              sessionType: ChatSessionType.writeGroupChat,
              conversationId: widget.conversationId,
              topicId: widget.topicId,
            );
      await _complete(pending);
    } catch (e) {
      _showError('发送文件失败: $e');
    }
  }

  Future<void> _sendVoice(int duration, String filePath) async {
    try {
      final pending = widget.isRoot
          ? await _messages.sendTopicRootSound(
              groupId: widget.groupId,
              filePath: filePath,
              duration: duration,
              conversationId: widget.conversationId,
            )
          : await _messages.sendSoundMessage(
              filePath: filePath,
              sourceId: widget.groupId,
              sessionType: ChatSessionType.writeGroupChat,
              duration: duration,
              conversationId: widget.conversationId,
              topicId: widget.topicId,
            );
      await _complete(pending);
    } catch (e) {
      _showError('发送语音失败: $e');
    }
  }

  Future<void> _sendGif(String url) async {
    try {
      final pending = widget.isRoot
          ? await _messages.sendTopicRootImageFromUrl(
              groupId: widget.groupId,
              sourceUrl: url,
              conversationId: widget.conversationId,
            )
          : await _messages.sendImageMessageFromUrl(
              sourceUrl: url,
              sourceId: widget.groupId,
              sessionType: ChatSessionType.writeGroupChat,
              conversationId: widget.conversationId,
              topicId: widget.topicId,
            );
      await _complete(pending);
    } catch (e) {
      _showError('发送 GIF 失败: $e');
    }
  }

  Future<void> _pickLocation() async {
    final position = await ref
        .read(mediaImportServiceProvider)
        .currentLocation();
    if (!mounted) return;
    final result = await _askLocation(context, position: position);
    if (result == null || !mounted) return;
    try {
      final pending = widget.isRoot
          ? await _messages.sendTopicRootLocation(
              groupId: widget.groupId,
              description: result.description,
              latitude: result.latitude,
              longitude: result.longitude,
              conversationId: widget.conversationId,
            )
          : await _messages.sendLocationMessage(
              description: result.description,
              latitude: result.latitude,
              longitude: result.longitude,
              sourceId: widget.groupId,
              sessionType: ChatSessionType.writeGroupChat,
              conversationId: widget.conversationId,
              topicId: widget.topicId,
            );
      await _complete(pending);
    } catch (e) {
      _showError('发送位置失败: $e');
    }
  }

  Future<void> _showAtMentionPicker() async {
    if (_members.isEmpty) await _loadMembers();
    if (!mounted || _members.isEmpty) {
      _showError('暂无可选群成员');
      return;
    }
    final selected = await showGroupMemberPicker(context, _members);
    if (selected == null || !mounted) return;
    _atUserIds.add(selected.userId);
    insertAtMention(
      _controller,
      selected.nickname.isNotEmpty ? selected.nickname : selected.userId,
      selected.userId,
    );
  }

  Future<void> _sendCard() async {
    if (_members.isEmpty) await _loadMembers();
    if (!mounted || _members.isEmpty) {
      _showError('暂无可选群成员');
      return;
    }
    final selected = await showModalBottomSheet<GroupMember>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView.builder(
          itemCount: _members.length,
          itemBuilder: (_, index) {
            final member = _members[index];
            return ListTile(
              title: Text(
                member.nickname.isNotEmpty ? member.nickname : member.userId,
              ),
              subtitle: Text(member.userId),
              onTap: () => Navigator.of(context).pop(member),
            );
          },
        ),
      ),
    );
    if (selected == null || !mounted) return;
    try {
      final pending = widget.isRoot
          ? await _messages.sendTopicRootCard(
              groupId: widget.groupId,
              userId: selected.userId,
              nickname: selected.nickname,
              faceUrl: selected.faceUrl,
              ex: '',
              conversationId: widget.conversationId,
            )
          : await _messages.sendCardMessage(
              userId: selected.userId,
              nickname: selected.nickname,
              faceUrl: selected.faceUrl,
              ex: '',
              sourceId: widget.groupId,
              sessionType: ChatSessionType.writeGroupChat,
              conversationId: widget.conversationId,
              topicId: widget.topicId,
            );
      await _complete(pending);
    } catch (e) {
      _showError('发送名片失败: $e');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

Future<({String description, double latitude, double longitude})?> _askLocation(
  BuildContext context, {
  ({double latitude, double longitude})? position,
}) async {
  final description = TextEditingController(text: '当前位置');
  final latitude = TextEditingController(
    text: position?.latitude.toStringAsFixed(6) ?? '',
  );
  final longitude = TextEditingController(
    text: position?.longitude.toStringAsFixed(6) ?? '',
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
                  controller: description,
                  decoration: const InputDecoration(labelText: '位置描述'),
                ),
                TextField(
                  controller: latitude,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: '纬度'),
                ),
                TextField(
                  controller: longitude,
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
            FilledButton(
              onPressed: () {
                final lat = double.tryParse(latitude.text.trim());
                final lng = double.tryParse(longitude.text.trim());
                if (lat == null || lng == null) {
                  ScaffoldMessenger.of(
                    dialogContext,
                  ).showSnackBar(const SnackBar(content: Text('请输入有效的纬度和经度')));
                  return;
                }
                Navigator.of(dialogContext).pop((
                  description: description.text.trim().isEmpty
                      ? '当前位置'
                      : description.text.trim(),
                  latitude: lat,
                  longitude: lng,
                ));
              },
              child: const Text('发送'),
            ),
          ],
        ),
      );
  await Future<void>.delayed(const Duration(milliseconds: 350));
  description.dispose();
  latitude.dispose();
  longitude.dispose();
  return result;
}
