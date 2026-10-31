import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../ui/chat/mappers/message_display.dart';
import '../../../../domain/models/user.dart';
import '../../../../domain/models/message_search_result.dart'
    show MessageSearchResult;
import '../../core/theme/app_theme.dart';
import '../../core/widgets/segmented_toggle.dart';
import '../../core/widgets/user_avatar.dart';
import '../providers/chat_detail_provider.dart';
import 'message_search_filter.dart';

/// 会话内消息搜索底部面板。
///
/// 顶部是搜索框 + 与消息列表同款的 `SegmentedToggle` 类型筛选，
/// 下方按结果类型展示列表/空态。
class ChatMessageSearchSheet extends ConsumerStatefulWidget {
  const ChatMessageSearchSheet({
    super.key,
    required this.conversationId,
    this.onMessageTap,
    this.initialFilter = ChatMessageSearchFilter.all,
  });

  final String conversationId;
  final ValueChanged<MessageSearchResult>? onMessageTap;
  final ChatMessageSearchFilter initialFilter;

  @override
  ConsumerState<ChatMessageSearchSheet> createState() =>
      _ChatMessageSearchSheetState();
}

class _ChatMessageSearchSheetState
    extends ConsumerState<ChatMessageSearchSheet> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  List<MessageSearchResult> _results = const [];
  bool _searching = false;
  String? _error;
  late ChatMessageSearchFilter _filter = widget.initialFilter;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String keyword) {
    _debounce?.cancel();
    if (keyword.trim().isEmpty && _filter == ChatMessageSearchFilter.all) {
      setState(() {
        _results = const [];
        _error = null;
        _searching = false;
      });
      return;
    }
    setState(() {});
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _search(keyword);
    });
  }

  void _onFilterChanged(ChatMessageSearchFilter filter) {
    if (filter == _filter) return;
    _debounce?.cancel();
    setState(() => _filter = filter);
    _search(_controller.text);
  }

  Future<void> _search(String keyword) async {
    final trimmed = keyword.trim();
    if (trimmed.isEmpty && _filter == ChatMessageSearchFilter.all) {
      if (!mounted) return;
      setState(() {
        _results = const [];
        _error = null;
        _searching = false;
      });
      return;
    }
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final raw = await ref
          .read(chatDetailViewModelProvider(widget.conversationId).notifier)
          .searchLocalMessages(
            trimmed,
            messageTypes: _filter.messageTypes,
            // 纯类型浏览页多取一些，避免只看到最近的几条
            count: _filter == ChatMessageSearchFilter.all ? 50 : 200,
          );
      final results = _filter.needsLocalMatch
          ? raw.where(_filter.matches).toList(growable: false)
          : raw;
      if (!mounted) return;
      setState(() => _results = results);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '搜索失败: $e');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final screenHeight = MediaQuery.sizeOf(context).height;
    // 键盘弹起时按剩余空间收敛高度，避免面板整体被顶出屏幕。
    final sheetHeight = math.max(320.0, (screenHeight - bottomInset) * 0.85);
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SizedBox(
        height: sheetHeight,
        child: Material(
          color: colors.surface,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
                child: Row(
                  children: [
                    Text(
                      '搜索',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '本会话',
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      tooltip: '关闭',
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  onChanged: _onChanged,
                  style: TextStyle(fontSize: 14, color: colors.textPrimary),
                  decoration: InputDecoration(
                    hintText: _filter.hint,
                    hintStyle: TextStyle(
                      fontSize: 14,
                      color: colors.textSecondary,
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      size: 20,
                      color: colors.textSecondary,
                    ),
                    suffixIcon: _controller.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            tooltip: '清空',
                            onPressed: () {
                              _controller.clear();
                              _onChanged('');
                            },
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    filled: true,
                    fillColor: colors.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: SegmentedToggle(
                  segments: [
                    for (final filter in ChatMessageSearchFilter.values)
                      filter.label,
                  ],
                  selectedIndex: _filter.index,
                  height: 36,
                  onChanged: (index) =>
                      _onFilterChanged(ChatMessageSearchFilter.values[index]),
                ),
              ),
              Divider(height: 1, color: colors.divider.withValues(alpha: 0.6)),
              Expanded(child: _buildResults()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResults() {
    final colors = context.appColors;
    if (_searching) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(_error!, style: TextStyle(color: colors.danger)),
        ),
      );
    }
    if (_results.isEmpty) return _buildEmpty(colors);
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: _results.length,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        indent: 16,
        endIndent: 16,
        color: colors.divider.withValues(alpha: 0.6),
      ),
      itemBuilder: (_, i) {
        final log = _results[i];
        final rawTime = log.sendTime.toInt();
        final time = DateTime.fromMillisecondsSinceEpoch(
          rawTime > 0 && rawTime < 946684800000 ? rawTime * 1000 : rawTime,
        ).toLocal();
        final senderName = log.senderNickName.isNotEmpty
            ? log.senderNickName
            : log.sendId;
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          leading: UserAvatar.fromUser(
            user: User(
              id: log.sendId,
              name: senderName,
              avatar: log.senderFaceUrl.isNotEmpty ? log.senderFaceUrl : null,
            ),
            radius: 18,
          ),
          title: Text(
            log.displayText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 14, color: colors.textPrimary),
          ),
          subtitle: Text(
            '$senderName  ${time.toString().substring(0, 16)}',
            style: TextStyle(fontSize: 12, color: colors.textSecondary),
          ),
          onTap: () {
            Navigator.of(context).pop();
            widget.onMessageTap?.call(log);
          },
        );
      },
    );
  }

  Widget _buildEmpty(AppColors colors) {
    final idle =
        _filter == ChatMessageSearchFilter.all &&
        _controller.text.trim().isEmpty;
    final icon = switch (_filter) {
      ChatMessageSearchFilter.all => Icons.search,
      ChatMessageSearchFilter.media => Icons.image_outlined,
      ChatMessageSearchFilter.files => Icons.folder_outlined,
      ChatMessageSearchFilter.links => Icons.link,
    };
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 44,
            color: colors.textSecondary.withValues(alpha: 0.35),
          ),
          const SizedBox(height: 12),
          Text(
            idle ? '输入关键字搜索聊天记录' : '没有找到相关消息',
            style: TextStyle(fontSize: 15, color: colors.textSecondary),
          ),
          const SizedBox(height: 6),
          Text(
            idle ? '可按图片视频、文件、链接筛选' : '换个关键字或筛选条件再试试',
            style: TextStyle(
              fontSize: 12,
              color: colors.textSecondary.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}
