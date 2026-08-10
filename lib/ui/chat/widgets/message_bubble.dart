import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';
import 'package:markdown/markdown.dart' as md;

import '../../../domain/models/message.dart';
import '../../../domain/models/message_ext.dart';
import '../../../domain/models/user.dart';
import '../../../router/app_router.dart';
import '../../../src/rust/event/events/message.dart' show GroupReadReceipt;
import '../../../src/rust/model/message.dart' show MessageInfo;
import '../../../src/rust/model/user.dart' show UserInfo;
import '../../../data/services/audio_player_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/user_avatar.dart';

/// 消息气泡：支持所有消息类型的渲染
class MessageBubble extends StatelessWidget {
  final MessageInfo message;
  final User otherUser;
  final String? currentUserId;
  final UserInfo? cachedSenderProfile;
  final UserInfo? cachedCurrentUserProfile;
  final void Function(MessageInfo message)? onLongPress;
  final void Function(MessageInfo message)? onTap;
  final int? uploadProgress;
  final GroupReadReceipt? groupReadReceipt;

  const MessageBubble({
    super.key,
    required this.message,
    required this.otherUser,
    this.currentUserId,
    this.cachedSenderProfile,
    this.cachedCurrentUserProfile,
    this.onLongPress,
    this.onTap,
    this.uploadProgress,
    this.groupReadReceipt,
  });

  User _buildSenderUser() {
    final isFromMe = _isFromMe;
    final senderProfile = cachedSenderProfile;
    final meProfile = cachedCurrentUserProfile;
    if (isFromMe) {
      final nickname = meProfile?.nickname ?? message.senderNickname;
      final faceUrl = meProfile?.faceUrl ?? message.senderFaceUrl;
      return User(
        id: message.sendId.isNotEmpty ? message.sendId : (currentUserId ?? ''),
        name: nickname.isNotEmpty ? nickname : (currentUserId ?? '我'),
        avatar: faceUrl.isNotEmpty ? faceUrl : null,
        avatarColorValue: 0xFF6200EE,
        avatarIconName: 'person',
      );
    } else {
      final nickname = senderProfile?.nickname ?? message.senderNickname;
      final faceUrl = senderProfile?.faceUrl ?? message.senderFaceUrl;
      if (nickname.isNotEmpty || faceUrl.isNotEmpty) {
        return User(
          id: message.sendId,
          name: nickname.isNotEmpty ? nickname : otherUser.name,
          avatar: faceUrl.isNotEmpty ? faceUrl : otherUser.avatar,
          avatarColorValue: 0xFF6200EE,
          avatarIconName: 'person',
        );
      }
      return otherUser;
    }
  }

  bool get _isFromMe =>
      message.sendId == currentUserId ||
      (currentUserId != null &&
          currentUserId!.isNotEmpty &&
          message.sendId.isNotEmpty &&
          message.sendId == currentUserId);

  bool get isGroupChat => message.sessionType == 2 || message.sessionType == 3;

  @override
  Widget build(BuildContext context) {
    // 系统消息（撤回等）：居中显示，无头像、无气泡背景
    if (message.messageType == MessageType.system) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Center(
          child: Text(
            message.displayText,
            style: const TextStyle(
              color: AppTheme.textSecondaryColor,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final isFromMe = _isFromMe;
    final timeText = _formatMessageTime(message.sendDateTime);
    final senderUser = _buildSenderUser();

    // 消息气泡内容
    final bubble = Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.65,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isFromMe ? AppTheme.myMessageColor : AppTheme.otherMessageColor,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(isFromMe ? 18 : 4),
          bottomRight: Radius.circular(isFromMe ? 4 : 18),
        ),
      ),
      child: _buildMessageContent(context, isFromMe),
    );

    // 引用消息预览
    final quotePreview = message.messageType == MessageType.quote
        ? _buildQuotePreview(context, isFromMe)
        : const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: isFromMe
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          // 引用预览 + 气泡 + 头像（同一行）
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isFromMe) ...[
                GestureDetector(
                  onTap: () => _navigateToProfile(context, senderUser, false),
                  child: UserAvatar(user: senderUser, radius: 18),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: GestureDetector(
                  onTap: onTap != null ? () => onTap!(message) : null,
                  onLongPress: onLongPress != null
                      ? () => onLongPress!(message)
                      : null,
                  child: Align(
                    alignment: isFromMe
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: isFromMe
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      children: [quotePreview, bubble],
                    ),
                  ),
                ),
              ),
              if (isFromMe) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _navigateToProfile(context, senderUser, true),
                  child: UserAvatar(user: senderUser, radius: 18),
                ),
              ],
            ],
          ),
          // 时间+状态（头像下方）
          Padding(
            padding: EdgeInsets.only(
              left: isFromMe ? 0 : 44,
              right: isFromMe ? 44 : 0,
              top: 4,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  timeText,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondaryColor.withValues(alpha: 0.8),
                  ),
                ),
                if (isFromMe) ...[const SizedBox(width: 4), _buildStatusIcon()],
              ],
            ),
          ),
          if (isFromMe &&
              isGroupChat &&
              groupReadReceipt != null &&
              groupReadReceipt!.hasReadCount > 0)
            Padding(
              padding: EdgeInsets.only(
                left: isFromMe ? 0 : 44,
                right: isFromMe ? 44 : 0,
                top: 2,
              ),
              child: Text(
                '已读 ${groupReadReceipt!.hasReadCount}/${groupReadReceipt!.groupMemberCount}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondaryColor,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 构建消息状态图标（飞书风格）
  Widget _buildStatusIcon() {
    final status = MessageSendStatus.fromValue(message.status);
    // 发送中：显示转圈
    if (status == MessageSendStatus.sending) {
      return SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.grey.shade400),
        ),
      );
    }
    // 发送失败：显示错误图标
    if (status == MessageSendStatus.sendFailed) {
      return const Icon(Icons.error_outline, size: 16, color: Colors.red);
    }
    // 已读：绿色实心圆 + 白色 ✓（飞书风格）
    if (message.isRead) {
      return Container(
        width: 16,
        height: 16,
        decoration: const BoxDecoration(
          color: Color(0xFF34C759),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.done, size: 11, color: Colors.white),
      );
    }
    // 已发送（未读）：灰色 ✓
    if (status == MessageSendStatus.sendSuccess) {
      return Icon(Icons.done, size: 16, color: Colors.grey.shade400);
    }
    return const SizedBox.shrink();
  }

  /// 根据消息类型构建消息内容
  Widget _buildMessageContent(BuildContext context, bool isFromMe) {
    final textColor = isFromMe ? Colors.white : AppTheme.otherMessageTextColor;

    return switch (message.messageType) {
      MessageType.image => _buildImageMessage(context),
      MessageType.video => _buildVideoMessage(context),
      MessageType.audio => _buildAudioMessage(context, isFromMe),
      MessageType.file => _buildFileMessage(context, isFromMe),
      MessageType.card => _buildCardMessage(context, isFromMe),
      MessageType.merge => _buildMergeMessage(context, isFromMe),
      MessageType.quote => _buildQuoteMessage(context, isFromMe),
      MessageType.at => _buildAtMessage(context, isFromMe),
      MessageType.face => _buildFaceMessage(context),
      MessageType.location => _buildLocationMessage(context, isFromMe),
      MessageType.custom => _buildCustomMessage(context, isFromMe),
      MessageType.system => _buildSystemMessage(context),
      MessageType.markdown => _buildMarkdownMessage(context, isFromMe),
      // text, advancedText
      _ => Text(
        message.displayText,
        style: TextStyle(color: textColor, fontSize: 16),
      ),
    };
  }

  // ===== Markdown 消息 =====
  Widget _buildMarkdownMessage(BuildContext context, bool isFromMe) {
    final textColor = isFromMe ? Colors.white : AppTheme.otherMessageTextColor;
    final linkColor = isFromMe ? Colors.white70 : AppTheme.primaryColor;
    final codeBgColor = isFromMe
        ? Colors.white.withValues(alpha: 0.15)
        : Colors.black.withValues(alpha: 0.06);

    return MarkdownBody(
      data: message.displayText,
      selectable: true,
      extensionSet: md.ExtensionSet.gitHubFlavored,
      styleSheet: MarkdownStyleSheet(
        p: TextStyle(color: textColor, fontSize: 16, height: 1.4),
        h1: TextStyle(
          color: textColor,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
        h2: TextStyle(
          color: textColor,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        h3: TextStyle(
          color: textColor,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        h4: TextStyle(
          color: textColor,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
        h5: TextStyle(
          color: textColor,
          fontSize: 15,
          fontWeight: FontWeight.bold,
        ),
        h6: TextStyle(
          color: textColor,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
        strong: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        em: TextStyle(color: textColor, fontStyle: FontStyle.italic),
        code: TextStyle(
          color: textColor,
          fontSize: 14,
          fontFamily: 'monospace',
          backgroundColor: codeBgColor,
        ),
        codeblockDecoration: BoxDecoration(
          color: codeBgColor,
          borderRadius: BorderRadius.circular(6),
        ),
        codeblockPadding: const EdgeInsets.all(8),
        blockquoteDecoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: linkColor.withValues(alpha: 0.5), width: 3),
          ),
        ),
        blockquotePadding: const EdgeInsets.only(left: 12),
        a: TextStyle(color: linkColor, decoration: TextDecoration.underline),
        listBullet: TextStyle(color: textColor, fontSize: 16),
        tableHead: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        tableBody: TextStyle(color: textColor, fontSize: 14),
        tableBorder: TableBorder.all(
          color: textColor.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
    );
  }

  // ===== 图片消息 =====
  Widget _withUploadProgress(BuildContext context, Widget child) {
    final progress = uploadProgress;
    if (!_isFromMe || progress == null || progress >= 100) return child;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        child,
        const SizedBox(height: 6),
        SizedBox(
          width: 150,
          child: LinearProgressIndicator(
            value: progress / 100,
            minHeight: 3,
            backgroundColor: Colors.white24,
          ),
        ),
      ],
    );
  }

  Widget _buildImageMessage(BuildContext context) {
    final source = message.displayImageSource;
    if (source.isEmpty) {
      return const Icon(Icons.broken_image, size: 120, color: Colors.grey);
    }
    return _withUploadProgress(
      context,
      ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: source.startsWith('http')
            ? Image.network(
                source,
                width: 150,
                height: 150,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.broken_image, size: 60),
              )
            : Image.asset(
                source,
                width: 150,
                height: 150,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.broken_image, size: 60),
              ),
      ),
    );
  }

  // ===== 视频消息 =====
  Widget _buildVideoMessage(BuildContext context) {
    final snap = message.videoSnapshotPath;
    return _withUploadProgress(
      context,
      Stack(
        alignment: Alignment.center,
        children: [
          if (snap.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: snap.startsWith('http')
                  ? Image.network(
                      snap,
                      width: 150,
                      height: 120,
                      fit: BoxFit.cover,
                    )
                  : Image.asset(
                      snap,
                      width: 150,
                      height: 120,
                      fit: BoxFit.cover,
                    ),
            )
          else
            Container(
              width: 150,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          const Icon(Icons.play_circle_fill, size: 40, color: Colors.white),
          if (message.videoDurationString != '0:00')
            Positioned(
              bottom: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  message.videoDurationString,
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ===== 语音消息 =====
  Widget _buildAudioMessage(BuildContext context, bool isFromMe) {
    return GestureDetector(
      onTap: () {
        if (message.soundSource.isEmpty) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('语音地址为空，无法播放')));
          return;
        }
        audioPlayerService.play(message.soundSource);
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.play_circle_outline,
            size: 24,
            color: isFromMe ? Colors.white : AppTheme.primaryColor,
          ),
          const SizedBox(width: 8),
          Text(
            message.audioDurationString,
            style: TextStyle(
              color: isFromMe ? Colors.white : AppTheme.otherMessageTextColor,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  // ===== 文件消息 =====
  Widget _buildFileMessage(BuildContext context, bool isFromMe) {
    final ext = message.fileExtension.toLowerCase();
    final iconData = switch (ext) {
      'pdf' => Icons.picture_as_pdf,
      'doc' || 'docx' => Icons.description,
      'xls' || 'xlsx' => Icons.table_chart,
      'ppt' || 'pptx' => Icons.slideshow,
      'zip' || 'rar' => Icons.folder_zip,
      _ => Icons.insert_drive_file,
    };
    final iconColor = isFromMe ? Colors.white70 : AppTheme.primaryColor;

    return _withUploadProgress(
      context,
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(iconData, size: 36, color: iconColor),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  message.fileName.isNotEmpty ? message.fileName : '未知文件',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isFromMe
                        ? Colors.white
                        : AppTheme.otherMessageTextColor,
                    fontSize: 14,
                  ),
                ),
                if (message.fileSizeString.isNotEmpty)
                  Text(
                    message.fileSizeString,
                    style: TextStyle(
                      color: isFromMe
                          ? Colors.white70
                          : AppTheme.textSecondaryColor,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===== 名片消息 =====
  Widget _buildCardMessage(BuildContext context, bool isFromMe) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isFromMe ? Colors.white.withValues(alpha: 0.15) : Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundImage: (message.cardFaceUrl).isNotEmpty
                    ? NetworkImage(message.cardFaceUrl)
                    : null,
                child: message.cardFaceUrl.isEmpty
                    ? Text(
                        (message.cardNickname).isNotEmpty
                            ? message.cardNickname[0]
                            : '?',
                      )
                    : null,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message.cardNickname.isNotEmpty
                          ? message.cardNickname
                          : '未知用户',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isFromMe
                            ? Colors.white
                            : AppTheme.otherMessageTextColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      message.cardUserId,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isFromMe
                            ? Colors.white70
                            : AppTheme.textSecondaryColor,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Divider(
            color: (isFromMe ? Colors.white30 : Colors.grey.shade200),
            height: 12,
          ),
          Text(
            '个人名片',
            style: TextStyle(
              color: isFromMe ? Colors.white70 : AppTheme.textSecondaryColor,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // ===== 合并转发消息 =====
  Widget _buildMergeMessage(BuildContext context, bool isFromMe) {
    final title = message.mergeTitle.isNotEmpty ? message.mergeTitle : '聊天记录';
    final previews = message.mergeSenderNicknames;
    final count = message.mergeMessageCount;

    return Container(
      width: 220,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isFromMe ? Colors.white.withValues(alpha: 0.15) : Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 标题
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isFromMe ? Colors.white : AppTheme.otherMessageTextColor,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          // 分隔线
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            height: 0.5,
            color: (isFromMe ? Colors.white24 : Colors.grey.shade300),
          ),
          // 摘要预览（sender: content 格式，最多 5 条）
          ...previews
              .take(5)
              .map(
                (text) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isFromMe
                          ? Colors.white70
                          : AppTheme.textSecondaryColor,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
          const SizedBox(height: 4),
          // 消息条数
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '$count条消息',
              style: TextStyle(
                color: isFromMe ? Colors.white54 : AppTheme.textSecondaryColor,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===== 引用消息预览 =====
  Widget _buildQuotePreview(BuildContext context, bool isFromMe) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.75,
      ),
      decoration: BoxDecoration(
        color: isFromMe
            ? Colors.white.withValues(alpha: 0.15)
            : Colors.grey.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (message.quoteSenderNickname.isNotEmpty)
            Text(
              message.quoteSenderNickname,
              style: TextStyle(
                color: isFromMe ? Colors.white70 : AppTheme.primaryColor,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          if (message.quoteReplyContent.isNotEmpty)
            Text(
              message.quoteReplyContent,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isFromMe ? Colors.white60 : AppTheme.textSecondaryColor,
                fontSize: 12,
              ),
            ),
        ],
      ),
    );
  }

  // ===== 引用消息主体 =====
  Widget _buildQuoteMessage(BuildContext context, bool isFromMe) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildQuotePreview(context, isFromMe),
        Text(
          message.quoteText.isNotEmpty
              ? message.quoteText
              : message.displayText,
          style: TextStyle(
            color: isFromMe ? Colors.white : AppTheme.otherMessageTextColor,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  // ===== @ 消息 =====
  Widget _buildAtMessage(BuildContext context, bool isFromMe) {
    final text = message.displayText;
    final nicknames = message.atNicknames;
    if (nicknames.isEmpty) {
      return Text(
        text,
        style: TextStyle(
          color: isFromMe ? Colors.white : AppTheme.otherMessageTextColor,
          fontSize: 16,
        ),
      );
    }
    // 简单实现：高亮 @昵称 部分
    return Text(
      text,
      style: TextStyle(
        color: isFromMe ? Colors.white : AppTheme.otherMessageTextColor,
        fontSize: 16,
      ),
    );
  }

  // ===== 表情消息 =====
  Widget _buildFaceMessage(BuildContext context) {
    // 大号 emoji 展示
    return Text(
      message.displayText.isNotEmpty ? message.displayText : '😀',
      style: const TextStyle(fontSize: 48),
    );
  }

  // ===== 位置消息 =====
  Widget _buildLocationMessage(BuildContext context, bool isFromMe) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isFromMe ? Colors.white.withValues(alpha: 0.15) : Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.location_on,
                size: 20,
                color: isFromMe ? Colors.white : AppTheme.primaryColor,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  message.locationName.isNotEmpty ? message.locationName : '位置',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isFromMe
                        ? Colors.white
                        : AppTheme.otherMessageTextColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          if (message.locationDesc.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              message.locationDesc,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isFromMe ? Colors.white70 : AppTheme.textSecondaryColor,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ===== 自定义消息 =====
  Widget _buildCustomMessage(BuildContext context, bool isFromMe) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isFromMe
            ? Colors.white.withValues(alpha: 0.15)
            : Colors.grey.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        message.displayText.isNotEmpty ? message.displayText : '[自定义消息]',
        style: TextStyle(
          color: isFromMe ? Colors.white : AppTheme.otherMessageTextColor,
          fontSize: 14,
        ),
      ),
    );
  }

  // ===== 系统消息（撤回等） =====
  Widget _buildSystemMessage(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.textSecondaryColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message.displayText,
        style: const TextStyle(
          color: AppTheme.textSecondaryColor,
          fontSize: 12,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  void _navigateToProfile(BuildContext context, User user, bool isFromMeHint) {
    AppRouter.goToUserProfile(context, userId: user.id, user: user);
  }

  /// 格式化消息时间（包含日期+时间）
  String _formatMessageTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(dateTime.year, dateTime.month, dateTime.day);
    final diff = today.difference(msgDay).inDays;
    final timeStr = DateFormat('HH:mm').format(dateTime);

    if (diff == 0) {
      return timeStr;
    } else if (diff == 1) {
      return '昨天 $timeStr';
    } else if (diff < 7) {
      const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
      return '${weekdays[dateTime.weekday - 1]} $timeStr';
    } else if (now.year == dateTime.year) {
      return '${DateFormat('MM月dd日').format(dateTime)} $timeStr';
    } else {
      return '${DateFormat('yyyy年MM月dd日').format(dateTime)} $timeStr';
    }
  }
}
